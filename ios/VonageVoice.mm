#import <React/RCTBridgeModule.h>
#import <CallKit/CallKit.h>
#import <PushKit/PushKit.h>
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

RCT_EXPORT_METHOD(login:(NSString *)jwt
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] loginWithJwt:jwt resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve
                   rejecter:(RCTPromiseRejectBlock)reject) {
     [[VonageVoice shared] logoutWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(registerVonageVoipToken:(NSString *)token
                  isSandbox:(BOOL)isSandbox
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] registerVonageVoipTokenWithToken:token isSandbox:isSandbox resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(registerVoipToken) {
    [[VonageVoice shared] registerVoipToken];
}

RCT_EXPORT_METHOD(unregisterDeviceTokens:(NSString *)deviceId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] unregisterDeviceTokensWithDeviceId:deviceId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(answerCall:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] answerCallWithCallId:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(rejectCall:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] rejectCallWithCallId:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(hangup:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] hangupCallWithCallId:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(mute:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] muteWithCallId:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(unmute:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] unmuteWithCallId:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(enableSpeaker:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] enableSpeakerWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(disableSpeaker:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] disableSpeakerWithResolve:resolve reject:reject];
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

RCT_EXPORT_METHOD(subscribeToCallEvents) {
    [[VonageVoice shared] subscribeToCallEvents];
}

RCT_EXPORT_METHOD(unsubscribeFromCallEvents) {
    [[VonageVoice shared] unsubscribeFromCallEvents];
}

@end
