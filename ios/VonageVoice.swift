import VonageClientSDKVoice
import CallKit

extension NSNotification.Name {
    static let voipPushReceived = NSNotification.Name("voip-push-received")
}

@objc(VonageVoice)
class VonageVoice: NSObject {
    private let client = VGVoiceClient()
    
    private var ongoingPushKitCompletion: () -> Void = { }
    private var storedAction: (() -> Void)?
    private var isActiveCall = false
    private var callID: String?
    private var caller: String?
    private var isLoggedIn = false
    private var audioSession = AVAudioSession.sharedInstance()
    private var callKitProvider: CXProvider
    private var callController = CXCallController()
    
    override init() {
        let configuration = CXProviderConfiguration(localizedName: "Allo")
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.phoneNumber]
        
        self.callKitProvider = CXProvider(configuration: configuration)
        super.init()

        self.callKitProvider.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleVoidPushNotification(_:)), name: NSNotification.Name.voipPushReceived, object: nil)
        initializeClient()
    }
    
    private func initializeClient() {
        VGVoiceClient.isUsingCallKit = true
    }

    @objc
    private func handleVoidPushNotification(_ notification: Notification) {
        handleIncomingPushNotification(notification: notification.object as! Dictionary<String, Any>) { _ in
        } reject: { _, _, error in
            print("Incoming Push unhandled", error)
        }
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
        client.delegate = self
    }

    @objc(createSessionWithSessionID:sessionID:resolver:rejecter:)
    public func loginWithSessionID(jwt: String, sessionID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isActiveCall else {
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
        guard !isActiveCall else {
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
                self.isActiveCall = true
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
    
    @objc(handleIncomingPushNotification:resolver:rejecter:)
    public func handleIncomingPushNotification(notification: Dictionary<String, Any>, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if isVonagePush(with: notification) {
            if let invite = client.processCallInvitePushData(notification) {
                // Extract the caller number
                var callerNumber: String = "Unknown Caller"
                let nexmo = notification["nexmo"] as? [String: Any]
                let body = nexmo?["body"] as? [String: Any]
                let channel = body?["channel"] as? [String: Any]
                let from = channel?["from"] as? [String: Any]
                let number = from?["number"] as? String

                if let number = number {
                    callerNumber = "+" + number
                }

                let callUpdate = CXCallUpdate()
                callUpdate.localizedCallerName = callerNumber

                callKitProvider.reportNewIncomingCall(
                    with: UUID(uuidString: invite) ?? UUID(),
                    update: callUpdate
                ) { error in
                    if let error = error {
                        print("error", error)
                    } else {
                        self.callID = invite
                        self.caller = number
                    }
                }
            } else {
                callKitProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
            }
        }
    }
    
    private func endCallTransaction(action: CXEndCallAction) {
        callController.request(CXTransaction(action: action)) { error in
            if error == nil {
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
        self.isActiveCall = false
        callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
        self.isActiveCall = false
        
        callKitProvider.reportCall(with: UUID(uuidString: callId)!, endedAt: Date(), reason: .remoteEnded)
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveLegStatusUpdateForCall callId: String, withLegId legId: String, andStatus status: String) {
        EventEmitter.shared.sendEvent(withName: Event.receiveLegStatusUpdate.rawValue, body: ["callId": callId, "legId": legId, "status": status])
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectingForCall callId: String) {
        EventEmitter.shared.sendEvent(withName: Event.connectionStatusChanged.rawValue, body: ["callId": callId, "status": "reconnecting"])
    }

    public func voiceClient(_ client: VGVoiceClient, didReceiveMediaReconnectedForCall callId: String) {
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
        callID = nil
    }


    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        EventEmitter.shared.sendEvent(withName: Event.callConnecting.rawValue, body: ["callId": self.callID, "caller": self.caller])
        guard let callID else { return }
        client.answer(callID) { error in
            if error == nil {
                self.isActiveCall = true
                EventEmitter.shared.sendEvent(withName: Event.callAnswered.rawValue, body: ["callId": self.callID, "caller": self.caller])
                action.fulfill()
            } else {
                print("Failed to answer call", error)
                action.fail()
            }
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let callID else {
            endCallTransaction(action: action)
            return
        }
        if isActiveCall {
            client.hangup(callID) { error in
                if error == nil {
                    self.isActiveCall = false
                    self.endCallTransaction(action: action)
                } else {
                    print("Failed to reject call", error)
                    action.fail()
                }
                EventEmitter.shared.sendEvent(withName: Event.callRejected.rawValue, body: ["callId": self.callID, "caller": self.caller])
            }
        } else {
            client.reject(callID) { error in
                if error == nil {
                    self.isActiveCall = false
                    self.endCallTransaction(action: action)
                } else {
                    print("Failed to reject call", error)
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
