import { NativeModules, Platform, NativeEventEmitter } from 'react-native';
import type {
  EventWithCallId,
  EventWithConnectionStatus,
  EventWithReason,
} from './types';

const LINKING_ERROR =
  `The package 'react-native-vonage-voice' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

// interface VGVoiceLeg {
//   legId: string;
//   conversationId: string;
//   direction: string;
//   status: string;
//   startTime: string;
//   endTime: string;
//   type: string;
//   from: any;
//   to: any;
//   mediaState: any;
// }

interface RNVonageVoiceCallModuleInterface {
  saveDebugAdditionalInfo(info: string): void;
  setRegion(region: 'US' | 'EU'): void;
  createSession(jwt: string): Promise<string | null>;
  createSessionWithSessionID(
    jwt: string,
    sessionID: string
  ): Promise<string | null>;
  deleteSession(): Promise<{ success: true } | null>;
  refreshSession(jwt: string): Promise<{ success: true } | null>;
  getIsLoggedIn(): Promise<boolean>;
  registerVoipToken: (
    token: string,
    isSandbox: boolean
  ) => Promise<string | null>;
  getUser: (userIdOrName: string) => Promise<any>;
  getCallStatus: () => Promise<{
    callId: string;
    status: 'active' | 'inactive';
    startedAt?: number;
  }>;
  unregisterDeviceTokens(deviceId: string): Promise<void>;
  answerCall(callId: string): Promise<{ success: true } | null>;
  rejectCall(callId: string): Promise<{ success: true } | null>;
  hangup(callId: string): Promise<{ success: true } | null>;
  mute(callId: string): Promise<{ success: true } | null>;
  unmute(callId: string): Promise<{ success: true } | null>;
  enableSpeaker(): Promise<{ success: true } | null>;
  disableSpeaker(): Promise<{ success: true } | null>;
  // getCallLegs(callId: string): Promise<{ legs: VGVoiceLeg[]; previousCursor: string; nextCursor: string }>;
  handleIncomingPushNotification(notification: {
    [key: string]: string;
  }): Promise<string | null>;
  serverCall(
    to: string,
    customData?: Record<string, string>
  ): Promise<{ callId: string }>;
  sendDTMF(callId: string, dtmf: string): Promise<{ success: true } | null>;
}

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

const VonageNativeEventEmitter = Platform.select({
  ios: NativeModules.EventEmitterNativeModule
    ? NativeModules.EventEmitterNativeModule
    : new Proxy(
        {},
        {
          get() {
            throw new Error(LINKING_ERROR);
          },
        }
      ),
  android: null,
});

type NativeModule = {
  /**
   * Add the provided eventType as an active listener
   * @param eventType name of the event for which we are registering listener
   */
  addListener: (eventType: string) => void;

  /**
   * Remove a specified number of events.  There are no eventTypes in this case, as
   * the native side doesn't remove the name, but only manages a counter of total
   * listeners
   * @param count number of listeners to remove (of any type)
   */
  removeListeners: (count: number) => void;
};

const VonageEventEmitter = VonageNativeEventEmitter as NativeModule;

class RNVonageVoiceCall {
  private static eventEmitter = new NativeEventEmitter(VonageEventEmitter);

  static setDebugAdditionalInfo(info: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return;
    }
    VonageVoice!.saveDebugAdditionalInfo(info);
  }

  static async createSession(
    jwt: string,
    region?: 'US' | 'EU',
    sessionID?: string
  ) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return;
    }
    if (region != null) {
      VonageVoice!.setRegion(region);
    }

    if (sessionID) {
      return await VonageVoice!.createSessionWithSessionID(jwt, sessionID);
    }
    return await VonageVoice!.createSession(jwt);
  }

  static refreshSession(jwt: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }

    return VonageVoice!.refreshSession(jwt);
  }

  static deleteSession() {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }

    return VonageVoice!.deleteSession();
  }

  static isLoggedIn() {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.getIsLoggedIn();
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

  static getUser(userIdOrName: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.getUser(userIdOrName);
  }

  static getCallStatus() {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.getCallStatus();
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

  // static async getCallLegs(callId: string) {
  //   try {
  //     return await VonageVoice!.getCallLegs(callId);
  //   } catch (error) {
  //     throw error;
  //   }
  // }

  static handleIncomingPushNotification(notification: {
    [key: string]: string;
  }) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.handleIncomingPushNotification(notification);
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

  static sendDTMF(callId: string, dtmf: string) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return new Promise<null>((resolve) => resolve(null));
    }
    return VonageVoice!.sendDTMF(callId, dtmf);
  }

  static onReceivedInvite(callback: (event: EventWithCallId) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('receivedInvite', callback);
  }

  static onReceivedHangup(callback: (event: EventWithReason) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('receivedHangup', callback);
  }

  static onReceivedCancel(callback: (event: EventWithReason) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('receivedCancel', callback);
  }

  static onCallConnecting(callback: (event: EventWithCallId) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('callConnecting', callback);
  }

  static onCallRinging(callback: (event: EventWithCallId) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('callRinging', callback);
  }

  static onCallAnswered(callback: (event: EventWithCallId) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('callAnswered', callback);
  }

  static onCallRejected(callback: (event: EventWithReason) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('callRejected', callback);
  }

  static onConnectionStatusChanged(
    callback: (event: EventWithConnectionStatus) => void
  ) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('connectionStatusChanged', callback);
  }

  static onReceiveLegStatusUpdate(callback: (event: any) => void) {
    if (Platform.OS === 'android') {
      if (__DEV__) {
        console.warn("This library doesn't support Android yet.");
      }
      return { remove: () => {} };
    }
    return this.eventEmitter.addListener('receiveLegStatusUpdate', callback);
  }
}

export default RNVonageVoiceCall;
