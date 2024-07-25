#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(RNVonageVoiceCall, NSObject)

RCT_EXTERN_METHOD(
  createSession:  (NSString *)jwt
  resolver:       (RCTPromiseResolveBlock)resolve
  rejecter:       (RCTPromiseRejectBlock)reject
)
RCT_EXTERN_METHOD(
  registerVoipToken:  (NSString *)token
  resolver:           (RCTPromiseResolveBlock)resolve
  rejecter:           (RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(registerForVoIPPushes)

@end
