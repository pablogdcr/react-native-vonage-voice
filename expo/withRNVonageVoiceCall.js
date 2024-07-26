Object.defineProperty(exports, "__esModule", { value: true });
exports.withXcodeLinkBinaryWithLibraries = void 0;
const config_plugins_1 = require("expo/config-plugins");

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
  config = (0, exports.withXcodeLinkBinaryWithLibraries)(config, {
    library: "CallKit.framework",
  });

  return config;
}

module.exports = function withVoipPushNotification(config) {
  config = withIosVonageVoiceCall(config);
  // config = withAndroidVoipPushNotification(config);

  return config;
};
