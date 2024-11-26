import type { ConfigPlugin } from 'expo/config-plugins';
import {
  IOSConfig,
  withAppDelegate,
  withDangerousMod,
  withXcodeProject,
} from 'expo/config-plugins';
import { mergeContents } from '@expo/config-plugins/build/utils/generateCode';
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
    [VonageVoice didInvalidatePushTokenForType:type];
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
                                                    object:payload.dictionaryPayload
                                                    userInfo:@{
      @"refreshSessionBlock": [refreshSessionBlock copy],
      @"refreshVonageTokenUrlString": @"${url}/v1/app/voip/auth",
    }];
    
    completion();
}
`;

// Add this new matcher constant
const userActivityLineMatcher =
  /- \(BOOL\)application:\(UIApplication \*\)application continueUserActivity:\(nonnull NSUserActivity \*\)userActivity restorationHandler:\(nonnull void \(\^\)\(NSArray<id<UIUserActivityRestoring>> \* _Nullable\)\)restorationHandler \{/g;

// Add this new block constant
const userActivityBlock = `
  if ([userActivity.interaction.intent isKindOfClass:[INStartAudioCallIntent class]]) {
    INPerson *person = [[(INStartAudioCallIntent*)userActivity.interaction.intent contacts] firstObject];
    NSString *phoneNumber = person.personHandle.value;
    NSString *telURL = [NSString stringWithFormat:@"tel:%@", phoneNumber];

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:telURL] options:@{} completionHandler:nil];
    return YES;
  }
`;

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

  // Modify AppDelegate.h using withDangerousMod
  updatedConfig = withAppDelegate(updatedConfig, (appDelegateConfig) => {
    // Update imports to include Intents
    appDelegateConfig.modResults.contents =
      appDelegateConfig.modResults.contents.replace(
        /#import "AppDelegate.h"/g,
        `#import "AppDelegate.h"
#import <PushKit/PushKit.h>
#import <VonageVoice.h>
#import <Intents/Intents.h>`
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

    // Add user activity handling
    appDelegateConfig.modResults.contents = mergeContents({
      tag: '@react-native-vonage-voice-useractivity',
      src: appDelegateConfig.modResults.contents,
      newSrc: userActivityBlock,
      anchor: userActivityLineMatcher,
      offset: 2,
      comment: '//',
    }).contents;

    return appDelegateConfig;
  });

  return withDangerousMod(updatedConfig, [
    'ios',
    (dangerousConfig) => {
      const appDelegateHeaderPath = path.join(
        dangerousConfig.modRequest.platformProjectRoot,
        dangerousConfig.modRequest.projectName!,
        'AppDelegate.h'
      );

      if (fs.existsSync(appDelegateHeaderPath)) {
        let headerContents = fs.readFileSync(appDelegateHeaderPath, 'utf-8');

        // Add PushKit import if not already present
        if (!headerContents.includes('#import <PushKit/PushKit.h>')) {
          headerContents = headerContents.replace(
            /#import <UIKit\/UIKit.h>/,
            '#import <UIKit/UIKit.h>\n#import <PushKit/PushKit.h>'
          );
        }

        // Update interface declaration
        headerContents = headerContents.replace(
          /@interface AppDelegate : EXAppDelegateWrapper/,
          '@interface AppDelegate : EXAppDelegateWrapper <UNUserNotificationCenterDelegate, PKPushRegistryDelegate>'
        );

        fs.writeFileSync(appDelegateHeaderPath, headerContents);
      }

      return dangerousConfig;
    },
  ]);
};

export default withIosVonageVoice;
