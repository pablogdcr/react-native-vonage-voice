import Foundation
import CallKit
import VonageClientSDKVoice

extension VonageVoice: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        self.contactService.resetCallInfo()
        callStartedAt = nil
        callID = nil
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])
        
        guard let callID = self.callID else {
            action.fail()
            return
        }
        
        self.contactService.changeTemporaryContactImage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            self.contactService.resetCallInfo()
            
            self.waitForRefreshCompletion {
                self.client.answer(callID) { error in
                    if error == nil {
                        self.callStartedAt = Date()
                        self.outbound = false
                        EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])
                        
                        action.fulfill()
                    } else {
                        provider.reportCall(with: action.callUUID, endedAt: Date(), reason: .failed)
                        self.callStartedAt = nil
                        self.callID = nil
                        self.outbound = false
                        EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callID, "reason": "completed"])
                        self.logger.logSlack(message: ":x: Failed to answer call\nid: \(callID)\nerror: \(String(describing: error))")
                        action.fail()
                    }
                }
            }
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        self.contactService.resetCallInfo()
        self.waitForRefreshCompletion {
            guard let callID = self.callID else {
                action.fail()
                return
            }
            
            if self.isCallActive() {
                self.client.hangup(callID) { error in
                    EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": self.callID, "reason": "completed"])
                    if error == nil {
                        self.callStartedAt = nil
                        self.callID = nil
                        self.outbound = false
                        action.fulfill()
                    } else {
                        self.logger.logSlack(message: ":x: Failed to hangup call\nid: \(callID)\nerror: \(String(describing: error))")
                        action.fail()
                    }
                }
            } else {
                self.client.reject(callID) { error in
                    EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": self.callID, "caller": self.caller])
                    if error == nil {
                        self.callStartedAt = nil
                        self.callID = nil
                        self.outbound = false
                        action.fulfill()
                    } else {
                        self.logger.logSlack(message: ":x: Failed to reject call\nid: \(callID)\nerror: \(String(describing: error))")
                        action.fail()
                    }
                }
            }
        }
    }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VGVoiceClient.enableAudio(audioSession)
        logger.logSlack(message: "Enabling audio (didActivate)", admin: true)
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        VGVoiceClient.disableAudio(audioSession)
        logger.logSlack(message: "Disabling audio (didDeactivate)", admin: true)
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let callID = self.callID else {
            logger.logSlack(message: ":interrobang: Trying to mute/unmute a call with callID null")
            action.fail()
            return
        }
        if action.isMuted {
            self.client.mute(callID) { error in
                if error == nil {
                    action.fulfill()
                    return
                } else {
                    self.logger.logSlack(message: ":speaker: Failed to mute\nid: \(String(describing: self.callID))\nerror: \(String(describing: error))")
                    action.fail()
                    return
                }
            }
        } else {
            self.client.unmute(callID) { error in
                if error == nil {
                    action.fulfill()
                    return
                } else {
                    self.logger.logSlack(message: ":speaker: Failed to mute\nid: \(String(describing: self.callID))\nerror: \(String(describing: error))")
                    action.fail()
                    return
                }
            }
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction){
        guard let callID = self.callID else {
            logger.logSlack(message: ":interrobang: Trying to mute/unmute a call with callID null from CXSetHeldCallAction")
            action.fail()
            return
        }
        
        if (action.isOnHold) {
            self.logger.logSlack(message: ":open_mouth: Unmute and disable earmuff")
            self.client.mute(callID) { error in
                if error == nil {
                    self.client.enableEarmuff(callID) { error in
                        if error == nil {
                            action.fulfill()
                        }
                    }
                }
            }
        } else {
            self.logger.logSlack(message: ":heart_eyes: Unmute and disable earmuff")
            self.client.unmute(callID) { error in
                if error == nil {
                    self.client.disableEarmuff(callID) { error in
                        if error == nil {
                            action.fulfill()
                        }
                    }
                }
            }
        }
        action.fulfill()
    }
}
