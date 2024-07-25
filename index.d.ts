declare module 'react-native-vonage-voice-call' {
  export default class RNVonageVoiceCall {
    static createSession(jwt: string): Promise<string>;
    static registerVoipToken(voipToken: string): Promise<string>;
  }
}
