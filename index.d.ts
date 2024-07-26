declare module 'react-native-vonage-voice-call' {
  export default class RNVonageVoiceCall {
    static createSession(jwt: string, region?: 'EU' | 'US' | 'AP'): Promise<string>;
    static registerVoipToken(voipToken: string): Promise<string>;
    static answer(callId: string): Promise<void>;
    static reject(callId: string): Promise<void>;
    static call(number: string): Promise<string>;
    static endCall(): Promise<string>;
  }
}
