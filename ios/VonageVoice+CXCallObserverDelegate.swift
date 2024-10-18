import CallKit
import AVFoundation
import VonageClientSDKVoice

extension VonageVoice: CXCallObserverDelegate {
  @objc public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if (call.hasEnded) {
      self.contactService.resetCallInfo()
    }
    if (call.hasConnected) {
      let audioSession = AVAudioSession.sharedInstance()

      do {
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try audioSession.setActive(true, options: [])

        VGVoiceClient.enableAudio(audioSession)
      } catch {
        // Fail silently
      }
    }
  }
}
