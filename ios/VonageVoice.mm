#import <React/RCTBridgeModule.h>
#import <CallKit/CallKit.h>
#import <VonageClientSDKVoice/VGVoiceClient.h>
#import <react_native_vonage_voice-Swift.h>

@interface VonageVoiceModule : NSObject <RCTBridgeModule>
@end

@implementation VonageVoiceModule

RCT_EXPORT_MODULE(VonageVoice);

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(saveDebugAdditionalInfo:(NSString *)info) {
    [[VonageVoice shared] saveDebugAdditionalInfoWithInfo:(NSString * _Nullable)info];
}

RCT_EXPORT_METHOD(setRegion:(NSString *)region) {
    [[VonageVoice shared] setRegionWithRegion:region];
}

RCT_EXPORT_METHOD(createSession:(NSString *)jwt
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] loginWithJwt:jwt resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(createSessionWithSessionID:(NSString *)jwt
                  sessionID:(NSString *)sessionID
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] loginWithSessionIDWithJwt:jwt sessionID:sessionID resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(deleteSession:(RCTPromiseResolveBlock)resolve
                   rejecter:(RCTPromiseRejectBlock)reject) {
     [[VonageVoice shared] logoutWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(refreshSession:(NSString *)jwt
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] refreshSessionWithJwt:jwt resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(registerVoipToken:(NSString *)token
                  isSandbox:(BOOL)isSandbox
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] registerVoipTokenWithToken:token isSandbox:isSandbox resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(unregisterDeviceTokens:(NSString *)deviceId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] unregisterDeviceTokensWithDeviceId:deviceId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getUser:(NSString *)userIdOrName
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] getUserWithUserIdOrName:userIdOrName resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(answerCall:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] answerCallWithCallID:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(rejectCall:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] rejectCallWithCallID:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(hangup:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] hangupWithCallID:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getIsLoggedIn:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] getIsLoggedInResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(mute:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] muteWithCallID:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(unmute:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] unmuteWithCallID:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(enableSpeaker:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] enableSpeakerWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(disableSpeaker:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] disableSpeakerWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(getCallStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] getCallStatusWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(serverCall:(NSString *)to
                  customData:(NSDictionary *)customData
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] serverCallTo:to customData:customData resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(sendDTMF:(NSString *)dtmf
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] sendDTMFWithDtmf:dtmf resolve:resolve reject:reject];
}

@end
