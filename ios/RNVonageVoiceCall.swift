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

  @objc(registerVoipToken:resolver:rejecter:)
  func registerVoipToken(_ token: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    var isSandbox = false
    #if DEBUG
      isSandbox = true
    #endif

    client.registerVoipToken(token.data(using: .utf8)!, isSandbox: isSandbox) { error, deviceId in
      if let error = error {
        print("[RNVonageVoiceCall] Error registering voip token: \(error)")
        reject("VOIP_TOKEN_ERROR", error.localizedDescription, error)
      } else {
        resolve(deviceId)
      }
    }
  }
}

extension RNVonageVoiceCall: VGVoiceClientDelegate {
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: String, from caller: String, with type: VGVoiceChannelType) {
      NSLog("Incoming call from \(caller)")
        // DispatchQueue.main.async { [weak self] in
        //     self?.displayIncomingCallAlert(callID: callId, caller: caller)
        // }
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
      NSLog("Call cancelled")
        // DispatchQueue.main.async { [weak self] in
        //     self?.dismiss(animated: true)
        // }
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: String, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
      NSLog("Call ended")
        // self.callID = nil
    }
    
    public func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
      NSLog("Session error")
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