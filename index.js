'use strict';

import {
  NativeModules,
  // NativeEventEmitter,
} from 'react-native';

const RNVonageVoiceCallModule = NativeModules.RNVonageVoiceCall;

// const eventEmitter = new NativeEventEmitter(RNVonageVoiceCallManager);
// const _eventHandlers = new Map();

export default class RNVonageVoiceCall {
  static createSession(jwt) {
    return RNVonageVoiceCallModule.createSession(jwt);
  }
};
