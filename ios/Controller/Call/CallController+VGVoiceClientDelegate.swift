import Foundation
import VonageClientSDKVoice
import CallKit

typealias CallUpdate = (call:UUID, leg:UUID, status:String)

extension VonageCallController: VGVoiceClientDelegate {
    // MARK: VGVoiceClientDelegate Sessions

    public func clientWillReconnect(_ client: VGBaseClient) {
        vonageWillReconnect.send(())
    }
    
    public func clientDidReconnect(_ client: VGBaseClient) {
        vonageDidReconnect.send(())
    }

    public func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
        vonageSessionError.send(reason)
    }

    // MARK: VGVoiceClientDelegate Invites

    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: String, from caller: String, with type: VGVoiceChannelType) {
        let uuid = UUID(uuidString: callId)!

        self.vonageCalls.send(Call.inbound(id: uuid, from: caller, status: .ringing))
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: VGCallId, with reason: VGVoiceInviteCancelReason) {
        let uuid = UUID(uuidString: callId)!
        var cxreason: CXCallEndedReason = .failed

        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[VGVoiceClientDelegate] - didReceiveInviteCancelForCall (reason raw value: \(reason.rawValue))")
        switch (reason){
        case .remoteTimeout: cxreason = .unanswered
        case .answeredElsewhere: cxreason = .answeredElsewhere
        case .rejectedElsewhere: cxreason = .declinedElsewhere
        case .remoteCancel: cxreason = .remoteEnded
        case .unknown: fatalError()
            
        @unknown default:
            fatalError()
        }
        self.vonageCallUpdates.send((uuid, .completed(remote: true, reason: cxreason)))
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        let uuid = UUID(uuidString: callId)!
        var cxreason: CXCallEndedReason = .failed

        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[VGVoiceClientDelegate] - didReceiveHangupForCall")
        switch (reason){
        case .mediaTimeout: cxreason = .unanswered
        case .remoteReject: cxreason = .declinedElsewhere
        case .localHangup: cxreason = .remoteEnded
        case .remoteHangup: cxreason = .remoteEnded
        case .unknown: cxreason = .unanswered
        case .remoteNoAnswerTimeout: cxreason = .unanswered
        @unknown default:
            fatalError()
        }
        self.vonageCallUpdates.send((uuid, .completed(remote: true, reason: cxreason)))
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveMediaDisconnectForCall callId: VGCallId, reason: VGCallDisconnectReason) {
        let uuid = UUID(uuidString: callId)!

        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[VGVoiceClientDelegate] - didReceiveMediaDisconnectForCall")
        self.vonageCallUpdates.send((uuid, .completed(remote: false, reason: .failed)))
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectingForCall callId: VGCallId) {
        let uuid = UUID(uuidString: callId)!

        self.vonageCallUpdates.send((uuid, .reconnecting))
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectionForCall callId: VGCallId) {
        let uuid = UUID(uuidString: callId)!

        self.vonageCallUpdates.send((uuid, .answered))
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveMediaErrorForCall callId: String, error: VGError) {
        self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Receive media error for call \(callId): \(error)")
    }

    // MARK: VGVoiceClientDelegate LegStatus
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveLegStatusUpdateForCall callId: VGCallId, withLegId legId: String, andStatus status: VGLegStatus) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[VGVoiceClientDelegate] - didReceiveLegStatusUpdateForCall: \(callId), legId: \(legId), status: \(status)")
        let uuid = UUID(uuidString: callId)!

        if let call = self.vonageActiveCalls.value[uuid],
           call.isOutbound == true,
           status == .answered {
            self.vonageCallUpdates.send((uuid, .answered))
        }
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveCallTransferForCall callId: VGCallId, withConversationId conversationId: String) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[VGVoiceClientDelegate] - didReceiveCallTransferForCall: \(callId)")
//        // this will only be triggered for our own legs
//        let uuid = UUID(uuidString: callId)!
//        vonageCallUpdates.send((uuid, .answered)) // report to Call Kit
    }
}
