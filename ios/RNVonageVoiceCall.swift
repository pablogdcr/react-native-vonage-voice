import PushKit
import Foundation
import React
import VonageClientSDKVoice

// @objc protocol VGVoiceClientDelegate {
//   func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, withChannelType type: VGVoiceChannelType)
//   func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, andReason: VGHangupReason)
//   func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, withReason reason: VGVoiceInviteCancelReason)
//   func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason)
// }

// typealias VGCallId = String

@objc
public final class RNVonageVoiceCall: NSObject {
  public var pushToken: Data?

  private let client = VGVoiceClient()
  private let providerDelegate = ProviderDelegate()

  private var ongoingPushLogin = false
  private var ongoingPushKitCompletion: () -> Void = { }
  private var storedAction: (() -> Void)?
  private var isActiveCall = false

  public static let shared = RNVonageVoiceCall()

  override init() {
    super.init()
    initializeClient()
  }

  private func initializeClient() {
    // client.delegate = self
  }

  @objc(setRegion:)
  public func setRegion(region: String?) {
    let config: VGClientConfig;

    if region == nil {
      config = VGClientConfig(region: .US)
    } else {
      switch region {
        case "EU":
          config = VGClientConfig(region: .EU)
        case "AP":
          config = VGClientConfig(region: .AP)
        default:
          config = VGClientConfig(region: .US)
      }
    }
    client.setConfig(config)
  }

  @objc(login:isPushLogin:completion:)
  public func login(jwt: String, isPushLogin: Bool = false, completion: @escaping (Error?) -> Void) {
    print("VPush: Login - isPush:", isPushLogin)
    guard !isActiveCall else { return }
    
    ongoingPushLogin = isPushLogin
    
    self.client.createSession(jwt) { error, sessionID in
      if error == nil {
        if isPushLogin {
          self.handlePushLogin()
        } else {
          self.handleLogin()
        }
        completion(nil)
      } else {
        completion(error)
      }
    }
  }

  private func handlePushLogin() {
    ongoingPushLogin = false

    if let storedAction = storedAction {
      storedAction()
    }
  }

  private func handleLogin() {
    if let token = pushToken {
      registerPushIfNeeded(with: token)
    }
  }

  @objc(isVonagePush:)
  public func isVonagePush(with userInfo: [AnyHashable : Any]) -> Bool {
    VGVoiceClient.vonagePushType(userInfo) == .unknown ? false : true
  }

  @objc(invalidatePushToken:)
  public func invalidatePushToken(_ completion: (() -> Void)? = nil) {
    if let deviceId = UserDefaults.standard.object(forKey: Constants.deviceId) as? String {
      print("VPush: Invalidate token")
      client.unregisterDeviceTokens(byDeviceId: deviceId) { error in
        if error == nil {
          self.pushToken = nil
          UserDefaults.standard.removeObject(forKey: Constants.pushToken)
          UserDefaults.standard.removeObject(forKey: Constants.deviceId)
          completion?()
        }
      }
    } else {
      completion?()
    }
  }
    
  /*
    This function processes the payload from the voip push notification.
    If successful it will return a call invite ID and `didReceiveInviteForCall`
    would be called.
    */
  @objc(processPushPayload:pushKitCompletion:)
  public func processPushPayload(with payload: [AnyHashable : Any], pushKitCompletion: @escaping () -> Void) -> String? {
    self.ongoingPushKitCompletion = pushKitCompletion
    return client.processCallInvitePushData(payload)
  }
    
  @objc(answer:completion:)
  public func answer(_ callID: String, completion: @escaping (Error?) -> Void) {
    let answerAction = {
      print("VPush: Answer", callID)
      self.isActiveCall = true
      self.client.answer(callID, callback: completion)
    }
      
    if ongoingPushLogin {
      print("VPush: Storing answer")
      storedAction = answerAction
    } else {
      answerAction()
    }
  }

  @objc(reject:completion:) 
  public func reject(_ callID: String, completion: @escaping (Error?) -> Void) {
    let rejectAction = {
      print("VPush: Reject", callID)
      self.isActiveCall = false
      self.client.reject(callID, callback: completion)
    }
    
    if ongoingPushLogin {
      print("VPush: Storing Reject")
      storedAction = rejectAction
    } else {
      rejectAction()
    }
  }

  @objc(voipRegistration)
  public func voipRegistration() {
    DispatchQueue.main.async { [self] in
      let voipRegistry: PKPushRegistry = PKPushRegistry(queue: nil)
      voipRegistry.delegate = RCTSharedApplication()?.delegate as? PKPushRegistryDelegate
      voipRegistry.desiredPushTypes = [PKPushType.voIP]
    }
  }

  /*
  This function enabled push notifications with the client
  if it has not already been done for the current token.
  */
  private func registerPushIfNeeded(with token: Data) {
    shouldRegisterToken(with: token) { shouldRegister in
      if shouldRegister {
        self.client.registerVoipToken(token, isSandbox: true) { error, deviceId in
          if error == nil {
            print("VPush: push token registered")
            UserDefaults.standard.setValue(token, forKey: Constants.pushToken)
            UserDefaults.standard.setValue(deviceId, forKey: Constants.deviceId)
          } else {
            print("VPush: registration error: \(String(describing: error))")
            return
          }
        }
      }
    }
  }
    
  /*
    Push tokens only need to be registered once.
    So the token is stored locally and is invalidated if the incoming
    token is new.
    */
  private func shouldRegisterToken(with token: Data, completion: @escaping (Bool) -> Void) {
    let storedToken = UserDefaults.standard.object(forKey: Constants.pushToken) as? Data
    
    if let storedToken = storedToken, storedToken == token {
      completion(false)
      return
    }
    
    invalidatePushToken {
      completion(true)
    }
  }
    
}

@objc extension RNVonageVoiceCall: VGVoiceClientDelegate {
  /*
    After the Client SDK is done processing the incoming push,
    You will receive the call here
  */
  public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, with type: VGVoiceChannelType) {
    print("VPush: Received invite", callId)
    providerDelegate.reportCall(callId, caller: caller, completion: ongoingPushKitCompletion)
  }
  
  public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
    print("VPush: Received hangup")
    isActiveCall = false
    providerDelegate.didReceiveHangup(callId)
  }
  
  public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
    print("VPush: Received invite cancel")
    providerDelegate.reportFailedCall(callId)
  }
  
  public func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
    let reasonString: String!
    
    switch reason {
      case .tokenExpired:
        reasonString = "Expired Token"
      case .pingTimeout, .transportClosed:
        reasonString = "Network Error"
      default:
        reasonString = "Unknown"
    }
    print("VPush: Session error", reasonString)
  }
}

// MARK:-  Constants

struct Constants {
  static let deviceId = "VGDeviceID"
  static let pushToken = "VGPushToken"
}