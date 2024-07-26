declare module 'react-native-vonage-voice-call' {
  export default class RNVonageVoiceCall {
    static createSession(jwt: string, region?: 'EU' | 'US' | 'AP'): Promise<void>;
    static answer(callId: string): Promise<void>;
    static reject(callId: string): Promise<void>;
  }
}
