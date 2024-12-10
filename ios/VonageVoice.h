#import <Foundation/Foundation.h>
#import <PushKit/PushKit.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTViewManager.h>

@interface VonageVoice : NSObject

+ (instancetype _Nonnull)shared;

// VoIP Push Notification Methods
+ (void)didUpdatePushCredentials:(PKPushCredentials * _Nullable)credentials forType:(PKPushType _Nullable )type;
+ (void)didInvalidatePushTokenForType:(PKPushType _Nullable )type;

// Configuration Methods
- (void)saveDebugAdditionalInfoWithInfo:(NSString * _Nullable)info;
- (void)setRegionWithRegion:(NSString * _Nullable)region;
+ (void)registerVoipToken;

// Authentication Methods
- (void)loginWithJwt:(NSString * _Nonnull)jwt resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)logoutWithResolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;

// Push Token Management
- (void)registerVonageVoipTokenWithToken:(NSString * _Nonnull)token isSandbox:(BOOL)isSandbox resolve:(RCTPromiseResolveBlock _Nonnull)resolve reject:(RCTPromiseRejectBlock _Nonnull)reject;
- (void)unregisterDeviceTokensWithDeviceId:(NSString * _Nonnull)deviceId resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;

// Call Control Methods
- (void)answerCallWithCallId:(NSString *_Nonnull)callId resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)rejectCallWithCallId:(NSString *_Nonnull)callId resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)hangupCallWithCallId:(NSString *_Nonnull)callId resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)muteWithCallId:(NSString *_Nonnull)callId resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)unmuteWithCallId:(NSString *_Nonnull)callId resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;

// Audio Control Methods
- (void)enableSpeakerWithResolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)disableSpeakerWithResolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;

// Outbound Call Methods
- (void)serverCallTo:(NSString *_Nonnull)to customData:(NSDictionary<NSString *, NSString *> *_Nonnull)customData resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;
- (void)sendDTMFWithDtmf:(NSString *_Nonnull)dtmf resolve:(RCTPromiseResolveBlock _Nonnull )resolve reject:(RCTPromiseRejectBlock _Nonnull )reject;

// Event Subscription Methods
- (void)subscribeToCallEvents;
- (void)unsubscribeFromCallEvents;
- (void)subscribeToAudioRouteChange;
- (void)unsubscribeFromAudioRouteChange;

@end
