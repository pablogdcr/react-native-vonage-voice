import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-vonage-voice' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

interface RNVonageVoiceCallModuleInterface {
  setRegion(region: 'US' | 'EU'): void;
  login(jwt: string, isPushLogin: boolean): Promise<string | null>;
  answerCall(callId: string): Promise<string | null>;
  rejectCall(callId: string): Promise<string | null>;
  hangup(callId: string): Promise<string | null>;
}

const VonageVoice = NativeModules.VonageVoice
  ? (NativeModules.VonageVoice as RNVonageVoiceCallModuleInterface)
  : new Proxy({} as RNVonageVoiceCallModuleInterface, {
      get() {
        throw new Error(LINKING_ERROR);
      },
    });

const NativeEventEmitter = NativeModules.EventEmitterNativeModule
  ? NativeModules.EventEmitterNativeModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export const VonageEventEmitter = NativeEventEmitter;

export class RNVonageVoiceCall {
  static async createSession(jwt: string, region: 'US' | 'EU') {
    if (region != null) {
      VonageVoice.setRegion(region);
    }

    try {
      return await VonageVoice.login(jwt, false);
    } catch (error) {
      console.error(error);
      throw error;
    }
  }

  static async answerCall(callId: string) {
    try {
      return await VonageVoice.answerCall(callId);
    } catch (error) {
      console.error(error);
      throw error;
    }
  }

  static async rejectCall(callId: string) {
    try {
      return await VonageVoice.rejectCall(callId);
    } catch (error) {
      console.error(error);
      throw error;
    }
  }

  static async hangup(callId: string) {
    try {
      return await VonageVoice.hangup(callId);
    } catch (error) {
      console.error(error);
      throw error;
    }
  }
}
