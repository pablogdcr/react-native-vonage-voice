import VonageClientSDKVoice
import CallKit
import Foundation
import PhoneNumberKit

extension NSNotification.Name {
  static let voipPushReceived = NSNotification.Name("voip-push-received")
}

typealias RefreshSessionBlock = (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void

@objc(VonageVoice)
class VonageVoice: NSObject {
  private var logger = CustomLogger()
  private let client: VGVoiceClient
  private let contactService = ContactService()
  
  private var refreshVonageTokenUrlString: String?
  private var ongoingPushKitCompletion: () -> Void = { }
  private var storedAction: (() -> Void)?
  private var callStartedAt: Date?
  private var callID: String?
  private var caller: String?
  private var isLoggedIn = false
  private var audioSession = AVAudioSession.sharedInstance()
  private var callKitProvider: CXProvider
  private var callController = CXCallController()
  private var voipNotification: Notification?
  private var isRefreshing = false
  @objc private var debugAdditionalInfo: String? {
    get {
      return UserDefaults.standard.string(forKey: "VonageVoiceDebugAdditionalInfo")
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "VonageVoiceDebugAdditionalInfo")
    }
  }

  private var outbound = false
  
  override init() {
    let configuration = CXProviderConfiguration(localizedName: "Allo")
    configuration.includesCallsInRecents = true
    configuration.supportsVideo = false
    configuration.maximumCallsPerCallGroup = 1
    configuration.maximumCallGroups = 1
    configuration.iconTemplateImageData = UIImage(named: "callKitAppIcon")?.pngData()
    configuration.supportedHandleTypes = [.phoneNumber]
      
    self.callKitProvider = CXProvider(configuration: configuration)
    self.client = VGVoiceClient(VGClientInitConfig(loggingLevel: .error, customLoggers: [self.logger]))
    super.init()

    self.callKitProvider.setDelegate(self, queue: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleVoipPushNotification(_:)),
      name: NSNotification.Name.voipPushReceived,
      object: nil
    )

    initializeClient()
    self.contactService.resetCallInfo()
  }
  
  private func initializeClient() {
    VGVoiceClient.isUsingCallKit = true
  }

  private func isCallActive() -> Bool {
    return callID != nil && callStartedAt != nil
  }

  @objc
  private func handleVoipPushNotification(_ notification: Notification) {
    voipNotification = notification
    
    handleIncomingPushNotification(notification: notification.object as! Dictionary<String, Any>) { _ in
    } reject: { _, _, error in
    }
  }
  
  @objc
  private func refreshTokens(accessToken: String, _ completion: @escaping ((any Error)?) -> Void) {
      guard let refreshVonageTokenUrlString = self.refreshVonageTokenUrlString else {
          completion(nil)
          return
      }
      self.getVonageToken(urlString: refreshVonageTokenUrlString, token: accessToken) { result in
      switch result {
        case .success(let vonageToken):
          if self.isLoggedIn {
            self.client.refreshSession(vonageToken) { error in
              if let error = error {
                self.client.createSession(vonageToken) { error, _ in
                  completion(error)
                }
              } else {
                completion(nil)
              }
            }
          } else {
            self.client.createSession(vonageToken) { error, _ in
              completion(error)
            }
          }
        case .failure(let error):
          print("Error: \(error.localizedDescription)")
          completion(error)
      }
    }
  }

  private func getVonageToken(urlString: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let url = URL(string: urlString) else {
      completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(error))
        return
      }
      
      guard let data = data else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
        return
      }
      do {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let dataDict = json["data"] as? [String: Any],
          let token = dataDict["token"] as? String {
          completion(.success(token))
        } else {
          completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Token not found in response"])))
        }
      } catch {
        completion(.failure(error))
      }
    }
    
    task.resume()
  }


  @objc(saveDebugAdditionalInfo:)
  public func saveDebugAdditionalInfo(info: String?) {
    debugAdditionalInfo = info
  }

  @objc(setRegion:)
  public func setRegion(region: String?) {
    let config: VGClientConfig;
    // When creating client save region to UserDefaults
    // This is needed for case when voip push is received in force-killed state
    // And JS part is not running so we can call setRegion from native code
    UserDefaults.standard.set(region ?? "US", forKey: "vonage.region")

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
    client.delegate = self
  }

  @objc(createSessionWithSessionID:sessionID:resolver:rejecter:)
  public func loginWithSessionID(jwt: String, sessionID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard !isCallActive() else {
      resolve(nil)
      return
    }

    client.createSession(jwt, sessionId: sessionID) { error, sessionID in
      if error == nil {
        self.isLoggedIn = true
        resolve(sessionID)
        return
      } else {
        reject("LOGIN_ERROR", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(createSession:resolver:rejecter:)
  public func login(jwt: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard !isCallActive() else {
      resolve(nil)
      return
    }
    guard !isLoggedIn else {
      reject("LOGIN_ERROR", "User is already logged in", nil)
      return
    }

    client.createSession(jwt) { error, sessionID in
      if error == nil {
        self.isLoggedIn = true
        resolve(sessionID)
        return
      } else {
        reject("LOGIN_ERROR", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(refreshSession:resolver:rejecter:)
  public func refreshSession(jwt: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard isLoggedIn else {
      reject("REFRESH_SESSION_ERROR", "User is not logged in", nil)
      return
    }

    client.refreshSession(jwt) { error in
      if error == nil {
        resolve(["success": true])
        return
      } else {
        reject("REFRESH_SESSION_ERROR", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(deleteSession:rejecter:)
  public func logout(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard isLoggedIn else {
      reject("LOGOUT_ERROR", "User is not logged in", nil)
      return
    }
    
    client.deleteSession { error in
      if error == nil {
        self.isLoggedIn = false
        resolve(["success": true])
        return
      } else {
        reject("LOGOUT_ERROR", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(getUser:resolver:rejecter:)
  public func getUser(userIdOrName: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard isLoggedIn else {
      reject("GET_USER_ERROR", "User is not logged in", nil)
      return
    }

    client.getUser(userIdOrName) { error, user in
      if error == nil {
        resolve(user)
        return
      } else {
        reject("GET_USER_ERROR", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(mute:resolver:rejecter:)
  public func mute(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    self.client.mute(callID) { error in
      if error == nil {
        resolve(["success": true])
        return
      } else {
        CustomLogger.logSlack(message: ":speaker: Failed to mute\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to mute", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(unmute:resolver:rejecter:)
  public func unmute(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    self.client.unmute(callID) { error in
      if error == nil {
        resolve(["success": true])
        return
      } else {
        CustomLogger.logSlack(message: ":speaker: Failed to unmute\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to unmute", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(enableSpeaker:rejecter:)
  public func enableSpeaker(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    do {
      try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
      try audioSession.setActive(true)
      VGVoiceClient.enableAudio(audioSession)
      resolve(["success": true])
      return
    } catch {
      CustomLogger.logSlack(message: ":loud_sound: Failed to enable speaker\nid: \(String(describing: callID))\nerror: \(String(describing: error))")
      reject("Failed to enable speaker", error.localizedDescription, error)
      return
    }
  }

  @objc(disableSpeaker:rejecter:)
  public func disableSpeaker(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let audioSession = AVAudioSession.sharedInstance()

    do {
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [])
      try audioSession.setActive(true)
      VGVoiceClient.enableAudio(audioSession)
      resolve(["success": true])
      return
    } catch {
      CustomLogger.logSlack(message: ":loud_sound: Failed to disable speaker\nid: \(String(describing: callID))\nerror: \(String(describing: error))")
      reject("Failed to disable speaker", error.localizedDescription, error)
      return
    }
  }

  @objc(getIsLoggedIn:rejecter:)
  public func getIsLoggedIn(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    resolve(isLoggedIn)
    return
  }

  @objc(getCallStatus:rejecter:)
  public func getCallStatus(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if isCallActive() {
      resolve(["callId": callID!, "outbound": outbound, "startedAt": callStartedAt!.timeIntervalSince1970, "status": "active"])
      return
    } else {
      resolve(["status": "inactive"])
      return
    }
  }

  @objc(unregisterDeviceTokens:resolver:rejecter:)
  public func unregisterDeviceTokens(deviceId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    client.unregisterDeviceTokens(byDeviceId: deviceId) { error in
      if error == nil {
        UserDefaults.standard.removeObject(forKey: Constants.pushToken)
        UserDefaults.standard.removeObject(forKey: Constants.deviceId)
        resolve(["success": true])
        return
      } else {
        reject("Failed to unregister device tokens", error?.localizedDescription, error)
        return
    }
    }
  }

  private func invalidatePushToken(_ completion: (() -> Void)? = nil) {
    if let deviceId = UserDefaults.standard.object(forKey: Constants.deviceId) as? String {
      client.unregisterDeviceTokens(byDeviceId: deviceId) { error in
        if error == nil {
          UserDefaults.standard.removeObject(forKey: Constants.pushToken)
          UserDefaults.standard.removeObject(forKey: Constants.deviceId)
        }
        completion?()
      }
    } else {
      completion?()
    }
  }

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

  @objc(registerVoipToken:isSandbox:resolver:rejecter:)
  func registerVoipToken(token: String, isSandbox: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let tokenData = data(fromHexString: token)

    guard let tokenData = tokenData else {
      reject("Invalid token", "Token is not a valid string", nil)
      return
    }

    shouldRegisterToken(with: tokenData) { shouldRegister in
      if shouldRegister {
        self.client.registerVoipToken(tokenData, isSandbox: isSandbox) { error, deviceId in
          if error == nil {
            UserDefaults.standard.setValue(tokenData, forKey: Constants.pushToken)
            UserDefaults.standard.setValue(deviceId, forKey: Constants.deviceId)
            resolve(deviceId)
            return
          } else {
            reject("Failed to register token", error?.localizedDescription, error)
            return
          }
        }
      } else {
        resolve(UserDefaults.standard.object(forKey: Constants.deviceId))
        return
      }
    }
  }

  private func data(fromHexString hexString: String) -> Data? {
    var data = Data()
    var hex = hexString
    
    // Remove any non-hex characters (optional, depending on your input)
    hex = hex.replacingOccurrences(of: " ", with: "")
    
    // Ensure even number of characters for proper hex representation
    guard hex.count % 2 == 0 else {
      return nil
    }
    
    var index = hex.startIndex
    while index < hex.endIndex {
      let byteString = hex[index..<hex.index(index, offsetBy: 2)]
      guard let byte = UInt8(byteString, radix: 16) else {
        return nil
      }
      data.append(byte)
      index = hex.index(index, offsetBy: 2)
    }
    
    return data
  }

  @objc(answerCall:resolver:rejecter:)
  public func answerCall(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    client.answer(callID) { error in
      if error == nil {
        self.callStartedAt = Date()
        self.callID = callID
        self.outbound = false
        resolve(["success": true])
        return
      } else {
        CustomLogger.logSlack(message: ":x: Failed to answer call\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to answer the call", error?.localizedDescription, error)
        return
      }
    }
  }
  
  @objc(rejectCall:resolver:rejecter:)
  public func rejectCall(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    client.reject(callID) { error in
      if error == nil {
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
        resolve(["success": true])
        return
      } else {
        CustomLogger.logSlack(message: ":x: Failed to reject call\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to reject call", error?.localizedDescription, error)
        return
      }
    }
  }
  
  @objc(hangup:resolver:rejecter:)
  public func hangup(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    client.hangup(callID) { error in
      if error == nil {
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
        resolve("Call ended")
        return
      } else {
        CustomLogger.logSlack(message: ":x: Failed to hangup call\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to hangup", error?.localizedDescription, error)
        return
      }
    }
  }

  private func isVonagePush(with userInfo: [AnyHashable : Any]) -> Bool {
    VGVoiceClient.vonagePushType(userInfo) == .unknown ? false : true
  }

  private func formatPhoneNumber(_ phoneNumber: String) -> String? {
    let phoneNumberKit = PhoneNumberKit()
    
    do {
      // Attempt to parse and format the phone number
      let parsedNumber = try phoneNumberKit.parse(phoneNumber)
      return phoneNumberKit.format(parsedNumber, toType: .international)
    } catch {
      print("Failed to format phone number: \(error)")
      return nil
    }
  }

  @objc(handleIncomingPushNotification:resolver:rejecter:)
  public func handleIncomingPushNotification(notification: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard isVonagePush(with: notification) else {
      callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
      return
    }

    processLoggedOutUser(notification: notification)
  }

  @objc(serverCall:customData:resolver:rejecter:)
  public func serverCall(to: String, customData: [String: String]? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    var callData = ["to": to]

    if let customData = customData {
      callData.merge(customData) { (_, new) in new }
    }
    self.outbound = true
    self.caller = to    
    client.serverCall(callData) { error, callID in
      if error == nil {
        resolve(["callId": callID])
        EventEmitter.shared.sendEvent(withName: Event.callRinging.rawValue, body: ["callId": callID!, "caller": to, "outbound": true])
        return
      } else {
        self.outbound = false
        self.caller = nil
        reject("Failed to server call", error?.localizedDescription, error)
        return
      }
    }
  }

  @objc(sendDTMF:resolver:rejecter:)
  public func sendDTMF(dtmf: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard let callID = callID else {
      reject("No call ID", "No call ID", nil)
      return
    }

    client.sendDTMF(callID, withDigits: dtmf, callback: { error in
      if error == nil {
        resolve(["success": true])
        return
      } else {
        reject("Failed to send DTMF", error?.localizedDescription, error)
        return
      }
    })
  }

  private func processLoggedOutUser(notification: Dictionary<String, Any>) {
    let nexmo = notification["nexmo"] as? [String: Any]
    let body = nexmo?["body"] as? [String: Any]
    let channel = body?["channel"] as? [String: Any]
    
    guard let invite = channel?["id"] as? String,
        let number = extractCallerNumber(from: notification) else {
      callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
      return
    }

    isRefreshing = true

    if let userInfo = voipNotification?.userInfo,
        let block = userInfo["refreshSessionBlock"] as? AnyObject,
        let refreshVonageTokenUrl = userInfo["refreshVonageTokenUrlString"] as? String {
      let refreshSessionBlock = unsafeBitCast(block, to: (@convention(block) (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void).self)
      refreshVonageTokenUrlString = refreshVonageTokenUrl

      var accessToken: String?
      var refreshError: Error?

      let semaphore = DispatchSemaphore(value: 0)

      refreshSessionBlock({ result in
        if let result = result as? [String: Any],
          let token = result["accessToken"] as? String {
          accessToken = token
        }
        semaphore.signal()
      }, { code, message, error in
        CustomLogger.logSlack(message: ":key: Failed to refresh session\ncode: \(String(describing: code))\nmessage: \(String(describing: message))\nerror: \(String(describing: error))")
        print("Reject called with error: \(String(describing: code)), \(String(describing: message)), \(String(describing: error))")
        refreshError = error
        semaphore.signal()
      })

      semaphore.wait()

      if let token = accessToken {
        self.reportIncomingCall(invite: invite, number: number, token: token)
        self.setRegion(region: UserDefaults.standard.string(forKey: "vonage.region"))
        self.refreshTokens(accessToken: token) { error in
          if let error = error {
            print(error.localizedDescription)
          } else {
            self.isLoggedIn = true
            self.client.processCallInvitePushData(notification)
          }
          self.isRefreshing = false
        }
      } else {
        CustomLogger.logSlack(message: ":key: Failed to refresh session")
        self.callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
        self.isRefreshing = false
      }
    }
  }

  private func extractCallerNumber(from notification: Dictionary<String, Any>) -> String? {
    let nexmo = notification["nexmo"] as? [String: Any]
    let body = nexmo?["body"] as? [String: Any]
    let channel = body?["channel"] as? [String: Any]
    let from = channel?["from"] as? [String: Any]
    return from?["number"] as? String
  }

  private func reportIncomingCall(invite: String, number: String, token: String) {
    let callUpdate = CXCallUpdate()
    callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: number)

    self.contactService.prepareCallInfo(number: number, token: token) { success, error in
      if success {
      } else if let error = error {
        print("Error updating contact image: \(error)")
      }
      self.callKitProvider.reportNewIncomingCall(with: UUID(uuidString: invite) ?? UUID(), update: callUpdate) { error in
        if let error = error {
          print("Error reporting call: \(error)")
          self.callKitProvider.reportCall(with: UUID(uuidString: invite) ?? UUID(), endedAt: Date(), reason: .unanswered)
        } else {
          self.callID = invite
          self.caller = number
          self.outbound = false
        }
      }
    }
  }

  private func endCallTransaction(action: CXEndCallAction) {
    callController.request(CXTransaction(action: action)) { error in
      if error == nil {
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
        action.fulfill()
      } else {
        action.fail()
      }
    }
  }

  private func waitForRefreshCompletion(completion: @escaping () -> Void) {
    if !isRefreshing {
      completion()
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.waitForRefreshCompletion(completion: completion)
      }
    }
  }
}

// MARK:-  Constants

struct Constants {
  static let deviceId = "VGDeviceID"
  static let pushToken = "VGPushToken"
}

@objc extension VonageVoice: VGVoiceClientDelegate {
  /*
      After the Client SDK is done processing the incoming push,
      You will receive the call here
  */
  public func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, with type: VGVoiceChannelType) {
    EventEmitter.shared.sendEvent(withName: Event.receivedInvite.rawValue, body: ["callId": callId, "caller": caller])
  }
  
  public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
    EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "reason": reason.rawValue])
    self.callStartedAt = nil
    self.callID = nil
    self.outbound = false
    callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
  }
  
  public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
    EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
    self.callStartedAt = nil
    self.callID = nil
    self.outbound = false
    callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
  }

  public func voiceClient(_ client: VGVoiceClient, didReceiveLegStatusUpdateForCall callId: String, withLegId legId: String, andStatus status: VGLegStatus) {
    switch (status) {
      case .completed:
        EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "reason": "completed"])
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false
        callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
        break

      case .ringing:
        EventEmitter.shared.sendEvent(withName: Event.callRinging.rawValue, body: ["callId": callId, "caller": caller!, "outbound": outbound])
        self.callStartedAt = Date()
        self.callID = callId
        callKitProvider.reportOutgoingCall(with: UUID(uuidString: callId)!, startedConnectingAt: Date())
        break

      case .answered:
        let audioSession = AVAudioSession.sharedInstance()

        do {
          try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [])
          try audioSession.setActive(true)
          VGVoiceClient.enableAudio(audioSession)
        } catch {
          CustomLogger.logSlack(message: ":loud_sound: Failed to disable speaker\nid: \(String(describing: callID))\nerror: \(String(describing: error))")
        }
        EventEmitter.shared.sendEvent(withName: Event.callAnswered.rawValue, body: ["callId": callId])
        break

      default:
        print("Unknown status: \(status)")
    }
  }

  public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectingForCall callId: String) {
    EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnecting"])
  }

  public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectionForCall callId: String) {
    EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnected"])
  }

  public func voiceClient(_ client: VGVoiceClient, didReceiveMediaDisconnectForCall callId: String, reason: VGCallDisconnectReason) {
    EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "disconnected", "reason": reason.rawValue])
  }

  public func voiceClient(_ client: VGVoiceClient, didReceiveMediaErrorForCall callId: String, error: VGError) {
    CustomLogger.logSlack(message: ":warning: Media error:\ncall id:\(callId)\nerror: \(String(describing: error))")
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
    if reason != .tokenExpired {
      CustomLogger.logSlack(message: ":warning: Session error:\nreason: \(String(describing: reason))\nreasonString: \(String(describing: reasonString))")
    }
    EventEmitter.shared.sendEvent(withName: Event.receivedSessionError.rawValue, body: ["reason": reasonString])
  }
}

extension VonageVoice: CXProviderDelegate {
  public func providerDidReset(_ provider: CXProvider) {
    self.contactService.resetCallInfo()
    callStartedAt = nil
    callID = nil
  }


  public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])
    self.contactService.changeTemporaryIdentifierImage()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
      self.contactService.resetCallInfo()
      waitForRefreshCompletion { [self] in
        guard let callID else { return }

        client.answer(callID) { error in
          if error == nil {
            self.callStartedAt = Date()
            self.callID = callID
            EventEmitter.shared.sendEvent(withName: Event.callAnswered.rawValue, body: ["callId": self.callID, "caller": self.caller])
            action.fulfill()
          } else {
            action.fail()
          }
        }
      }
    }
  }
  
  public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    self.contactService.resetCallInfo()
    waitForRefreshCompletion { [self] in
      guard let callID else {
        endCallTransaction(action: action)
        return
      }

      if isCallActive() {
        client.hangup(callID) { error in
          if error == nil {
            self.callStartedAt = nil
            self.callID = nil
            self.endCallTransaction(action: action)
          } else {
            action.fail()
          }
          EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": self.callID, "caller": self.caller])
        }
      } else {
        client.reject(callID) { error in
          if error == nil {
            self.callStartedAt = nil
            self.callID = nil
            self.endCallTransaction(action: action)
          } else {
            action.fail()
          }
          EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": self.callID, "caller": self.caller])
        }
      }
    }
  }

  public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    VGVoiceClient.enableAudio(audioSession)
  }

  public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    VGVoiceClient.disableAudio(audioSession)
  }

  public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    guard let callID = self.callID else {
      CustomLogger.logSlack(message: ":interrobang: Trying to mute/unmute a call with callID null")
      action.fail()
      return
    }
    if action.isMuted {
      self.client.mute(callID) { error in
        if error == nil {
          action.fulfill()
          return
        } else {
          CustomLogger.logSlack(message: ":speaker: Failed to mute\nid: \(String(describing: self.callID))\nerror: \(String(describing: error))")
          action.fail()
          return
        }
      }
    } else {
      self.client.unmute(callID) { error in
        if error == nil {
          action.fulfill()
          return
        } else {
          CustomLogger.logSlack(message: ":speaker: Failed to mute\nid: \(String(describing: self.callID))\nerror: \(String(describing: error))")
          action.fail()
          return
        }
      }
    }
  }
}
