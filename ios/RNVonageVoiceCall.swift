// Native module in swift: https://medium.com/@jtaverasv/native-modules-swift-based-the-basics-react-native-4ac2d0a712ca

import Foundation
import PushKit
import VonageClientSDKVoice

@objc(RNVonageVoiceCall)
public class RNVonageVoiceCall: NSObject {
  let client = VGVoiceClient()

  override init() {
      super.init()
      client.delegate = self
  }

  @objc(createSession:resolver:rejecter:)
  func createSession(_ jwt: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    client.createSession(jwt) { error, sessionId in
      if let error = error {
        print("[RNVonageVoiceCall] Error creating session: \(error)")
        reject("SESSION_ERROR", error.localizedDescription, error)
      } else {
        resolve(sessionId)
      }
    }
  }
}

extension RNVonageVoiceCall: VGVoiceClientDelegate {
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: String, from caller: String, with type: VGVoiceChannelType) {
        // DispatchQueue.main.async { [weak self] in
        //     self?.displayIncomingCallAlert(callID: callId, caller: caller)
        // }
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
        // DispatchQueue.main.async { [weak self] in
        //     self?.dismiss(animated: true)
        // }
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: String, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        // self.callID = nil
    }
    
    public func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
        // let reasonString: String!
        
        // switch reason {
        // case .tokenExpired:
        //     reasonString = "Expired Token"
        // case .pingTimeout, .transportClosed:
        //     reasonString = "Network Error"
        // default:
        //     reasonString = "Unknown"
        // }
    }
}

extension RNVonageVoiceCall: PKPushRegistryDelegate {
  public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    NSLog("voip token: \(credentials.token)")
  }
}