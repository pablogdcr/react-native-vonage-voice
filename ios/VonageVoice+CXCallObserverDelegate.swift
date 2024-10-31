import CallKit
import AVFoundation
import VonageClientSDKVoice

extension VonageVoice: CXCallObserverDelegate {
  @objc public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if (call.hasEnded) {
      self.contactService.resetCallInfo()
      self.deactivateAndResetAudioSession()
    }
  }
}
