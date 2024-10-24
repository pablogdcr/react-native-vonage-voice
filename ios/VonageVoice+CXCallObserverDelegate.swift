import CallKit
import AVFoundation
import VonageClientSDKVoice

extension VonageVoice: CXCallObserverDelegate {
  @objc public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if (call.hasEnded) {
      self.contactService.resetCallInfo()
      self.isCallHandled = false
    }
    if (call.hasConnected) {
      do {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowBluetooth, .defaultToSpeaker])
        try audioSession.overrideOutputAudioPort(.none)
        try audioSession.setActive(true)

        VGVoiceClient.enableAudio(audioSession)
      } catch {
        // Fail silently
      }
    }
  }
}
