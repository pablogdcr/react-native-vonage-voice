import {
  NativeModules,
  Platform,
  // NativeEventEmitter,
} from 'react-native';

const RNVonageVoiceCallModule = NativeModules.RNVonageVoiceCall;

// const eventEmitter = new NativeEventEmitter(RNVonageVoiceCallManager);
// const _eventHandlers = new Map();

export default class RNVonageVoiceCall {
  static createSession(jwt, region) {
    return RNVonageVoiceCallModule.createSession(jwt, region);
  }

  static registerVoipToken(token) {
    return RNVonageVoiceCallModule.registerVoipToken(token);
  }

  static call(number) {
    return RNVonageVoiceCallModule.call(number);
  }

  static endCall() {
    return RNVonageVoiceCallModule.endCall();
  }
};
