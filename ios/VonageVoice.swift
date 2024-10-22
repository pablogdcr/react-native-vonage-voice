import VonageClientSDKVoice
import CallKit
import AVFoundation

extension NSNotification.Name {
  static let voipPushReceived = NSNotification.Name("voip-push-received")
}

typealias RefreshSessionBlock = (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void

@objc(VonageVoice)
public class VonageVoice: NSObject {
  @objc public static let shared = VonageVoice()

  private var logger = CustomLogger()
  let client: VGVoiceClient
  let contactService = ContactService()
  let audioSession = AVAudioSession.sharedInstance()
  
  private var refreshVonageTokenUrlString: String?
  private var ongoingPushKitCompletion: () -> Void = { }
  private var storedAction: (() -> Void)?
  private var isLoggedIn = false
  var callKitProvider: CXProvider
  private var callKitObserver: CXCallObserver!
  var callController = CXCallController()
  private var voipNotification: Notification?
  private var isRefreshing = false
  private var isObserversAdded = false
  private var refreshSessionBlock: RefreshSessionBlock?
  var callStartedAt: Date?
  var callID: String?
  var caller: String?
  var outbound = false
  var isCallHandled = false

  @objc private var debugAdditionalInfo: String? {
    get {
      return UserDefaults.standard.string(forKey: Constants.debugInfoKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Constants.debugInfoKey)
    }
  }

  private override init() {
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

    self.callKitObserver = CXCallObserver()
    self.callKitObserver.setDelegate(self, queue: nil)
    self.callKitProvider.setDelegate(self, queue: nil)

    addObservers()
    initializeClient()
    self.contactService.resetCallInfo()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private func addObservers() {
    if !isObserversAdded {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleVoipPushNotification),
        name: NSNotification.Name.voipPushReceived,
        object: nil
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAudioSessionInterruption),
        name: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance())
    }
  }

  @objc private func handleAudioSessionInterruption(notification: Notification) {
    guard let info = notification.userInfo,
        let interruptionType = info[AVAudioSessionInterruptionTypeKey] as? UInt else {
      return
    }

    if interruptionType == AVAudioSession.InterruptionType.ended.rawValue {
      do {
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
      } catch {
        CustomLogger.logSlack(message: ":x: Failed to reactivate audio session after interruption: \(error.localizedDescription)\ninfo:\(debugAdditionalInfo)")
      }
    }
  }

  private func initializeClient() {
    VGVoiceClient.isUsingCallKit = true
  }

  func isCallActive() -> Bool {
    return callID != nil && callStartedAt != nil
  }

  @objc private func handleVoipPushNotification(_ notification: Notification) {
    voipNotification = notification
    handleIncomingPushNotification(notification: notification.object as! Dictionary<String, Any>) { _ in
    } reject: { _, _, error in
    }
  }
  
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
              if error != nil {
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

  @objc public func saveDebugAdditionalInfo(info: String?) {
    debugAdditionalInfo = info
  }

  @objc public func setRegion(region: String?) {
    let config: VGClientConfig;
    // When creating client save region to UserDefaults
    // This is needed for case when voip push is received in force-killed state
    // And JS part is not running so we can call setRegion from native code
    UserDefaults.standard.set(region ?? "US", forKey: Constants.regionKey)

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

  @objc public func loginWithSessionID(jwt: String, sessionID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func login(jwt: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func refreshSession(jwt: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func logout(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func getUser(userIdOrName: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func mute(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func unmute(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func enableSpeaker(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    do {
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothA2DP, .allowBluetooth, .defaultToSpeaker])
      try audioSession.overrideOutputAudioPort(.speaker)
      try audioSession.setActive(true)

      resolve(["success": true])
      return
    } catch {
      CustomLogger.logSlack(message: ":loud_sound: Failed to enable speaker\nid: \(String(describing: callID))\nerror: \(String(describing: error))")
      reject("Failed to enable speaker", error.localizedDescription, error)
      return
    }
  }

  @objc public func disableSpeaker(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    do {
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowBluetooth, .defaultToSpeaker])
      try audioSession.overrideOutputAudioPort(.none)
      try audioSession.setActive(true)
    
      resolve(["success": true])
      return
    } catch {
      CustomLogger.logSlack(message: ":loud_sound: Failed to disable speaker\nid: \(String(describing: callID))\nerror: \(String(describing: error))")
      reject("Failed to disable speaker", error.localizedDescription, error)
      return
    }
  }

  @objc public func getIsLoggedIn(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    resolve(isLoggedIn)
    return
  }

  @objc public func getCallStatus(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if isCallActive() {
      resolve(["callId": callID!, "outbound": outbound, "startedAt": callStartedAt!.timeIntervalSince1970, "status": "active"])
      return
    } else {
      resolve(["status": "inactive"])
      return
    }
  }

  @objc public func unregisterDeviceTokens(deviceId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func registerVoipToken(token: String, isSandbox: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  @objc public func answerCall(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if isCallHandled {
      reject("Call already handled", "Call already handled", nil)
      return
    }
    EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])

    client.answer(callID) { error in
      if error == nil {
        self.isCallHandled = true
        self.callStartedAt = Date()
        self.callID = callID
        self.outbound = false

        let transaction = CXTransaction(action: CXAnswerCallAction(call: UUID(uuidString: callID)!))
        self.callController.request(transaction, completion: { error in
          if let error = error {
            print("Error answering call: \(error)")
          }
          self.isCallHandled = false
        })
        resolve(["success": true])
        return
      } else {
        CustomLogger.logSlack(message: ":x: Failed to answer call\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to answer the call", error?.localizedDescription, error)
        return
      }
    }
  }
  
  @objc public func rejectCall(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if isCallHandled {
      reject("Call already handled", "Call already handled", nil)
      return
    }

    client.reject(callID) { error in
      if error == nil {
        self.isCallHandled = true
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false

        do {
          try VGVoiceClient.disableAudio(self.audioSession)
        } catch {
          // Fail silently
        }
        let transaction = CXTransaction(action: CXEndCallAction(call: UUID(uuidString: callID)!))
        self.callController.request(transaction, completion: { error in
          if let error = error {
            print("Error ending call: \(error)")
          }
          self.isCallHandled = false
        })
        resolve(["success": true])
        return
      } else {
        CustomLogger.logSlack(message: ":x: Failed to reject call\nid: \(callID)\nerror: \(String(describing: error))")
        reject("Failed to reject call", error?.localizedDescription, error)
        return
      }
    }
  }
  
  @objc public func hangup(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if isCallHandled {
      reject("Call already handled", "Call already handled", nil)
      return
    }

    client.hangup(callID) { error in
      if error == nil {
        self.isCallHandled = true
        self.callStartedAt = nil
        self.callID = nil
        self.outbound = false

        do {
          try VGVoiceClient.disableAudio(self.audioSession)
        } catch {
          // Fail silently
        }
        let transaction = CXTransaction(action: CXEndCallAction(call: UUID(uuidString: callID)!))
        self.callController.request(transaction, completion: { error in
          if let error = error {
            print("Error ending call: \(error)")
          }
          self.isCallHandled = false
        })
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

  @objc public func handleIncomingPushNotification(notification: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard isVonagePush(with: notification) else {
      callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
      return
    }

    processNotification(notification: notification)
  }

  @objc public func serverCall(to: String, customData: [String: String]? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    var callData = ["to": to]

    if let customData = customData {
      callData.merge(customData) { (_, new) in new }
    }
    self.outbound = true
    self.caller = to
    client.serverCall(callData) { error, callID in
      if error == nil {
        self.callKitProvider.reportOutgoingCall(with: UUID(uuidString: callID!)!, startedConnectingAt: Date())
        self.callID = callID
        self.callStartedAt = Date()
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

  @objc public func sendDTMF(dtmf: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
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

  private func extractCallerNumber(from notification: Dictionary<String, Any>) -> String? {
    let nexmo = notification["nexmo"] as? [String: Any]
    let body = nexmo?["body"] as? [String: Any]
    let channel = body?["channel"] as? [String: Any]
    let from = channel?["from"] as? [String: Any]
    return from?["number"] as? String
  }

  private func extractCallId(from notification: Dictionary<String, Any>) -> String? {
    let nexmo = notification["nexmo"] as? [String: Any]
    let body = nexmo?["body"] as? [String: Any]
    let channel = body?["channel"] as? [String: Any]
    return channel?["id"] as? String
  }

  private func reportNewIncomingCall(callId: String, number: String) {
    let callUpdate = CXCallUpdate()

    callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: "+\(number)")
    self.callKitProvider.reportNewIncomingCall(with: UUID(uuidString: callId)!, update: callUpdate) { error in
      if let error = error {
        print("Error reporting call: \(error.localizedDescription)")
        CustomLogger.logSlack(message: ":x: Failed to report new incoming call\ncallId: \(callId)\nnumber: \(number)\nerror: \(error.localizedDescription)")
        self.callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .unanswered)
      } else {
        self.callID = callId
        self.caller = number
        self.outbound = false
      }
    }
  }

  private func refreshSessionAndReportCall(callId: String, number: String, notification: Dictionary<String, Any>) {
    if let userInfo = voipNotification?.userInfo,
        let block = userInfo["refreshSessionBlock"] as? AnyObject,
        let refreshVonageTokenUrl = userInfo["refreshVonageTokenUrlString"] as? String {
      let refreshSessionBlock = unsafeBitCast(block, to: (@convention(block) (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void).self)
      refreshVonageTokenUrlString = refreshVonageTokenUrl

      isRefreshing = true

      let startTime = Date()
      let maxWaitTime: TimeInterval = 1.5

      let semaphore = DispatchSemaphore(value: 0)

      let backgroundTaskID = UIApplication.shared.beginBackgroundTask {
          CustomLogger.logSlack(message: ":hourglass_flowing_sand: Refresh session background task expired\ninfo:\(self.debugAdditionalInfo)")
      }

      refreshSessionBlock({ result in
        if let result = result as? [String: Any],
          let token = result["accessToken"] as? String {
          self.contactService.prepareCallInfo(number: number, token: token) { success, error in
            if let error = error {
              print("Error updating contact image: \(error)")
            }
            semaphore.signal()
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
          }
          self.setRegion(region: UserDefaults.standard.string(forKey: "vonage.region"))
          self.refreshTokens(accessToken: token) { error in
            if let error = error {
              print(error.localizedDescription)
                CustomLogger.logSlack(message: ":key: Failed to refresh Vonage session\nerror: \(error.localizedDescription)\ninfo:\(self.debugAdditionalInfo)")
            } else {
              self.isLoggedIn = true
              self.client.processCallInvitePushData(notification)
              self.isRefreshing = false
            }
          }
        } else {
          print("Failed to refresh session")
            CustomLogger.logSlack(message: ":key: Failed to refresh session\ninfo:\(self.debugAdditionalInfo)")
        }
      }, { code, message, error in
        CustomLogger.logSlack(message: ":key: Failed to refresh session\ncode: \(String(describing: code))\nmessage: \(String(describing: message))\nerror: \(String(describing: error))")
        semaphore.signal()
        self.isRefreshing = false
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
      })

      let result = semaphore.wait(timeout: .now() + maxWaitTime)

      if result == .timedOut {
        print("Refresh session timed out after \(maxWaitTime) seconds")
        CustomLogger.logSlack(message: ":hourglass_flowing_sand: Call UI timed out after \(maxWaitTime) seconds. Call reported successfully :white_check_mark:\ninfo:\(debugAdditionalInfo)")
        self.isRefreshing = false
      }

      self.reportNewIncomingCall(callId: callId, number: number)
    } else {
      callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .failed)
    }
  }

  private func processNotification(notification: Dictionary<String, Any>) {
    let newCallId = extractCallId(from: notification)
    let number = extractCallerNumber(from: notification)

    guard let newCallId = newCallId, let number = number else {
      callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
      return
    }
    refreshSessionAndReportCall(callId: newCallId, number: number, notification: notification)
  }

  func waitForRefreshCompletion(completion: @escaping () -> Void) {
    if !isRefreshing {
      completion()
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.waitForRefreshCompletion(completion: completion)
      }
    }
  }
}
