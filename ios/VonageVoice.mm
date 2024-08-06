#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(VonageVoice, NSObject)

RCT_EXTERN_METHOD(setRegion:(NSString*)region)

RCT_EXTERN_METHOD(login:(NSString *)jwt
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(registerVoipToken:(NSString *)token
                 isSandbox:(BOOL)isSandbox
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(answerCall:(NSString *)callId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(rejectCall:(NSString *)callId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(hangup:(NSString *)callId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end
