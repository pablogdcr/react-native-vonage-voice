import VonageClientSDKVoice
import CallKit

extension VonageVoice: VGVoiceClientDelegate {
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, with type: VGVoiceChannelType) {
        self.callID = callId
        self.caller = caller
        self.outbound = false
        EventEmitter.shared.sendEvent(withName: Event.receivedInvite.rawValue, body: ["callId": callId, "caller": caller, "outbound": outbound])
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": callId, "reason": reason.rawValue])
        callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)

        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
        self.contactService.resetCallInfo()
        
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
        if reason == .answeredElsewhere {
            callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .answeredElsewhere)
        } else {
            callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
        }
        EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveLegStatusUpdateForCall callId: String, withLegId legId: String, andStatus status: VGLegStatus) {
        switch (status) {
        case .completed:
            EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "reason": "completed"])
            self.callStartedAt = nil
            self.callID = nil
            self.outbound = false
            self.contactService.resetCallInfo()
            
            self.callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
            break
            
        case .ringing:
            self.callID = callId
            if self.outbound == true {
                self.callController.requestTransaction(with: [CXStartCallAction(call: UUID(uuidString: callId)!, handle: CXHandle(type: .generic, value: ""))], completion: { _ in })
            }
            EventEmitter.shared.sendEvent(withName: Event.callRinging.rawValue, body: ["callId": callId, "caller": caller!, "outbound": outbound])
            break
            
        case .answered:
            if self.outbound == true {
                self.callStartedAt = Date()
                self.callKitProvider.reportOutgoingCall(with: UUID(uuidString: callId)!, connectedAt: Date())
                let update = CXCallUpdate()
                
                update.supportsDTMF = true
                update.supportsHolding = true
                update.supportsGrouping = false
                update.hasVideo = false
                
                self.callKitProvider.reportCall(with: UUID(uuidString: callId)!, updated: update)
            }
            EventEmitter.shared.sendEvent(withName: Event.callAnswered.rawValue, body: ["callId": callId, "caller": caller!, "outbound": outbound])
            break
            
        default:
            print("Unknown status: \(status)")
        }
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectingForCall callId: String) {
        logger.logSlack(message: "Media reconnecting", admin: true)
        EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnecting"])
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectionForCall callId: String) {
        logger.logSlack(message: "Media reconnected", admin: true)
        EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnected"])
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaDisconnectForCall callId: String, reason: VGCallDisconnectReason) {
        logger.logSlack(message: "Media disconnected", admin: true)
        EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "disconnected", "reason": reason.rawValue])
    }
    
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaErrorForCall callId: String, error: VGError) {
        logger.logSlack(message: ":warning: Media error:\ncall id:\(callId)\nerror: \(String(describing: error))")
    }
    
    @objc  public func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
        let reasonString: String!
        
        logger.logSlack(message: ":warning: Session error:\nreason: \(String(describing: reason))", admin: true)
        switch reason {
        case .tokenExpired:
            reasonString = "Expired Token"
        case .pingTimeout, .transportClosed:
            reasonString = "Network Error"
        default:
            reasonString = "Unknown"
        }
        if reason != .tokenExpired {
            logger.logSlack(message: ":warning: Session error:\nreason: \(String(describing: reason))\nreasonString: \(String(describing: reasonString))")
        }
        EventEmitter.shared.sendEvent(withName: Event.receivedSessionError.rawValue, body: ["reason": reasonString])
    }
}
