//
//  Event.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation

enum Event: String {
    case connectionStatusChanged
    case receivedInvite
    case receivedHangup
    case receivedCancel
    case receivedSessionError
    
    static var supportedEvents: [String] {
        return [
            Event.connectionStatusChanged.rawValue,
            Event.receivedInvite.rawValue,
            Event.receivedHangup.rawValue,
            Event.receivedCancel.rawValue,
            Event.receivedSessionError.rawValue
        ]
    }
}
