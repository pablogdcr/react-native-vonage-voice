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
    print("provider: start call")
    // This method is called when a call is initiated from the system
    // We don't need to implement anything here as we're not initiating outgoing calls
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    print("provider: set held call")
    // This method is called when a call is put on hold or taken off hold
    // We don't support call holding in this implementation
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    print("provider: timed out performing action")
    CustomLogger.logSlack(message: ":warning: Timed out performing action\n\(String(describing: action))")
    // This method is called when the provider times out while performing an action
    // We'll just fail the action in this case
    action.fail()
  }

  public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard !isCallHandled else {
      self.contactService.resetCallInfo()
      action.fulfill()
      self.isCallHandled = false
      return
    }
    EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])
    print("provider: answer call")
    self.contactService.changeTemporaryIdentifierImage()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
      self.contactService.resetCallInfo()

      self.waitForRefreshCompletion {
        guard let callID = self.callID else { return }

        self.client.answer(callID) { error in
          if error == nil {
            self.callStartedAt = Date()
            self.callID = callID
            self.outbound = false
            EventEmitter.shared.sendEvent(withName: Event.callAnswered.rawValue, body: ["callId": self.callID, "caller": self.caller])
            action.fulfill()
          } else {
            CustomLogger.logSlack(message: ":x: Failed to answer call\nid: \(callID)\nerror: \(String(describing: error))")
            action.fail()
          }
        }
      }
    }
  }
  
  public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    print("provider: end call")
    self.contactService.resetCallInfo()
    guard !isCallHandled else {
      action.fulfill()
      self.isCallHandled = false
      return
    }
    self.waitForRefreshCompletion {
      guard let callID = self.callID else {
        action.fail()
        return
      }

      if self.isCallActive() {
        print("provider: HANGUP")
        self.client.hangup(callID) { error in
          if error == nil {
            self.callStartedAt = nil
            self.callID = nil
            self.outbound = false
            EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": self.callID, "caller": self.caller])
            action.fulfill()
          } else {
            CustomLogger.logSlack(message: ":x: Failed to hangup call\nid: \(callID)\nerror: \(String(describing: error))")
            action.fail()
          }
        }
      } else if (callID != nil) {
        print("provider: REJECT")
        self.client.reject(callID) { error in
          if error == nil {
            self.callStartedAt = nil
            self.callID = nil
            self.outbound = false
            action.fulfill()
          } else {
            CustomLogger.logSlack(message: ":x: Failed to reject call\nid: \(callID)\nerror: \(String(describing: error))")
            action.fail()
          }
          EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": self.callID, "caller": self.caller])
        }
      }
    }
  }

  public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    print("provider: did activate audio session")
    VGVoiceClient.enableAudio(audioSession)
  }

  public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    print("provider: did deactivate audio session")
    VGVoiceClient.disableAudio(audioSession)
  }

  public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    print("provider: set muted call")
    guard let callID = self.callID else {
      CustomLogger.logSlack(message: ":interrobang: Trying to mute/unmute a call with callID null")
      action.fail()
      return
    }
    if action.isMuted {
      self.client.mute(callID) { error in
        if error == nil {
          action.fulfill()
          return
        } else {
          CustomLogger.logSlack(message: ":speaker: Failed to mute\nid: \(String(describing: self.callID))\nerror: \(String(describing: error))")
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
          CustomLogger.logSlack(message: ":speaker: Failed to mute\nid: \(String(describing: self.callID))\nerror: \(String(describing: error))")
          action.fail()
          return
        }
      }
    }
  }
}
