import {
  NativeModules,
  Platform,
  NativeEventEmitter,
  type EmitterSubscription,
} from 'react-native';
import { type CallEvent, CallStatus } from './types';

const LINKING_ERROR =
  `The package 'react-native-vonage-voice' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

interface RNVonageVoiceCallModuleInterface {
  saveDebugAdditionalInfo(info: string): void;
  setRegion(region: 'US' | 'EU'): void;
  login(jwt: string, region?: 'US' | 'EU'): Promise<{ success: true } | null>;
  logout(): Promise<{ success: true } | null>;
  registerVoipToken: (
    token: string,
    isSandbox: boolean
  ) => Promise<string | null>;
  unregisterDeviceTokens(deviceId: string): Promise<void>;
  answerCall(callId: string): Promise<{ success: true } | null>;
  rejectCall(callId: string): Promise<{ success: true } | null>;
  hangup(callId: string): Promise<{ success: true } | null>;
  mute(callId: string): Promise<{ success: true } | null>;
  unmute(callId: string): Promise<{ success: true } | null>;
  enableSpeaker(): Promise<{ success: true } | null>;
  disableSpeaker(): Promise<{ success: true } | null>;
  serverCall(to: string, customData?: Record<string, string>): Promise<string>;
  sendDTMF(dtmf: string): Promise<{ success: true } | null>;
  subscribeToCallEvents(): EmitterSubscription;
  unsubscribeFromCallEvents(): void;
}

// Create event emitter instance
const eventEmitter = new NativeEventEmitter(
  NativeModules.EventEmitterNativeModule
);

const VonageVoice = Platform.select({
  ios: NativeModules.VonageVoice
    ? (NativeModules.VonageVoice as RNVonageVoiceCallModuleInterface)
    : new Proxy({} as RNVonageVoiceCallModuleInterface, {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }),
  android: null,
});

class RNVonageVoiceCall {
  static setDebugAdditionalInfo(info: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return;
    }
    VonageVoice!.saveDebugAdditionalInfo(info);
  }

  static async login(jwt: string, region?: 'US' | 'EU') {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return;
    }
    if (region != null) {
      VonageVoice!.setRegion(region);
    }

    return VonageVoice!.login(jwt);
  }

  static logout() {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }

    return VonageVoice!.logout();
  }

  static registerVoipToken(token: string, isSandbox?: boolean) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    try {
      return VonageVoice!.registerVoipToken(token, isSandbox ?? false);
    } catch (error) {
      throw error;
    }
  }

  static unregisterDeviceTokens(deviceId: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }

    return VonageVoice!.unregisterDeviceTokens(deviceId);
  }

  static answerCall(callId: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.answerCall(callId);
  }

  static rejectCall(callId: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.rejectCall(callId);
  }

  static hangup(callId: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.hangup(callId);
  }

  static mute(callId: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.mute(callId);
  }

  static unmute(callId: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.unmute(callId);
  }

  static enableSpeaker() {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.enableSpeaker();
  }

  static disableSpeaker() {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.disableSpeaker();
  }

  static serverCall(to: string, customData?: Record<string, string>) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.serverCall(to, customData);
  }

  static sendDTMF(dtmf: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.sendDTMF(dtmf);
  }

  static subscribeToCallEvents(callback: (event: CallEvent) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return;
    }
    VonageVoice!.subscribeToCallEvents();
    return eventEmitter.addListener('callEvents', callback);
  }

  static unsubscribeFromCallEvents() {
    if (Platform.OS === 'android') {
      return;
    }
    VonageVoice!.unsubscribeFromCallEvents();
  }
}

export { CallStatus, type CallEvent };

export default RNVonageVoiceCall;
