import VonageClientSDKVoice

@objc(VonageVoice)
class VonageVoice: NSObject {
    private let client = VGVoiceClient()
    
    private var ongoingPushKitCompletion: () -> Void = { }
    private var storedAction: (() -> Void)?
    private var isActiveCall = false
    private var callID: String?
    
    override init() {
        super.init()
        initializeClient()
    }
    
    private func initializeClient() {
        VGVoiceClient.isUsingCallKit = true
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

    @objc(login:resolver:rejecter:)
    public func login(jwt: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isActiveCall else {
            resolve(nil)
            return
        }
        
        client.createSession(jwt) { error, sessionID in
            if error == nil {
                resolve(sessionID)
            } else {
                reject("LOGIN_ERROR", error?.localizedDescription, error)
            }
        }
    }

    @objc(registerVoipToken:resolver:rejecter:)
    func registerVoipToken(token: String, isSandbox: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let tokenData = token.data(using: .utf8)

        shouldRegisterToken(with: tokenData) { shouldRegister in
            if shouldRegister {
                self.client.registerVoipToken(tokenData, isSandbox: isSandbox) { error, deviceId in
                    if error == nil {
                        UserDefaults.standard.setValue(tokenData, forKey: Constants.pushToken)
                        UserDefaults.standard.setValue(deviceId, forKey: Constants.deviceId)
                        resolve(deviceId)
                    } else {
                        reject("Failed to register token", error?.localizedDescription, error)
                        return
                    }
                }
            }
            resolve(nil)
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
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedHangup.rawValue, body: ["callId": callId, "callQuality": callQuality.rawValue, "reason": reason.rawValue])
        isActiveCall = false
    }
    
    public func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: String, with reason: VGVoiceInviteCancelReason) {
        EventEmitter.shared.sendEvent(withName: Event.receivedCancel.rawValue, body: ["callId": callId, "reason": reason.rawValue])
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
