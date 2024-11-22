import type { ConfigPlugin } from 'expo/config-plugins';
import withVonageVoice from './withVonageVoice';

const withVonageVoicePlugin: ConfigPlugin<{ url: string }> = (
  config,
  options
) => {
  return withVonageVoice(config, options);
};

export default withVonageVoicePlugin;
