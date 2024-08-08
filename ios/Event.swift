//
//  Event.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation

enum Event: String {
    case callAnswered
    case callRejected
    case connectionStatusChanged
    case receivedCancel
    case receivedHangup
    case receivedInvite
    case receivedSessionError
    
    static var supportedEvents: [String] {
        return [
            Event.callAnswered.rawValue
            Event.callRejected.rawValue,
            Event.connectionStatusChanged.rawValue,
            Event.receivedCancel.rawValue,
            Event.receivedHangup.rawValue,
            Event.receivedInvite.rawValue,
            Event.receivedSessionError.rawValue,
        ]
    }
}
