import {
  NativeModules,
} from 'react-native';

const RNVonageVoiceCallModule = NativeModules.RNVonageVoiceCall;

export default class RNVonageVoiceCall {
  static createSession(jwt, region) {
    if (region != null) {
      RNVonageVoiceCallModule.setRegion(region);
    }
    return RNVonageVoiceCallModule.login(jwt, false);
  }

  static answer(callId) {
    return new Promise((resolve, reject) => {
      RNVonageVoiceCallModule.answer(callId, (error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  static reject(callId) {
    return new Promise((resolve, reject) => {
      RNVonageVoiceCallModule.reject(callId, (error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  // static call(number) {
  //   return RNVonageVoiceCallModule.call(number);
  // }

  // static endCall() {
  //   return RNVonageVoiceCallModule.endCall();
  // }
};
