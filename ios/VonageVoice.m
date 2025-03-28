#import "VonageVoice.h"

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
    [VonageVoice registerVoipToken];
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

RCT_EXPORT_METHOD(reconnectCall:(NSString *)callId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] reconnectCallWithCallId:callId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(subscribeToCallEvents) {
    [[VonageVoice shared] subscribeToCallEvents];
}

RCT_EXPORT_METHOD(subscribeToAudioRouteChange) {
    [[VonageVoice shared] subscribeToAudioRouteChange];
}

RCT_EXPORT_METHOD(unsubscribeFromCallEvents) {
    [[VonageVoice shared] unsubscribeFromCallEvents];
}

RCT_EXPORT_METHOD(unsubscribeFromAudioRouteChange) {
    [[VonageVoice shared] unsubscribeFromAudioRouteChange];
}

RCT_EXPORT_METHOD(getAvailableAudioDevices:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] getAvailableAudioDevicesWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(setAudioDevice:(NSString *)deviceId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] setAudioDeviceWithDeviceId:deviceId resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(playDTMFTone:(NSString *)key
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] playDTMFToneWithKey:key resolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(stopDTMFTone:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [[VonageVoice shared] stopDTMFToneWithResolve:resolve reject:reject];
}
@end
