#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(RNVonageVoiceCall, NSObject)

RCT_EXTERN_METHOD(
  createSession:  (NSString *)jwt
  region:         (NSString *)region
  resolver:       (RCTPromiseResolveBlock)resolve
  rejecter:       (RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  registerVoipToken:  (NSString *)token
  resolver:           (RCTPromiseResolveBlock)resolve
  rejecter:           (RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  answer:             (NSString *)callId
  resolver:           (RCTPromiseResolveBlock)resolve
  rejecter:           (RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  reject:             (NSString *)callId
  resolver:           (RCTPromiseResolveBlock)resolve
  rejecter:           (RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  call:     (NSString *)number
  resolver: (RCTPromiseResolveBlock)resolve
  rejecter: (RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  endCall:   (RCTPromiseResolveBlock)resolve
  rejecter: (RCTPromiseRejectBlock)reject
)

@end