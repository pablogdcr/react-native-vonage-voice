import CallKit
import AVFoundation
import VonageClientSDKVoice

extension VonageVoice: CXCallObserverDelegate {
  @objc public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if (call.hasEnded) {
      self.logger.logSlack(message: "Call ended", admin: true)
      self.contactService.resetCallInfo()
      print("CALL ENDED!")
      if let url = Bundle.main.url(forResource: "call_end", withExtension: "mp3") {
        do {
          let audioPlayer = try AVAudioPlayer(contentsOf: url)
          audioPlayer.play()
        } catch {
          self.logger.logSlack(message: "Failed to play call end sound: \(error.localizedDescription)")
        }
      } else {
        print("NO CALL_END")
      }
    }
  }
}
