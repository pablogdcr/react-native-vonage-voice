//
//  Event.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation

enum Event: String {
    case callConnecting
    case callAnswered
    case callRejected
    case callRinging
    case connectionStatusChanged
    case receivedCancel
    case receivedHangup
    case receivedInvite
    case receivedSessionError
    case receiveLegStatusUpdate
    
    static var supportedEvents: [String] {
        return [
            Event.callConnecting.rawValue,
            Event.callAnswered.rawValue,
            Event.callRejected.rawValue,
            Event.callRinging.rawValue,
            Event.connectionStatusChanged.rawValue,
            Event.receivedCancel.rawValue,
            Event.receivedHangup.rawValue,
            Event.receivedInvite.rawValue,
            Event.receivedSessionError.rawValue,
            Event.receiveLegStatusUpdate.rawValue
        ]
    }
}
