import VonageClientSDKVoice

@objc(VonageVoice)
class VonageVoice: NSObject {
    
    public var pushToken: Data?
    
    private let client = VGVoiceClient()
    
    private var ongoingPushLogin = false
    private var ongoingPushKitCompletion: () -> Void = { }
    private var storedAction: (() -> Void)?
    private var isActiveCall = false
    private var callID: String?
    
    override init() {
        super.init()
        initializeClient()
    }
    
    private func initializeClient() {
        VGVoiceClient.isUsingCallKit = false
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
        config.enableWebsocketInvites = true
        client.setConfig(config)
        client.delegate = self
    }

    @objc(login:isPushLogin:resolver:rejecter:)
    public func login(jwt: String, isPushLogin: Bool = false, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        print("VPush: Login - isPush:", isPushLogin)
        guard !isActiveCall else {
            resolve(nil)
            return
        }
        
        ongoingPushLogin = isPushLogin
        
        client.createSession(jwt) { error, sessionID in
            if error == nil {
                if isPushLogin {
                    self.handlePushLogin()
                } else {
                    self.handleLogin()
                }
                resolve("Connected")
            } else {
                reject("LOGIN_ERROR", error?.localizedDescription, error)
            }
        }
    }
    
    
    private func handlePushLogin() {
        ongoingPushLogin = false
        
        storedAction?()
    }
    
    private func handleLogin() {
        if let token = pushToken {
            registerPushIfNeeded(with: token)
        }
    }
    
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
    
    @objc(answerCall:resolver:rejecter:)
    public func answerCall(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        self.client.answer(callID) { error in
            if error == nil {
                self.callID = callID
                resolve(["success": true])
            } else {
                reject("Failed to answer the call", error?.localizedDescription, error)
            }
        }
    }
    
    @objc(rejectCall:resolver:rejecter:)
    public func rejectCall(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        self.client.reject(callID) { error in
            if error == nil {
                self.callID = nil
                resolve(["success": true])
            } else {
                reject("Failed to reject call", error?.localizedDescription, error)
            }
        }
    }
    
    @objc(hangup:resolver:rejecter:)
    public func hangup(callID: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        self.client.hangup(callID) { error in
            if error == nil {
                self.callID = nil
                resolve("Call ended")
            } else {
                reject("Failed to hangup", error?.localizedDescription, error)
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
        print("VPush: Received invite", callId)
        //    providerDelegate.reportCall(callId, caller: caller, completion: ongoingPushKitCompletion)
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "callQuality": callQuality.rawValue, "reason": reason.rawValue])
        print("VPush: Received hangup", client, callId, callQuality, reason)
        isActiveCall = false
        //    providerDelegate.didReceiveHangup(callId)
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
        print("VPush: Received invite cancel", client, callId, reason)
        //    providerDelegate.reportFailedCall(callId)
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
        print("VPush: Session error", reasonString)
    }
}
