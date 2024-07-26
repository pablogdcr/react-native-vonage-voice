const config_plugins_1 = require('expo/config-plugins');

const withIosVonageVoiceCall = (config) => {
  config = (0, config_plugins_1.withInfoPlist)(config, (config) => {
    if (!Array.isArray(config.modResults.UIBackgroundModes)) {
      config.modResults.UIBackgroundModes = [];
    }
    if (!config.modResults.UIBackgroundModes.includes('remote-notification')) {
      config.modResults.UIBackgroundModes.push('remote-notification');
    }
    if (!config.modResults.UIBackgroundModes.includes('processing')) {
      config.modResults.UIBackgroundModes.push('processing');
    }
    return config;
  });
}

module.exports = function withVoipPushNotification(config) {
  config = withIosVonageVoiceCall(config);
  // config = withAndroidVoipPushNotification(config);

  return config;
};
