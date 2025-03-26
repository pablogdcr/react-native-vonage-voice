import Foundation
import CallKit
import VonageClientSDKVoice
import PhoneNumberKit

extension VonageCallController: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXStartCallAction")
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXAnswerCallAction")
        guard let _ = self.vonageActiveCalls.value[action.callUUID]  else {
            self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXAnswerCallAction - failed 1")
            action.fail()
            return
        }

        self.client.answer(action.callUUID.toVGCallID()) { err in
            self.contactService.resetCallInfo()
            guard err == nil else {
                self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":x: Failed to answer call! Error: \(String(describing: err))")
                provider.reportCall(with: action.callUUID, endedAt: Date(), reason: .failed)
                self.vonageCallUpdates.send((action.callUUID, .completed(remote: false, reason: .failed)))
                self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXAnswerCallAction - failed 2")
                action.fail()
                return
            }
            self.vonageCallUpdates.send((action.callUUID, .answered))
            self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXAnswerCallAction - fulfilled")
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXEndCallAction")
        guard let call = self.vonageActiveCalls.value[action.callUUID]  else {
            self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXEndCallAction - failed")
            action.fail()
            return
        }

        if case .inbound(_,_,.ringing,_) = call {
            self.vonageCalls.send(Call.inbound(id: action.callUUID, from: call.phoneNumber, status: .completed(remote: true, reason: .declinedElsewhere)))
            self.client.reject(action.callUUID.toVGCallID()){ err in
                self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXEndCallAction - fulfilled 1")
            }
        } else {
            self.client.hangup(action.callUUID.toVGCallID()){ err in
                self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXEndCallAction - fulfilled 2")
            }
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let _ = self.vonageActiveCalls.value[action.callUUID]  else {
            action.fail()
            return
        }
        
        if (action.isMuted == true) {
            self.client.mute(action.callUUID.toVGCallID()) { err in
                if let error = err {
                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to mute call: \(error)")
                    action.fail()
                    return
                }
                EventEmitter.shared.sendEvent(withName: Event.muteChanged.rawValue, body: ["muted": true])
            }
        } else {
            self.client.unmute(action.callUUID.toVGCallID()) { err in
                if let error = err {
                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to unmute call: \(error)")
                    action.fail()
                    return
                }
                EventEmitter.shared.sendEvent(withName: Event.muteChanged.rawValue, body: ["muted": false])
            }
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard self.vonageActiveCalls.value[action.callUUID] != nil else {
            action.fail()
            return
        }
        self.client.sendDTMF(action.callUUID.toVGCallID(), withDigits: action.digits) { err in
            if let error = err {
                self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to send DTMF: \(error)")
                action.fail()
                return
            }
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - didActivate")        
        VGVoiceClient.enableAudio(audioSession)
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - didDeactivate")
        VGVoiceClient.disableAudio(audioSession)
    }

    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXSetHeldCallAction")
        guard let _ = self.vonageActiveCalls.value[action.callUUID]  else {
            self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXSetHeldCallAction - failed")
            action.fail()
            return
        }
        let callId = action.callUUID.toVGCallID()
        if (action.isOnHold) {
            self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXSetHeldCallAction - mute")
            self.client.mute(callId) { error in
                if let error = error {
                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to mute call on hold: \(error)")
                    return
                }
                self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXSetHeldCallAction - enable earmuff")
                self.client.enableEarmuff(callId) { error in
                    if let error = error {
                        self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to enable earmuff on hold: \(error)")
                        return
                    }
                }
            }
        } else {
            self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXSetHeldCallAction - unmute")
            self.client.unmute(callId) { error in
                if let error = error {
                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to unmute call on hold: \(error)")
                    return
                }
                self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXSetHeldCallAction - disable earmuff")
                self.client.disableEarmuff(callId) { error in
                    if let error = error {
                        self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to disable earmuff on hold: \(error)")
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
                        self.cxController.requestTransaction(
                            with: CXStartCallAction(call: callId, handle: CXHandle(type: .generic, value: to)),
                            completion: { err in
                                guard err == nil else {
                                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to report start outbound call: \(String(describing: err))")
                                    self.client.hangup(callId.toVGCallID()) { err in
                                        self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to hangup outbound call: \(String(describing: err))")
                                    }
                                    return
                                }
                                self.callProvider.reportOutgoingCall(with: callId, startedConnectingAt: Date())
                            }
                        )

                    case .answered:
                        self.callProvider.reportOutgoingCall(with: callId, connectedAt: Date())
                        let callUpdate = CXCallUpdate()

                        callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: "+\(to)")
                        self.callProvider.reportCall(with: callId, updated: callUpdate)

                    case .completed(true, .some(let reason)):
                        // Report Remote Hangups + Cancels
                        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXCallUpdate - completed")
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

                        callUpdate.remoteHandle = (self.contactReady || !from.isEmpty)
                            ? CXHandle(type: .phoneNumber, value: !self.timedOut && self.contactReady ? "7222555666" : "+\(from)")
                            : nil
                        callUpdate.localizedCallerName = self.contactName ?? (self.contactReady && !self.timedOut ? PartialFormatter().formatPartial("+\(from)") : nil)
                        self.callProvider.reportNewIncomingCall(with: callId, update: callUpdate) { err in
                            if err != nil {
                                self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":warning: Failed to report new incoming call \(callId). Error: \(String(describing: err))")
                                self.client.reject(callId.toVGCallID()) { err in
                                    if let err = err {
                                        self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to reject failed call. \(err)")
                                    }
                                }
                            }
                        }

                    case .completed(true,.some(let reason)):
                        self.logger?.didReceiveLog(logLevel: .info, topic: .DEFAULT.first!, message: "[CXProviderDelegate] - CXCallUpdate - completed")
                        self.callProvider.reportCall(with: callId, endedAt: Date(), reason: reason)
                        self.contactService.resetCallInfo()
                        
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
