#import <Foundation/Foundation.h>
#import <PushKit/PushKit.h>
#import <React/RCTBridgeModule.h>

@interface VonageVoice : NSObject

+ (instancetype)shared;

// VoIP Push Notification Methods
+ (void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type;
+ (void)didInvalidatePushTokenForType:(PKPushType)type;

@end
