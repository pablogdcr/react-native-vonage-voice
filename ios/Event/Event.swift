//
//  Event.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation

enum Event: String {
    case callEvents
    case register
    case voipTokenInvalidated
    case audioRouteChanged
    case muteChanged
    
    static var supportedEvents: [String] {
        return [
            Event.callEvents.rawValue,
            Event.register.rawValue,
            Event.voipTokenInvalidated.rawValue,
            Event.audioRouteChanged.rawValue,
            Event.muteChanged.rawValue,
        ]
    }
}
