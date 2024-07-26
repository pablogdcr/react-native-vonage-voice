declare module 'react-native-vonage-voice-call' {
  export default class RNVonageVoiceCall {
    static createSession(jwt: string, region?: 'EU' | 'US' | 'AP'): Promise<string>;
    static registerVoipToken(voipToken: string): Promise<string>;
  }
}
