import type { ConfigPlugin } from 'expo/config-plugins';
import {
  IOSConfig,
  withAppDelegate,
  withXcodeProject,
  withDangerousMod,
} from 'expo/config-plugins';
import { mergeContents } from '@expo/config-plugins/build/utils/generateCode';
import * as fs from 'fs';
import * as path from 'path';

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

// Matchers for the AppDelegate modifications
const handlersLineMatcher =
  /return \[super application:application didFinishLaunchingWithOptions:launchOptions\];/g;

const handlersBlock = (url: string) => `
// --- Handle updated push credentials
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
    // Register VoIP push token with VonageVoice
    [VonageVoice didUpdatePushCredentials:credentials forType:type];
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    // Handle token invalidation if needed
}

// --- Handle incoming pushes
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion {
    void (^refreshSessionBlock)(RCTPromiseResolveBlock, RCTPromiseRejectBlock) = ^(RCTPromiseResolveBlock resolve, RCTPromiseRejectBlock reject) {
        [[SupabaseService shared] refreshSession:^(id result) {
            if (resolve) {
                resolve(result); // Hook into resolve callback
            }
        } rejecter:^(NSString *code, NSString *message, NSError *error) {
            if (reject) {
                reject(code, message, error); // Hook into reject callback
            }
        }];
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"voip-push-received" 
                                                      object:nil 
                                                    userInfo:payload.dictionaryPayload
                                                    userInfo:@{
    @"refreshSessionBlock": [refreshSessionBlock copy],
    @"refreshVonageTokenUrlString": @"${url}/v1/app/voip/auth",
  }];
    
    completion();
}
`;

const withVonagePodfileConfig: ConfigPlugin = (config) => {
  return withDangerousMod(config, [
    'ios',
    async (dangerousModConfig) => {
      const podfilePath = path.join(
        dangerousModConfig.modRequest.platformProjectRoot,
        'Podfile'
      );
      let podfileContent = fs.readFileSync(podfilePath, 'utf8');

      const podConfigBlock = `
  installer.pods_project.targets.each do |target|
    if target.name == 'react-native-vonage-voice'
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'YES'
        config.build_settings['DEFINES_MODULE'] = 'YES'
        config.build_settings['SWIFT_OBJC_INTERFACE_HEADER_NAME'] = "${dangerousModConfig.modRequest.projectName}-Swift.h"
      end
    end
  end`;

      // Check if configuration already exists
      if (!podfileContent.includes('react-native-vonage-voice')) {
        // Find the post_install hook or create one
        if (podfileContent.includes('post_install')) {
          podfileContent = podfileContent.replace(
            /post_install do \|installer\|(.*?)end/s,
            (match) => {
              const existingContent = match.slice(0, -3); // Remove last 'end'
              return `${existingContent}${podConfigBlock}\n  end`;
            }
          );
        } else {
          podfileContent += `\npost_install do |installer|${podConfigBlock}\nend\n`;
        }

        fs.writeFileSync(podfilePath, podfileContent);
      }

      return dangerousModConfig;
    },
  ]);
};

const withIosVonageVoice: ConfigPlugin<{ url: string }> = (config, options) => {
  let updatedConfig = config;

  // Add required frameworks
  updatedConfig = withXcodeLinkBinaryWithLibraries(updatedConfig, {
    library: 'PushKit.framework',
  });

  updatedConfig = withXcodeLinkBinaryWithLibraries(updatedConfig, {
    library: 'CallKit.framework',
  });

  // Add Podfile configuration
  updatedConfig = withVonagePodfileConfig(updatedConfig);

  return withAppDelegate(updatedConfig, (appDelegateConfig) => {
    // Add required imports
    appDelegateConfig.modResults.contents =
      appDelegateConfig.modResults.contents.replace(
        /#import "AppDelegate.h"/g,
        `#import "AppDelegate.h"
#import <PushKit/PushKit.h>
#import "AlloDev-Swift.h" // For VonageVoice`
      );

    // Add handlers
    appDelegateConfig.modResults.contents = mergeContents({
      tag: '@react-native-vonage-voice-handlers',
      src: appDelegateConfig.modResults.contents,
      newSrc: handlersBlock(options.url),
      anchor: handlersLineMatcher,
      offset: 2,
      comment: '//',
    }).contents;

    return appDelegateConfig;
  });
};

export default withIosVonageVoice;
