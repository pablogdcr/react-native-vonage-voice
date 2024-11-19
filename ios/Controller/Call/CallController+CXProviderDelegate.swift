import Foundation
import CallKit
import VonageClientSDKVoice

extension VonageCallController: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let _ = self.vonageActiveCalls.value[action.callUUID]  else {
            action.fail()
            return
        }

        self.contactService.changeTemporaryContactImage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            self.contactService.resetCallInfo()

            self.client.answer(action.callUUID.toVGCallID()) { err in
                guard err == nil else {
                    self.logger.logSlack(message: ":x: Failed to answer call! Error: \(String(describing: err))")
                    provider.reportCall(with: action.callUUID, endedAt: Date(), reason: .failed)
                    self.vonageCallUpdates.send((action.callUUID, .completed(remote: false, reason: .failed)))
                    action.fail()
                    return
                }
                self.vonageCallUpdates.send((action.callUUID, .answered))
                action.fulfill()
            }
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        self.contactService.resetCallInfo()
        guard let call = self.vonageActiveCalls.value[action.callUUID]  else {
            action.fail()
            return
        }
                
        if case .inbound(_,_,.ringing,_) = call {
            self.client.reject(action.callUUID.toVGCallID()){ err in
                action.fulfill()
            }
        } else {
            self.client.hangup(action.callUUID.toVGCallID()){ err in
                action.fulfill()
            }
        }
    }

    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let _ = self.vonageActiveCalls.value[action.callUUID]  else {
            action.fail()
            return
        }
        
        if (action.isMuted == true) {
            self.client.mute(action.callUUID.toVGCallID()) { err in
                if let error = err {
                    self.logger.logSlack(message: "Failed to mute call: \(error)")
                    action.fail()
                    return
                }
                action.fulfill()
            }
        }
        else {
            self.client.unmute(action.callUUID.toVGCallID()) { err in
                if let error = err {
                    self.logger.logSlack(message: "Failed to unmute call: \(error)")
                    action.fail()
                    return
                }
                action.fulfill()
            }
        }
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VGVoiceClient.enableAudio(audioSession)
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        VGVoiceClient.disableAudio(audioSession)
    }

    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction){
        guard let _ = self.vonageActiveCalls.value[action.callUUID]  else {
            action.fail()
            return
        }
        let callId = action.callUUID.toVGCallID()
        if (action.isOnHold) {
            self.client.mute(callId) { error in
                if let error = error {
                    self.logger.logSlack(message: "Failed to mute call on hold: \(error)")
                    return
                }
                self.client.enableEarmuff(callId) { error in
                    if let error = error {
                        self.logger.logSlack(message: "Failed to enable earmuff on hold: \(error)")
                        return
                    }
                }
            }
        } else {
            self.client.unmute(callId) { error in
                if let error = error {
                    self.logger.logSlack(message: "Failed to unmute call on hold: \(error)")
                    return
                }
                self.client.disableEarmuff(callId) { error in
                    if let error = error {
                        self.logger.logSlack(message: "Failed to disable earmuff on hold: \(error)")
                        return
                    }
                }
            }
        }
        action.fulfill()
    }
}

extension VonageCallController {
    func bindCallkit() {
        self.calls
            .flatMap { $0 }
            .sink { call in
                switch (call) {
                case let .outbound(callId,to,status,_):
                    switch(status) {
                    case .ringing:
                        // Outbound calls need reporting to callkit
                        self.cxController.requestTransaction(
                            with: CXStartCallAction(call: callId, handle: CXHandle(type: .generic, value: to)),
                            completion: { err in
                                guard err == nil else {
                                    self.client.hangup(callId.toVGCallID()) { err in
                                        self.logger.logSlack(message: "Failed to report start outboud call: \(String(describing: err))")
                                    }
                                    return
                                }
                                self.callProvider.reportOutgoingCall(with: callId, startedConnectingAt: Date())
                            }
                        )
                        
                    case .answered:
                        // Answers are remote by definition, so report them
                        self.callProvider.reportOutgoingCall(with: callId, connectedAt: Date())
                        let update = CXCallUpdate()
                        update.remoteHandle = CXHandle(type: .phoneNumber, value: "+\(to)")
                        update.supportsDTMF = true
                        update.supportsHolding = true
                        update.supportsGrouping = false
                        update.hasVideo = false
                        self.callProvider.reportCall(with: callId, updated: update)
                        
                    case .completed(true, .some(let reason)):
                        // Report Remote Hangups + Cancels
                        self.callProvider.reportCall(with: callId, endedAt: Date(), reason: reason)
                        
                    default:
                        // Nothing needed to report for local hangups
                        return
                    }
                    
                case let .inbound(callId,from,status,_):
                    switch (status) {
                    case .ringing:
                        // Report new Inbound calls so we follow PushKit and Callkit Rules
                        let callUpdate = CXCallUpdate()
                                
                        callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: "+\(from)")
                        self.callProvider.reportNewIncomingCall(with: callId, update: callUpdate) { err in
                            if err != nil {
                                self.logger.logSlack(message: ":warning: Failed to report new incoming call \(callId). Error: \(String(describing: err))")
                                self.client.reject(callId.toVGCallID()) { err in
                                    if let err = err {
                                        self.logger.logSlack(message: "Failed to reject failed call. \(err)")
                                    }
                                }
                            }
                        }
                        
                    case .completed(true,.some(let reason)):
                        // Report Remote Hangups + Cancels
                        self.callProvider.reportCall(with: callId, endedAt: Date(), reason: reason)
                        
                    default:
                        // Nothing needed to report since answering requires local CXAction
                        // Same for local hangups
                        return
                    }
                }
            }
            .store(in: &cancellables)
    }
}
