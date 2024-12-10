//
//  Call.swift
//

import Foundation
import CallKit

enum CallStatus {
    case ringing
    case answered
    case reconnecting
    case completed(remote:Bool, reason:CXCallEndedReason?)
}

// Helper method to convert CallStatus to string description
extension CallStatus {
    var description: String {
        switch self {
        case .ringing: return "ringing"
        case .answered: return "answered"
        case .reconnecting: return "reconnecting"
        case .completed: return "completed"
        }
    }
}

extension CallStatus: Equatable {}

enum Call {
    case inbound(id:UUID, from:String, status:CallStatus, startedAt:Date? = nil)
    case outbound(id:UUID, to:String, status:CallStatus, startedAt:Date? = nil)
    
    init(call:Self, status:CallStatus) {
        switch (call){
        case .inbound(let id, let from, _, let startedAt):
            let newStartedAt = status == .answered ? Date.now : startedAt
            self = .inbound(id:id, from: from, status:status, startedAt: newStartedAt)
        case .outbound(let id, let to, _, let startedAt):
            let newStartedAt = status == .answered ? Date() : startedAt
            self = .outbound(id: id, to: to, status:status, startedAt: newStartedAt)
        }
    }

    var status: CallStatus {
        get {
            switch(self) {
            case .outbound(_,_,let status,_):
                return status
            case .inbound(_,_,let status,_):
                return status
            }
        }
    }
    
    var id: UUID {
        get {
            switch(self) {
            case .outbound(let callId,_,_,_):
                return callId
            case .inbound(let callId,_,_,_):
                return callId
            }
        }
    }
    
    var isOutbound: Bool {
        switch self {
        case .outbound: return true
        case .inbound: return false
        }
    }
    
    var isInbound: Bool {
        return !isOutbound
    }

    var phoneNumber: String {
        switch self {
        case .outbound(_,let to,_, _):
            return to
        case .inbound(_,let from,_,_):
            return from
        }
    }

    var startedAt: Date? {
        switch self {
        case .outbound(_,_,_,let startedAt):
            return startedAt
        case .inbound(_,_,_,let startedAt):
            return startedAt
        }
    }
}
