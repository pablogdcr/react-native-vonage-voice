import { NativeModules, Platform, NativeEventEmitter } from 'react-native';
import type { EventWithCallId, EventWithReason } from './types';

const LINKING_ERROR =
  `The package 'react-native-vonage-voice' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

interface RNVonageVoiceCallModuleInterface {
  setRegion(region: 'US' | 'EU'): void;
  login(jwt: string): Promise<string | null>;
  registerVoipToken: (
    token: string,
    isSandbox: boolean
  ) => Promise<string | null>;
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

const VonageNativeEventEmitter = NativeModules.EventEmitterNativeModule
  ? NativeModules.EventEmitterNativeModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

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

  static async createSession(jwt: string, region: 'US' | 'EU') {
    if (region != null) {
      VonageVoice.setRegion(region);
    }

    try {
      return await VonageVoice.login(jwt);
    } catch (error) {
      console.error(error);
      throw error;
    }
  }

  static async registerVoipToken(token: string, isSandbox?: boolean) {
    try {
      return await VonageVoice.registerVoipToken(token, isSandbox ?? false);
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

  static onReceivedInvite(callback: (event: EventWithCallId) => void) {
    return this.eventEmitter.addListener('receivedInvite', callback);
  }

  static onReceivedHangup(callback: (event: EventWithReason) => void) {
    return this.eventEmitter.addListener('receivedHangup', callback);
  }

  static onReceivedCancel(callback: (event: EventWithReason) => void) {
    return this.eventEmitter.addListener('receivedCancel', callback);
  }

  static onConnectionStatusChange(callback: (event: any) => void) {
    return this.eventEmitter.addListener('connectionStatusChange', callback);
  }
}

export default RNVonageVoiceCall;
