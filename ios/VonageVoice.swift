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
    private let client = VGVoiceClient()
    
    private var refreshSupabaseSessionBlock: RefreshSessionBlock?
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
    
    override init() {
        let configuration = CXProviderConfiguration(localizedName: "Allo")
        configuration.includesCallsInRecents = true
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.iconTemplateImageData = UIImage(named: "callKitAppIcon")?.pngData()
        configuration.supportedHandleTypes = [.phoneNumber]
        
        self.callKitProvider = CXProvider(configuration: configuration)
        super.init()

        self.callKitProvider.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoipPushNotification(_:)),
            name: NSNotification.Name.voipPushReceived,
            object: nil
        )

        initializeClient()
    }
    
    private func initializeClient() {
        VGVoiceClient.isUsingCallKit = true
    }

    private func isCallActive() -> Bool {
        return callID != nil && callStartedAt != nil
    }

    @objc
    private func handleVoipPushNotification(_ notification: Notification) {
        print("RECEIVED REFRESH TOKEN NOTIFICATION")
        if let userInfo = notification.userInfo,
           let block = userInfo["refreshSessionBlock"] as? AnyObject,
           let refreshVonageTokenUrl = userInfo["refreshVonageTokenUrlString"] as? String {
            
            let refreshSessionBlock = unsafeBitCast(block, to: (@convention(block) (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void).self)
            refreshSupabaseSessionBlock = refreshSessionBlock
            refreshVonageTokenUrlString = refreshVonageTokenUrl
        }
        
        handleIncomingPushNotification(notification: notification.object as! Dictionary<String, Any>) { _ in
        } reject: { _, _, error in
        }
    }
    
    
    @objc
    private func refeshTokens(_ completion: @escaping ((any Error)?, String?) -> Void) {
        refreshSupabaseSessionBlock?({ result in
            if let result = result as? [String: Any],
                let accessToken = result["accessToken"] as? String,
                let refreshVonageTokenUrlString = self.refreshVonageTokenUrlString {
                self.getVonageToken(urlString: refreshVonageTokenUrlString, token: accessToken) { result in
                    switch result {
                    case .success(let vonageToken):
                        print("Received Vonage Token: \(vonageToken)")
                        self.isLoggedIn ? self.client.refreshSession(vonageToken, callback: { error in
                            completion(error, nil)
                        })
                        : self.client.createSession(vonageToken, callback: completion)
                    case .failure(let error):
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        
        }, { code, message, error in
            print("Reject called with error: \(code), \(message), \(String(describing: error))")
        })
    }
    
    private func getVonageToken(urlString: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Ensure the URL is valid
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create a URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set the Authorization header with the Bearer token
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Create a URLSession data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Ensure we received data
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
        
        // Start the data task
        task.resume()
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
        guard !isLoggedIn else {
            reject("LOGIN_ERROR", "User is already logged in", nil)
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
            resolve(["callId": callID, "startedAt": callStartedAt!.timeIntervalSince1970, "status": "active"])
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
                resolve(["success": true])
                return
            } else {
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
                resolve(["success": true])
                return
            } else {
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
                resolve("Call ended")
                return
            } else {
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

        if isLoggedIn {
            processLoggedInUser(notification: notification)
        } else {
            processLoggedOutUser(notification: notification)
        }
    }

    private func processLoggedInUser(notification: Dictionary<String, Any>) {
        guard let invite = client.processCallInvitePushData(notification) else {
            callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
            return
        }

        if let number = extractCallerNumber(from: notification) {
            reportIncomingCall(invite: invite, number: number)
        } else {
            callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
        }
    }

    private func processLoggedOutUser(notification: Dictionary<String, Any>) {
        print("Processing logged out user")
        let nexmo = notification["nexmo"] as? [String: Any]
        let body = nexmo?["body"] as? [String: Any]
        let channel = body?["channel"] as? [String: Any]
        
        guard let invite = channel?["id"] as? String,
              let number = extractCallerNumber(from: notification) else {
            callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
            return
        }

        reportIncomingCall(invite: invite, number: number)
        setRegion(region: UserDefaults.standard.string(forKey: "vonage.region"))
        
        print("Refreshing tokens")
        refeshTokens { error, sessionId in
            if let error = error {
                print(error.localizedDescription)
            } else {
                print("Tokens refreshed")
                self.isLoggedIn = true
                self.client.processCallInvitePushData(notification)
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

    private func reportIncomingCall(invite: String, number: String) {
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: formatPhoneNumber(number) ?? number)
        
        callKitProvider.reportNewIncomingCall(with: UUID(uuidString: invite) ?? UUID(), update: callUpdate) { error in
            if let error = error {
                print("Error reporting call: \(error)")
            } else {
                self.callID = invite
                self.caller = number
            }
        }
    }


    private func endCallTransaction(action: CXEndCallAction) {
        callController.request(CXTransaction(action: action)) { error in
            if error == nil {
                self.callStartedAt = nil
                self.callID = nil
                action.fulfill()
            } else {
                action.fail()
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
         callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
        self.callStartedAt = nil
        self.callID = nil
        
        callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveLegStatusUpdateForCall callId: String, withLegId legId: String, andStatus status: VGLegStatus) {
        if status == .completed {
            EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "reason": "completed"])
            self.callStartedAt = nil
            self.callID = nil

            callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
        }
         EventEmitter.shared.sendEvent(withName: Event.receiveLegStatusUpdate.rawValue, body: ["callId": callId, "legId": legId, "status": status])
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
        EventEmitter.shared.sendEvent(withName: Event.receivedSessionError.rawValue, body: ["reason": reasonString])
    }
}

extension VonageVoice: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        callStartedAt = nil
        callID = nil
    }


    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])
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
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
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

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VGVoiceClient.enableAudio(audioSession)
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        VGVoiceClient.disableAudio(audioSession)
    }
}
