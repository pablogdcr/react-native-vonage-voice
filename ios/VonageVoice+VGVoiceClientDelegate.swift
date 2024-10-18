import VonageClientSDKVoice

extension VonageVoice: VGVoiceClientDelegate {
  @objc public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, with type: VGVoiceChannelType) {
    print("Received invite for call: \(callId)")
    self.isCallHandled = false
    self.callID = callId
    self.caller = caller
    self.outbound = false
    EventEmitter.shared.sendEvent(withName: Event.receivedInvite.rawValue, body: ["callId": callId, "caller": caller, "outbound": outbound])
  }

    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
    print("Received hangup for call: \(callId)")
    EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "reason": reason.rawValue])
    self.callStartedAt = nil
    self.callID = nil
    self.outbound = false
    self.contactService.resetCallInfo()
    callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
  }
  
    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
    print("Received cancel for call: \(callId)")
    EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
    self.callStartedAt = nil
    self.callID = nil
    self.outbound = false
    callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
  }

    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveLegStatusUpdateForCall callId: String, withLegId legId: String, andStatus status: VGLegStatus) {
    print("Received leg status update for call: \(callId)")
    switch (status) {
      case .completed:
        EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "reason": "completed"])
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
        callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
        break

      case .ringing:
        EventEmitter.shared.sendEvent(withName: Event.callRinging.rawValue, body: ["callId": callId, "caller": caller!, "outbound": outbound])
        self.callID = callId
        break

      case .answered:
        if self.outbound == true {
          self.callKitProvider.reportOutgoingCall(with: UUID(uuidString: callId)!, connectedAt: Date())
        }
        let audioSession = AVAudioSession.sharedInstance()

        do {
          try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
          try audioSession.setActive(true, options: [])

          VGVoiceClient.enableAudio(audioSession)
        } catch {
          // Fail silently
        }
        EventEmitter.shared.sendEvent(withName: Event.callAnswered.rawValue, body: ["callId": callId, "caller": caller!, "outbound": outbound])
        break

      default:
        print("Unknown status: \(status)")
    }
  }

    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectingForCall callId: String) {
    print("Received media reconnecting for call: \(callId)")
    EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnecting"])
  }

    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectionForCall callId: String) {
    print("Received media reconnection for call: \(callId)")
    EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnected"])
  }

    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaDisconnectForCall callId: String, reason: VGCallDisconnectReason) {
    print("Received media disconnect for call: \(callId)")
    EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "disconnected", "reason": reason.rawValue])
  }

    @objc public func voiceClient(_ client: VGVoiceClient, didReceiveMediaErrorForCall callId: String, error: VGError) {
    print("Received media error for call: \(callId)")
    CustomLogger.logSlack(message: ":warning: Media error:\ncall id:\(callId)\nerror: \(String(describing: error))")
  }

    @objc  public func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
      print("Received session error for call: \(self.callID)")
    let reasonString: String!

    switch reason {
      case .tokenExpired:
        reasonString = "Expired Token"
      case .pingTimeout, .transportClosed:
        reasonString = "Network Error"
      default:
        reasonString = "Unknown"
    }
    if reason != .tokenExpired {
      CustomLogger.logSlack(message: ":warning: Session error:\nreason: \(String(describing: reason))\nreasonString: \(String(describing: reasonString))")
    }
    EventEmitter.shared.sendEvent(withName: Event.receivedSessionError.rawValue, body: ["reason": reasonString])
  }
}
