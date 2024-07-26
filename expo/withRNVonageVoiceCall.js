Object.defineProperty(exports, "__esModule", { value: true });
exports.withXcodeLinkBinaryWithLibraries = void 0;
const config_plugins_1 = require("expo/config-plugins");
const generateCode = require('@expo/config-plugins/build/utils/generateCode');
const ensureHeaderSearchPath_1 = require("./ensureHeaderSearchPath");

// https://regex101.com/r/mPgaq6/1
// eslint-disable-next-line max-len
const methodInvocationLineMatcher = /self\.moduleName\s*=\s*@"([^"]*)";|(self\.|_)(\w+)\s?=\s?\[\[UMModuleRegistryAdapter alloc\]|RCTBridge\s?\*\s?(\w+)\s?=\s?\[(\[RCTBridge alloc\]|self\.reactDelegate)/g;
// https://regex101.com/r/nHrTa9/1/
// if the above regex fails, we can use this one as a fallback:
// eslint-disable-next-line max-len
const fallbackInvocationLineMatcher = /-\s*\(BOOL\)\s*application:\s*\(UIApplication\s*\*\s*\)\s*\w+\s+didFinishLaunchingWithOptions:/g;
const methodInvocationBlock = `
  [RNVonageVoiceCall voipRegistration];
`;

const handlersLineMatcher = /return \[super application:application didFinishLaunchingWithOptions:launchOptions\];/g;
const handlersBlock = `
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
  [RNVonageVoiceCall sharedInstance].pushToken = pushCredentials.token;
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type
{
  [RNVonageVoiceCall invalidatePushToken];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion {
  if ([RNVonageVoiceCall isVonagePush: payload.dictionaryPayload]) {
    [RNVonageVoiceCall login(isPushLogin: true)];
    [RNVonageVoiceCall processPushPayload: payload.dictionaryPayload pushKitCompletion: completion];
  }
}
`;

const withVoipPushNotificationHeaderSearchPath = (config) => {
    const headerSearchPath = `"$(SRCROOT)/../node_modules/react-native-vonage-voice-call/ios/RNVonageVoiceCall"`;
    return (0, config_plugins_1.withXcodeProject)(config, (config) => {
        (0, ensureHeaderSearchPath_1.ensureHeaderSearchPath)(config.modResults, headerSearchPath);
        return config;
    });
};

const withIosVonageVoiceCall = (config) => {
  config = (0, config_plugins_1.withInfoPlist)(config, (config) => {
    if (!Array.isArray(config.modResults.UIBackgroundModes)) {
      config.modResults.UIBackgroundModes = [];
    }
    if (!config.modResults.UIBackgroundModes.includes("voip")) {
      config.modResults.UIBackgroundModes.push("voip");
    }
    if (!config.modResults.UIBackgroundModes.includes('processing')) {
      config.modResults.UIBackgroundModes.push('processing');
    }
    return config;
  });
  config = withVoipPushNotificationHeaderSearchPath(config);
  config = (0, exports.withXcodeLinkBinaryWithLibraries)(config, {
    library: "CallKit.framework",
  });

  return config_plugins_1.withAppDelegate(
    config,
    (config) => {
      config.modResults.contents = config.modResults.contents.replace(/#import "AppDelegate.h"/g, `#import "AppDelegate.h"\n#import <PushKit/PushKit.h>\n#import "RNVonageVoiceCall-Swift.h"`);
      if (!methodInvocationLineMatcher.test(config.modResults.contents)
        && !fallbackInvocationLineMatcher.test(config.modResults.contents)
        && !handlersLineMatcher.test(config.modResults.contents)) {
        config_plugins_1.WarningAggregator.addWarningIOS('react-native-vonage-voice-call', 'Unable to determine correct insertion point in AppDelegate.m. Skipping addition.');
        return config;
      }
      try {
        config.modResults.contents = (0, generateCode.mergeContents)({
          tag: '@react-native-vonage-voice-call-didFinishLaunchingWithOptions',
          src: config.modResults.contents,
          newSrc: methodInvocationBlock,
          anchor: methodInvocationLineMatcher,
          offset: 0,
          comment: '//',
        }).contents;
      } catch (e) {
        // tests if the opening `{` is in the new line
        const multilineMatcher = new RegExp(`${fallbackInvocationLineMatcher.source}.+\\n*\\{`);
        const isHeaderMultiline = multilineMatcher.test(config.modResults.contents);
        // we fallback to another regex if the first one fails
        config.modResults.contents = (0, generateCode.mergeContents)({
          tag: '@react-native-vonage-voice-call-didFinishLaunchingWithOptions',
          src: config.modResults.contents,
          newSrc: methodInvocationBlock,
          anchor: fallbackInvocationLineMatcher,
          // new line will be inserted right below matched anchor
          // or two lines, if the `{` is in the new line
          offset: isHeaderMultiline ? 2 : 1,
          comment: '//',
        }).contents;
      }
      config.modResults.contents = (0, generateCode.mergeContents)({
        tag: '@react-native-vonage-voice-call-handlers',
        src: config.modResults.contents,
        newSrc: handlersBlock,
        anchor: handlersLineMatcher,
        offset: 2,
        comment: '//',
      }).contents;

      return config;
    },
  );
}

const withXcodeLinkBinaryWithLibraries = (config, { library, status }) => {
  return (0, config_plugins_1.withXcodeProject)(config, (config) => {
      const options = status === "optional" ? { weak: true } : {};
      const target = config_plugins_1.IOSConfig.XcodeUtils.getApplicationNativeTarget({
          project: config.modResults,
          projectName: config.modRequest.projectName,
      });
      config.modResults.addFramework(library, {
          target: target.uuid,
          ...options,
      });
      return config;
  });
};

exports.withXcodeLinkBinaryWithLibraries = withXcodeLinkBinaryWithLibraries;
exports.default = function withVoipPushNotification(config) {
  config = withIosVonageVoiceCall(config);

  return config;
};
