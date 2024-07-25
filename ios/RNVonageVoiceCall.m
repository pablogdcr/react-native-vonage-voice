#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"

@interface RCT_EXTERN_MODULE(RNVonageClientVoice, NSObject)

RCT_EXTERN_METHOD(
  createSession:  (NSString *)jwt
  resolver:       (RCTPromiseResolveBlock)resolve
  rejecter:       (RCTPromiseRejectBlock)reject
)
// RCT_EXTERN_METHOD(registerVoipToken:(NSString *)token isSandbox:(BOOL)isSandbox resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end
