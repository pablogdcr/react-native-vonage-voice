//
//  EventEmitterNativeModule.m
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(EventEmitterNativeModule, RCTEventEmitter)

RCT_EXTERN_METHOD(sendEventWithName:(NSString *)name body:(id)body)

@end
