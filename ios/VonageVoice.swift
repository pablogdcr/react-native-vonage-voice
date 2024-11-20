import VonageClientSDKVoice
import CallKit
import AVFoundation
import Combine

extension NSNotification.Name {
    static let voipPushReceived = NSNotification.Name("voip-push-received")
}

typealias RefreshSessionBlock = (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void

@objc(VonageVoice)
public class VonageVoice: NSObject {
    @objc public static let shared = VonageVoice()

    let callController: CallController!
    private var cancellables = Set<AnyCancellable>()

    private var isProcessingAnswer = false
    private var isProcessingReject = false
    private var isProcessingHangup = false
    private var isProcessingMute = false
    private var isProcessingUnmute = false
    private var isProcessingSpeaker = false
    private var isProcessingServerCall = false
    private var isProcessingDTMF = false

    @objc var debugAdditionalInfo: String? {
        get {
            return UserDefaults.standard.string(forKey: Constants.debugInfoKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.debugInfoKey)
        }
    }

    override init() {
        VGVoiceClient.isUsingCallKit = true

        let info = UserDefaults.standard.string(forKey: Constants.debugInfoKey)
        callController = VonageCallController(logger: CustomLogger(debugAdditionalInfo: info))

        super.init()

        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
    }

    @objc public func saveDebugAdditionalInfo(info: String?) {
        guard let info = info else {
            return
        }
        callController.saveDebugAdditionalInfo(info: info)
    }

    @objc public func setRegion(region: String) {
        callController.setRegion(region: region)
    }

    @objc public func login(jwt: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        callController.updateSessionToken(jwt, completion: { error in
            if error == nil {
                resolve(["success": true])
            } else {
                reject("LOGIN_ERROR", error?.localizedDescription, error)
            }
        })
    }

    @objc public func logout(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        callController.updateSessionToken(nil, completion: { error in
            if error == nil {
                resolve(["success": true])
            } else {
                reject("LOGOUT_ERROR", error?.localizedDescription, error)
            }
        })
    }

    private func data(fromHexString hexString: String) -> Data? {
        var data = Data()
        var hex = hexString

        // Remove any non-hex characters
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

    private func invalidatePushToken(_ completion: (() -> Void)? = nil) {
        if let deviceId = UserDefaults.standard.object(forKey: Constants.deviceId) as? String {
            callController.unregisterPushTokens(deviceId) { error in
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
        guard let tokenData = data(fromHexString: token) else {
            reject("Invalid token", "Token is not a valid string", nil)
            return
        }

        shouldRegisterToken(with: tokenData) { shouldRegister in
            if shouldRegister {
                self.callController.registerPushTokens(tokenData, isSandbox: isSandbox) { error, deviceId in
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

    @objc public func unregisterDeviceTokens(deviceId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        callController.unregisterPushTokens(deviceId) { error in
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

    @objc public func answerCall(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingAnswer else {
            reject("ALREADY_PROCESSING", "Already processing an answer request", nil)
            return
        }
        isProcessingAnswer = true
        
        callController.reportCXAction(CXAnswerCallAction(call: UUID(uuidString: callId)!), completion: { [weak self] error in
            self?.isProcessingAnswer = false
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to answer call", error?.localizedDescription, error)
            }
        })
    }

    @objc public func rejectCall(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingReject else {
            reject("ALREADY_PROCESSING", "Already processing a reject request", nil)
            return
        }
        isProcessingReject = true
        
        callController.reportCXAction(CXEndCallAction(call: UUID(uuidString: callId)!), completion: { [weak self] error in
            self?.isProcessingReject = false
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to reject call", error?.localizedDescription, error)
            }
        })
    }

    @objc public func hangupCall(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingHangup else {
            reject("ALREADY_PROCESSING", "Already processing a hangup request", nil)
            return
        }
        isProcessingHangup = true
        
        callController.reportCXAction(CXEndCallAction(call: UUID(uuidString: callId)!), completion: { [weak self] error in
            self?.isProcessingHangup = false
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to hangup call", error?.localizedDescription, error)
            }
        })
    }

    @objc public func mute(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingMute else {
            reject("ALREADY_PROCESSING", "Already processing a mute request", nil)
            return
        }
        isProcessingMute = true
        
        callController.reportCXAction(CXSetMutedCallAction(call: UUID(uuidString: callId)!, muted: true), completion: { [weak self] error in
            self?.isProcessingMute = false
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to mute call", error?.localizedDescription, error)
            }
        })
    }

    @objc public func unmute(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingUnmute else {
            reject("ALREADY_PROCESSING", "Already processing an unmute request", nil)
            return
        }
        isProcessingUnmute = true
        
        callController.reportCXAction(CXSetMutedCallAction(call: UUID(uuidString: callId)!, muted: false), completion: { [weak self] error in
            self?.isProcessingUnmute = false
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to unmute call", error?.localizedDescription, error)
            }
        })
    }

    @objc public func enableSpeaker(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingSpeaker else {
            reject("ALREADY_PROCESSING", "Already processing a speaker request", nil)
            return
        }
        isProcessingSpeaker = true
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.overrideOutputAudioPort(.speaker)
            isProcessingSpeaker = false
            resolve(["success": true])
        } catch {
            isProcessingSpeaker = false
            reject("Failed to enable speaker", error.localizedDescription, error)
        }
    }

    @objc public func disableSpeaker(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingSpeaker else {
            reject("ALREADY_PROCESSING", "Already processing a speaker request", nil)
            return
        }
        isProcessingSpeaker = true
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.overrideOutputAudioPort(.none)
            isProcessingSpeaker = false
            resolve(["success": true])
        } catch {
            isProcessingSpeaker = false
            reject("Failed to disable speaker", error.localizedDescription, error)
        }
    }

    @objc public func serverCall(to: String, customData: [String: String]? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingServerCall else {
            reject("ALREADY_PROCESSING", "Already processing a server call request", nil)
            return
        }
        isProcessingServerCall = true
        
        var callData = ["to": to]
        if let customData = customData {
            callData.merge(customData) { (_, new) in new }
        }

        callController.startOutboundCall(callData) { [weak self] error, callId in
            self?.isProcessingServerCall = false
            if let error = error {
                reject("Failed to start server call", error.localizedDescription, error)
            } else {
                resolve(callId)
            }
        }
    }

    @objc public func sendDTMF(dtmf: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingDTMF else {
            reject("ALREADY_PROCESSING", "Already processing a DTMF request", nil)
            return
        }
        isProcessingDTMF = true
        
        callController.sendDTMF(dtmf) { [weak self] error in
            self?.isProcessingDTMF = false
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to send DTMF", error?.localizedDescription, error)
            }
        }
    }
}

extension VonageVoice {
    @objc public func subscribeToCallEvents() {
        callController.calls
            .flatMap { $0 }
            .sink { call in
                let callData: [String: Any] = [
                    "id": call.id.uuidString,
                    "status": call.status.description,
                    "isOutbound": call.isOutbound,
                    "phoneNumber": call.phoneNumber,
                    "startedAt": call.startedAt?.timeIntervalSince1970 ?? 0
                ]
                
                EventEmitter.shared.sendEvent(withName: Event.callEvents.rawValue, body: callData)
            }
            .store(in: &cancellables)
    }

    @objc public func unsubscribeFromCallEvents() {
        cancellables.removeAll()
    }
}
