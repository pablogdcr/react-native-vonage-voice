import CallKit
import AVFoundation
import VonageClientSDKVoice

extension VonageVoice: CXCallObserverDelegate {
  @objc public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if (call.hasEnded) {
      self.contactService.resetCallInfo()
      VGVoiceClient.disableAudio(self.audioSession)
      do {
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      } catch {
        // Fail silently
      }
    }
  }
}
