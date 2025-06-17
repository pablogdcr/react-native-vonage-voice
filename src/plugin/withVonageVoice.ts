import type { ConfigPlugin } from 'expo/config-plugins';
import {
  IOSConfig,
  withAppDelegate,
  withDangerousMod,
  withXcodeProject,
} from 'expo/config-plugins';
import fs from 'fs';
import path from 'path';

const withXcodeLinkBinaryWithLibraries: ConfigPlugin<{
  library: string;
  status?: string;
}> = (config, { library, status }) => {
  return withXcodeProject(config, (xcodeConfig) => {
    const options = status === 'optional' ? { weak: true } : {};
    const target = IOSConfig.XcodeUtils.getApplicationNativeTarget({
      project: xcodeConfig.modResults,
      projectName: xcodeConfig.modRequest.projectName!,
    });

    xcodeConfig.modResults.addFramework(library, {
      target: target.uuid,
      ...options,
    });
    return xcodeConfig;
  });
};

// Matchers for the Swift AppDelegate modifications
const importsLineMatcher = /import ReactAppDependencyProvider/g;

const swiftImportsBlock = `import ReactAppDependencyProvider
import PushKit
import CallKit
import Intents`;

// Matcher for class declaration to add protocol conformance
const classDeclarationMatcher = /public class AppDelegate: ExpoAppDelegate \{/g;

const classDeclarationReplacement = `public class AppDelegate: ExpoAppDelegate, PKPushRegistryDelegate {`;

// Matcher for didFinishLaunchingWithOptions to add PushKit setup
const didFinishLaunchingMatcher = /return super\.application\(application, didFinishLaunchingWithOptions: launchOptions\)/g;

const pushKitSetupBlock = `    // Setup PushKit for VoIP
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)`;

// Swift handlers block
const handlersBlock = (url: string) => `
  // MARK: - PKPushRegistryDelegate
  
  public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    // Register VoIP push token with VonageVoice
    VonageVoice.didUpdate(pushCredentials, forType: type)
  }
  
  public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    // Handle token invalidation if needed
    VonageVoice.didInvalidatePushToken(forType: type)
  }
  
  public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    let refreshSessionBlock: (RCTPromiseResolveBlock?, RCTPromiseRejectBlock?) -> Void = { resolve, reject in
      SupabaseService.shared.refreshSession(
        resolve: { result in
          resolve?(result)
        },
        reject: { code, message, error in
          reject?(code, message, error)
        }
      )
    }
    
    NotificationCenter.default.post(
      name: Notification.Name("voip-push-received"),
      object: payload.dictionaryPayload,
      userInfo: [
        "refreshSessionBlock": refreshSessionBlock,
        "refreshVonageTokenUrlString": "${url}/v1/app/voip/auth"
      ]
    )
    
    completion()
  }`;

// Matcher for continueUserActivity
const userActivityMatcher = /let result = RCTLinkingManager\.application\(application, continue: userActivity, restorationHandler: restorationHandler\)/g;

const userActivityBlock = `    // Handle Intents for CallKit
    if let intent = userActivity.interaction?.intent as? INStartCallIntent,
       let person = intent.contacts?.first,
       let phoneNumber = person.personHandle?.value {
      let telURL = "tel:\\(phoneNumber)"
      if let url = URL(string: telURL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
      }
    }
    
    let result = RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)`;

// Add applicationWillTerminate
const terminateBlock = `
  public override func applicationWillTerminate(_ application: UIApplication) {
    super.applicationWillTerminate(application)
    VonageVoice.shared().resetCallInfo()
  }`;

const withIosVonageVoice: ConfigPlugin<{ url: string }> = (config, options) => {
  let updatedConfig = config;

  // Add required frameworks
  updatedConfig = withXcodeLinkBinaryWithLibraries(updatedConfig, {
    library: 'PushKit.framework',
  });

  updatedConfig = withXcodeLinkBinaryWithLibraries(updatedConfig, {
    library: 'CallKit.framework',
  });

  updatedConfig = withXcodeLinkBinaryWithLibraries(updatedConfig, {
    library: 'Intents.framework',
  });

  // Modify AppDelegate.swift
  updatedConfig = withAppDelegate(updatedConfig, (appDelegateConfig) => {
    // Update imports
    appDelegateConfig.modResults.contents = appDelegateConfig.modResults.contents.replace(
      importsLineMatcher,
      swiftImportsBlock
    );

    // Update class declaration to add PKPushRegistryDelegate
    appDelegateConfig.modResults.contents = appDelegateConfig.modResults.contents.replace(
      classDeclarationMatcher,
      classDeclarationReplacement
    );

    // Add PushKit setup in didFinishLaunchingWithOptions
    appDelegateConfig.modResults.contents = appDelegateConfig.modResults.contents.replace(
      didFinishLaunchingMatcher,
      pushKitSetupBlock
    );

    // Add handlers before the closing brace of the AppDelegate class
    // Find the end of the AppDelegate class (before ReactNativeDelegate)
    const appDelegateEndPattern = /\n}\n\nclass ReactNativeDelegate/;
    const appDelegateEndMatch = appDelegateConfig.modResults.contents.match(appDelegateEndPattern);
    
    if (appDelegateEndMatch) {
      const insertPosition = appDelegateEndMatch.index!;
      appDelegateConfig.modResults.contents = 
        appDelegateConfig.modResults.contents.slice(0, insertPosition) +
        handlersBlock(options.url) +
        terminateBlock +
        appDelegateConfig.modResults.contents.slice(insertPosition);
    } else {
      // Fallback: add before the last closing brace
      const lastBraceIndex = appDelegateConfig.modResults.contents.lastIndexOf('}');
      if (lastBraceIndex !== -1) {
        appDelegateConfig.modResults.contents = 
          appDelegateConfig.modResults.contents.slice(0, lastBraceIndex) +
          handlersBlock(options.url) +
          terminateBlock +
          '\n}' +
          appDelegateConfig.modResults.contents.slice(lastBraceIndex + 1);
      }
    }

    // Update user activity handling
    appDelegateConfig.modResults.contents = appDelegateConfig.modResults.contents.replace(
      userActivityMatcher,
      userActivityBlock
    );

    return appDelegateConfig;
  });

  // Update bridging header for VonageVoice
  updatedConfig = withDangerousMod(updatedConfig, [
    'ios',
    (dangerousConfig) => {
      const projectName = dangerousConfig.modRequest.projectName!;
      const bridgingHeaderPath = path.join(
        dangerousConfig.modRequest.platformProjectRoot,
        projectName,
        `${projectName}-Bridging-Header.h`
      );

      if (fs.existsSync(bridgingHeaderPath)) {
        let headerContents = fs.readFileSync(bridgingHeaderPath, 'utf-8');

        // Add VonageVoice import if not already present
        if (!headerContents.includes('#import <VonageVoice.h>')) {
          headerContents += '\n#import <VonageVoice.h>';
        }

        // Remove SupabaseService.h import if present (it doesn't exist as a header file)
        if (headerContents.includes('#import "SupabaseService.h"')) {
          headerContents = headerContents.replace(/\n?#import "SupabaseService\.h"/g, '');
        }

        fs.writeFileSync(bridgingHeaderPath, headerContents);
      }

      return dangerousConfig;
    },
  ]);

  return updatedConfig;
};

export default withIosVonageVoice;
