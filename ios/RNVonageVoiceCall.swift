import PushKit
import Foundation
import VonageClientSDKVoice

@objc(RNVonageVoiceCall)
class RNVonageVoiceCall {
  let client = VGVoiceClient()
  private var _isVoipRegistered = false
  private var _lastVoipToken = ""

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

  @objc(registerForVoIPPushes)
  func registerForVoIPPushes() {
    if _isVoipRegistered {
#if DEBUG
        RCTLog(@"[RNVonageVoiceCallNotificationManager] voipRegistration is already registered. return _lastVoipToken = %@", _lastVoipToken);
#endif
      return
    }
#if DEBUG
      RCTLog(@"[RNVonageVoiceCallNotificationManager] voipRegistration enter");
#endif
    _isVoipRegistered = true
    DispatchQueue.main.async { [weak self] in
      let voipRegistry = PKPushRegistry(queue: nil)

      voipRegistry.delegate = self
      voipRegistry.desiredPushTypes = [PKPushType.voIP]
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

  @objc(didUpdatePushCredentials:forType:)
  func didUpdatePushCredentials(_ credentials: PKPushCredentials, forType type: String) {
#if DEBUG
    NSLog("[RNVonageVoiceCall] didUpdatePushCredentials credentials.token = %@, type = %@", credentials.token, type)
#endif
    let voipTokenLength = credentials.token.count
    if voipTokenLength == 0 {
      return
    }

    var hexString = ""
    let bytes = [UInt8](credentials.token)
    for byte in bytes {
      hexString += String(format: "%02x", byte)
    }

    _lastVoipToken = hexString
  }

  @objc(didReceiveIncomingPushWithPayload:forType:)
  func didReceiveIncomingPush(with payload: PKPushPayload, forType type: String) {
#if DEBUG
    NSLog("[RNVonageVoiceCall] didReceiveIncomingPushWithPayload payload.dictionaryPayload = %@, type = %@", payload.dictionaryPayload, type)
#endif

    sendEvent(withName: "RNVonageVoiceCallRemoteNotificationReceivedEvent", body: payload.dictionaryPayload)
  }
}

extension RNVonageVoiceCall: RCTEventEmitter {
  private var _completionHandlers = [String: RCTPromiseResolveBlock]()
  private var hasListeners = false
  private var _delayedEvents = [Any]()

  override static func requiresMainQueueSetup() -> Bool {
      return true
  }

  override deinit {
    NotificationCenter.default.removeObserver(self)
    for (_, completion) in _completionHandlers {
      completion()
    }
    _completionHandlers.removeAll()
  }

  override func supportedEvents() -> [String]! {
    return [
      "RNVonageVoiceCallRemoteNotificationsRegisteredEvent",
      "RNVonageVoiceCallRemoteNotificationReceivedEvent",
      "RNVonageVoiceCallDidLoadWithEvents",
    ]
  }

  
  override func startObserving() {
    self.hasListeners = true
    if !_delayedEvents.isEmpty {
      sendEvent(withName: "RNVonageVoiceCallDidLoadWithEvents", body: _delayedEvents)
    }
  }

  override func stopObserving() {
    self.hasListeners = false
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
