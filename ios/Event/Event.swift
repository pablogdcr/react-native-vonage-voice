//
//  Event.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation

enum Event: String {
    case callEvents
    
    static var supportedEvents: [String] {
        return [
            Event.callEvents.rawValue,
        ]
    }
}