//
//  EventEmitterNAtiveModule.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation
import React

@objc(EventEmitterNativeModule)
class EventEmitterNativeModule: RCTEventEmitter {
    
    override init() {
        super.init()
        EventEmitter.shared.registerEventEmitter(self)
    }
    
    @objc
    override func supportedEvents() -> [String]! {
        return Event.supportedEvents
    }
    
    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
}


