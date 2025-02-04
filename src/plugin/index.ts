import type { ConfigPlugin } from 'expo/config-plugins';
import withIosVonageVoice from './withIosVonageVoice';
import withAndroidVonageVoice from './withAndroidVonageVoice';

const withVonageVoice: ConfigPlugin<{ url: string }> = (config, options) => {
  // Apply iOS configuration
  config = withIosVonageVoice(config, options);

  // Apply Android configuration
  config = withAndroidVonageVoice(config);

  return config;
};

export default withVonageVoice;
