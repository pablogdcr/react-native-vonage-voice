import {
  NativeModules,
  Platform,
  NativeEventEmitter,
  type EmitterSubscription,
} from 'react-native';
import {
  type AudioRouteChangeEvent,
  type CallEvent,
  type MuteChangedEvent,
  type AudioDevice,
  CallStatus,
} from './types';

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
  reconnectCall(callId: string): Promise<{ success: true } | null>;
  addCallEventListener(
    callback: (event: CallEvent) => void
  ): EmitterSubscription;
  addAudioRouteChangeListener(
    callback: (event: AudioRouteChangeEvent) => void
  ): EmitterSubscription;
  addMutedEventListener(
    callback: (event: MuteChangedEvent) => void
  ): EmitterSubscription;
  subscribeToVoipToken(): EmitterSubscription;
  subscribeToVoipTokenInvalidation(): EmitterSubscription;
  registerVonageVoipToken: (
    token: string,
    isSandbox: boolean
  ) => Promise<string | null>;
  registerVoipToken(): void;
  getAvailableAudioDevices(): Promise<AudioDevice[] | null>;
  setAudioDevice(deviceId: string): Promise<{ success: true } | null>;
  playDTMFTone(key: string): Promise<{ success: true }>;
  stopDTMFTone(): Promise<{ success: true }>;
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
  android: NativeModules.VonageVoiceModule
    ? (NativeModules.VonageVoiceModule as RNVonageVoiceCallModuleInterface)
    : new Proxy({} as RNVonageVoiceCallModuleInterface, {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }),
});

// Create a new event type for VoIP registration
type VoipRegistrationEvent = {
  token: string;
};

class RNVonageVoiceCall {
  static setDebugAdditionalInfo(info: string) {
    VonageVoice!.saveDebugAdditionalInfo(info);
  }

  static async login(jwt: string, region?: 'US' | 'EU') {
    if (region != null) {
      VonageVoice!.setRegion(region);
    }

    return VonageVoice!.login(jwt);
  }

  static logout() {
    return VonageVoice!.logout();
  }

  static unregisterDeviceTokens(deviceId: string) {
    return VonageVoice!.unregisterDeviceTokens(deviceId);
  }

  static answerCall(callId: string) {
    return VonageVoice!.answerCall(callId);
  }

  static rejectCall(callId: string) {
    return VonageVoice!.rejectCall(callId);
  }

  static hangup(callId: string) {
    return VonageVoice!.hangup(callId);
  }

  static mute(callId: string) {
    return VonageVoice!.mute(callId);
  }

  static unmute(callId: string) {
    return VonageVoice!.unmute(callId);
  }

  static enableSpeaker() {
    return VonageVoice!.enableSpeaker();
  }

  static disableSpeaker() {
    return VonageVoice!.disableSpeaker();
  }

  static serverCall(to: string, customData?: Record<string, any>) {
    return VonageVoice!.serverCall(to, customData);
  }

  static sendDTMF(dtmf: string) {
    return VonageVoice!.sendDTMF(dtmf);
  }

  static reconnectCall(callId: string) {
    return VonageVoice!.reconnectCall(callId);
  }

  static addCallEventListener(callback: (event: CallEvent) => void) {
    return eventEmitter.addListener('callEvents', callback);
  }

  static registerVonageVoipToken(token: string, isSandbox?: boolean) {
    try {
      return VonageVoice!.registerVonageVoipToken(token, isSandbox ?? false);
    } catch (error) {
      throw error;
    }
  }

  static registerVoipToken() {
    VonageVoice!.registerVoipToken();
  }

  static subscribeToVoipToken(
    callback: (event: VoipRegistrationEvent) => void
  ) {
    return eventEmitter.addListener('register', callback);
  }

  static subscribeToVoipTokenInvalidation(callback: () => void) {
    return eventEmitter.addListener('voipTokenInvalidated', callback);
  }

  static addAudioRouteChangeListener(
    callback: (event: AudioRouteChangeEvent) => void
  ) {
    return eventEmitter.addListener('audioRouteChanged', callback);
  }

  static addMutedEventListener(callback: (event: MuteChangedEvent) => void) {
    return eventEmitter.addListener('muteChanged', callback);
  }

  static getAvailableAudioDevices() {
    return VonageVoice!.getAvailableAudioDevices();
  }

  static setAudioDevice(deviceId: string) {
    return VonageVoice!.setAudioDevice(deviceId);
  }

  static playDTMFTone(key: string) {
    return VonageVoice!.playDTMFTone(key);
  }

  static stopDTMFTone() {
    return VonageVoice!.stopDTMFTone();
  }
}

export {
  CallStatus,
  type CallEvent,
  type VoipRegistrationEvent,
  type AudioDevice,
};

export default RNVonageVoiceCall;
