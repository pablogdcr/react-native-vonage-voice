import type { ConfigPlugin } from '@expo/config-plugins';
import withVonageVoice from './plugin/index';

// Export the plugin configuration
export default withVonageVoice as ConfigPlugin<{ url: string }>;
