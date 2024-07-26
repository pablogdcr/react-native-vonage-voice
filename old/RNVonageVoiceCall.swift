import Foundation
import VonageClientSDKVoice

@objc(RNVonageVoiceCall)
class RNVonageVoiceCall: NSObject {
  let client: VGVoiceClient
  var callId: String?

  override init() {
      let initConfig = VGClientInitConfig(loggingLevel: .verbose)

      client = VGVoiceClient(initConfig)
      super.init()

      client.delegate = self
  }

  @objc(createSession:region:resolver:rejecter:)
  func createSession(_ jwt: String, region: String?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
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
    client.createSession(jwt) { error, sessionId in
      if let error = error {
        print("[RNVonageVoiceCall] Error creating session: \(error)")
        reject("SESSION_ERROR", error.localizedDescription, error)
      } else {
        resolve(sessionId)
      }
    }
  }

  @objc(answer:resolver:rejecter:)
  func answer(_ callId: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    client.answer(callId) { error in
      if let error {
        print("[RNVonageVoiceCall] Error answering call: \(error)")
        reject("ANSWER_ERROR", error.localizedDescription, error)
      } else {
        self.callId = callId
        resolve(nil)
      }
    }
  }

  @objc(reject:resolver:rejecter:)
  func reject(_ callId: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    client.reject(callId) { error in
      if let error {
        print("[RNVonageVoiceCall] Error rejecting call: \(error)")
        reject("REJECT_ERROR", error.localizedDescription, error)
      } else {
        resolve(nil)
      }
    }
  }

  @objc(call:resolver:rejecter:)
  func call(_ number: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    client.serverCall(["to": number]) { error, callId in
      if let error {
        print("[RNVonageVoiceCall] Error calling number: \(error)")
        reject("CALL_ERROR", error.localizedDescription, error)
      } else {
        self.callId = callId
        resolve(callId)
      }
    }
  }

  @objc(endCall:rejecter:)
  func endCall(resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if let callId = self.callId {
      client.hangup(callId) { error in
        if let error {
          print("[RNVonageVoiceCall] Error hanging up call: \(error)")
          reject("HANGUP_ERROR", error.localizedDescription, error)
        }
        resolve(nil)
      }
    } else {
      reject("NO_CALL", "No active call", nil)
    }
  }
}

//   @objc(registerForVoIPPushes)
//   func registerForVoIPPushes() {
//     if _isVoipRegistered {
// #if DEBUG
//         NSLog("[RNVonageVoiceCallNotificationManager] voipRegistration is already registered. return _lastVoipToken = %@", _lastVoipToken);
// #endif
//       return
//     }
// #if DEBUG
//       NSLog("[RNVonageVoiceCallNotificationManager] voipRegistration enter");
// #endif
//     _isVoipRegistered = true
//     DispatchQueue.main.async { [weak self] in
//       let voipRegistry: PKPushRegistry = PKPushRegistry(queue: nil)

//       // voipRegistry.delegate = self
//       voipRegistry.desiredPushTypes = [PKPushType.voIP]
//     }
//   }

  // @objc(registerVoipToken:resolver:rejecter:)
  // func registerVoipToken(_ token: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
  //   var isSandbox = false
  //   #if DEBUG
  //     isSandbox = true
  //   #endif

  //   client.registerVoipToken(token.data(using: .utf8)!, isSandbox: isSandbox) { error, deviceId in
  //     if let error = error {
  //       print("[RNVonageVoiceCall] Error registering voip token: \(error)")
  //       reject("VOIP_TOKEN_ERROR", error.localizedDescription, error)
  //     } else {
  //       resolve(deviceId)
  //     }
  //   }
  // }

//   @objc(didUpdatePushCredentials:forType:)
//   func didUpdatePushCredentials(_ credentials: PKPushCredentials, forType type: String) {
// // #if DEBUG
// //     NSLog("[RNVonageVoiceCall] didUpdatePushCredentials credentials.token = %@, type = %@", credentials.token, type)
// // #endif
//     let voipTokenLength = credentials.token.count
//     if voipTokenLength == 0 {
//       return
//     }

//     var hexString = ""
//     let bytes = [UInt8](credentials.token)
//     for byte in bytes {
//       hexString += String(format: "%02x", byte)
//     }

//     _lastVoipToken = hexString
//   }

//   @objc(didReceiveIncomingPushWithPayload:forType:)
//   func didReceiveIncomingPush(with payload: PKPushPayload, forType type: String) {
// #if DEBUG
//     NSLog("[RNVonageVoiceCall] didReceiveIncomingPushWithPayload payload.dictionaryPayload = %@, type = %@", payload.dictionaryPayload, type)
// #endif

//     // sendEvent(withName: "RNVonageVoiceCallRemoteNotificationReceivedEvent", body: payload.dictionaryPayload)
//   }


extension RNVonageVoiceCall: VGVoiceClientDelegate {
  func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: String, from caller: String, with type: VGVoiceChannelType) {
    NSLog("Incoming call from \(caller)")
      // DispatchQueue.main.async { [weak self] in
      //     self?.displayIncomingCallAlert(callId: callId, caller: caller)
      // }
  }

  func voiceClient(_ client: VGVoiceClient, didReceiveCallTransferForCall callId: String, with conversationId: String) {
    NSLog("Call transfer")
      // DispatchQueue.main.async { [weak self] in
      //     self?.displayIncomingCallAlert(callId: callId, caller: caller)
      // }
  }
  
  func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
    NSLog("Call cancelled")
      // DispatchQueue.main.async { [weak self] in
      //     self?.dismiss(animated: true)
      // }
  }
  
  func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: String, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
    NSLog("Call ended")
      self.callId = nil
  }
  
  func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
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

// class RNVonageVoiceCallManager: RCTEventEmitter {
//   private var _completionHandlers = [String: RCTPromiseResolveBlock]()
//   private var hasListeners = false
//   private var _delayedEvents = [Any]()

//   override static func requiresMainQueueSetup() -> Bool {
//       return true
//   }

//   override deinit {
//     NotificationCenter.default.removeObserver(self)
//     for (_, completion) in _completionHandlers {
//       completion()
//     }
//     _completionHandlers.removeAll()
//   }

//   override func supportedEvents() -> [String]! {
//     return [
//       "RNVonageVoiceCallRemoteNotificationsRegisteredEvent",
//       "RNVonageVoiceCallRemoteNotificationReceivedEvent",
//       "RNVonageVoiceCallDidLoadWithEvents",
//     ]
//   }

  
//   override func startObserving() {
//     self.hasListeners = true
//     if !_delayedEvents.isEmpty {
//       sendEvent(withName: "RNVonageVoiceCallDidLoadWithEvents", body: _delayedEvents)
//     }
//   }

//   override func stopObserving() {
//     self.hasListeners = false
//   }
// }