import VonageClientSDKVoice
import CallKit
import AVFoundation
import Combine
import PushKit

extension NSNotification.Name {
    static let voipPushReceived = NSNotification.Name("voip-push-received")
    static let voipTokenRegistered = NSNotification.Name("register")
    static let voipTokenInvalidated = NSNotification.Name("voip-token-invalidated")
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
    private static var isVoipRegistered = false
    private static var lastVoipToken: String?
    
    // Audio properties
    private var audioEngine: AVAudioEngine?
    private var toneGenerator: AVAudioSourceNode?
    private var sampleRate: Double = 44100.0
    private var currentSampleIndex: Int = 0
    private var currentSamples: [Float]?
    private var isPlaying = false
    private var stopDispatchWorkItem: DispatchWorkItem?

    // DTMF frequencies for each key
    private struct DTMF {
        static let frequencies: [String: (high: Float, low: Float)] = [
            "1": (697, 1209),
            "2": (697, 1336),
            "3": (697, 1477),
            "4": (770, 1209),
            "5": (770, 1336),
            "6": (770, 1477),
            "7": (852, 1209),
            "8": (852, 1336),
            "9": (852, 1477),
            "*": (941, 1209),
            "0": (941, 1336),
            "#": (941, 1477)
        ]
        
        // Pre-calculated samples for each key
        static let samples: [String: [Float]] = {
            let sampleRate = 44100.0
            let duration = 3.0 // 200ms
            let numSamples = Int(sampleRate * duration)
            
            return frequencies.reduce(into: [:]) { result, entry in
                var samples = [Float](repeating: 0, count: numSamples)
                for i in 0..<numSamples {
                    let t = Double(i) / sampleRate
                    let highAngle = 2.0 * Double.pi * Double(entry.value.high) * t
                    let lowAngle = 2.0 * Double.pi * Double(entry.value.low) * t
                    samples[i] = Float(sin(highAngle) + sin(lowAngle)) * 0.5
                }
                result[entry.key] = samples
            }
        }()
    }

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

        listenForCallEvents()
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc
    func invalidate() {
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
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

    @objc public func registerVonageVoipToken(token: String, isSandbox: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let tokenData = data(fromHexString: token) else {
            reject("Invalid token", "Token is not a valid string", nil)
            return
        }

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

    @objc public func reconnectCall(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        callController.reconnectCall(callId) { error in
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to reconnect call", error?.localizedDescription, error)
            }
        }
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
            let device = audioSession.availableInputs?.first { $0.portType == .builtInMic }

            try audioSession.overrideOutputAudioPort(.none)

            try? audioSession.setPreferredInput(device) // Disable Bluetooth input explicitly
            isProcessingSpeaker = false
            resolve(["success": true])
        } catch {
            isProcessingSpeaker = false
            reject("Failed to disable speaker", error.localizedDescription, error)
        }
    }

    @objc public func serverCall(to: String, customData: [String:Any]? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !isProcessingServerCall else {
            reject("ALREADY_PROCESSING", "Already processing a server call request", nil)
            return
        }
        isProcessingServerCall = true

        var callData: [String:Any] = ["to": to]
        if let customData = customData {
            for (key, value) in customData {
                callData[key] = value
            }
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
        callController.sendDTMF(dtmf) { error in
            if error == nil {
                resolve(["success": true])
            } else {
                reject("Failed to send DTMF", error?.localizedDescription, error)
            }
        }
    }

    @objc public static func didUpdatePushCredentials(_ credentials: PKPushCredentials, forType type: PKPushType) {
        let tokenString = credentials.token.map { String(format: "%02x", $0) }.joined()

        self.lastVoipToken = tokenString
        NotificationCenter.default.post(
            name: .voipTokenRegistered,
            object: nil,
            userInfo: ["token": tokenString]
        )
    }

    @objc public static func didInvalidatePushTokenForType(_ type: PKPushType) {
        NotificationCenter.default.post(
            name: .voipTokenInvalidated,
            object: nil,
            userInfo: ["type": type]
        )
    }

    @objc public static func registerVoipToken() {
        if VonageVoice.isVoipRegistered && VonageVoice.lastVoipToken != nil {
            if let token = VonageVoice.lastVoipToken {
                NotificationCenter.default.post(
                    name: .voipTokenRegistered,
                    object: nil,
                    userInfo: ["token": token]
                )
            }
        } else {
            VonageVoice.isVoipRegistered = true

            DispatchQueue.main.async {
                let voipRegistry = PKPushRegistry(queue: .main)

                voipRegistry.delegate = RCTSharedApplication()?.delegate as? PKPushRegistryDelegate
                voipRegistry.desiredPushTypes = [.voIP]
            }
        }
    }

    @objc public func resetCallInfo() {
        callController.resetCallInfo()
    }
}

extension VonageVoice {
    @objc public func listenForCallEvents() {
        callController.calls
            .flatMap { $0 }
            .sink { call in
                let callData: [String: Any] = [
                    "id": call.id.uuidString,
                    "status": call.status.description,
                    "isOutbound": call.isOutbound,
                    "phoneNumber": call.phoneNumber,
                    "startedAt": call.startedAt?.timeIntervalSince1970 as Any
                ]
                
                print("[VonageVoice] Send call event: \(call.status.description)")
                EventEmitter.shared.sendEvent(withName: Event.callEvents.rawValue, body: callData)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .voipTokenRegistered)
            .sink { notification in
                if let token = notification.userInfo?["token"] as? String {
                    EventEmitter.shared.sendEvent(withName: Event.register.rawValue, body: ["token": token])
                }
            }
            .store(in: &cancellables)
    }
}

extension VonageVoice {
    @objc func handleRouteChange(notification: Notification) {
        guard !callController.vonageActiveCalls.value.isEmpty else {
            return
        }
        if let device = AVAudioSession.sharedInstance().currentRoute.outputs.first {
            EventEmitter.shared.sendEvent(
                withName: Event.audioRouteChanged.rawValue,
                body: [
                    "device": [
                        "name": device.portName,
                        "id": device.uid,
                        "type": device.portType
                    ]
                ]
            )
        }
    }

    @objc func getAvailableAudioDevices(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let devices = AVAudioSession.sharedInstance().availableInputs

        resolve(devices?.map { device in
            return [
                "name": device.portName,
                "id": device.uid,
                "type": device.portType
            ]
        })
    }

    @objc public func setAudioDevice(deviceId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let devices = AVAudioSession.sharedInstance().availableInputs
        let device = devices?.first { $0.uid == deviceId }

        if let device = device {
            callController.setAudioDevice(device) { error in
                if error == nil {
                    resolve(["success": true])
                } else {
                    reject("Failed to set audio device", error?.localizedDescription, error)
                }
            }
        } else {
            reject("Device not found", "Device with id \(deviceId) not found", nil)
        }
    }
}

extension VonageVoice {
    private func processAudioBuffer(ptr: UnsafeMutablePointer<Float>, frameCount: UInt32) {
        guard let samples = currentSamples else { return }
        
        for frame in 0..<Int(frameCount) {
            if currentSampleIndex < samples.count {
                ptr[frame] = samples[currentSampleIndex]
                currentSampleIndex += 1
            } else {
                ptr[frame] = 0
            }
        }
    }

    @objc public func playDTMFTone(key: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let samples = DTMF.samples[key] else {
            reject("INVALID_KEY", "Invalid DTMF key", nil)
            return
        }

        // If we're already playing, just update the samples
        if isPlaying {
            currentSampleIndex = 0
            currentSamples = samples
            resolve(["success": true])
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            reject("AUDIO_SESSION_ERROR", "Failed to configure audio session: \(error.localizedDescription)", error)
            return
        }

        // Reset state
        currentSampleIndex = 0
        currentSamples = samples
        isPlaying = true

        // Create and configure audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            reject("AUDIO_ENGINE_ERROR", "Failed to create audio engine", nil)
            return
        }

        // Create tone generator node
        toneGenerator = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            
            self.processAudioBuffer(ptr: ptr, frameCount: frameCount)
            return noErr
        }

        // Configure audio format
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                 sampleRate: sampleRate,
                                 channels: 1,
                                 interleaved: false)!

        // Attach and connect nodes
        audioEngine.attach(toneGenerator!)
        
        // Create a mixer node with volume control
        let mixerNode = AVAudioMixerNode()
        audioEngine.attach(mixerNode)
        
        // Connect nodes
        audioEngine.connect(toneGenerator!,
                          to: mixerNode,
                          format: format)
        
        audioEngine.connect(mixerNode,
                          to: audioEngine.mainMixerNode,
                          format: format)
        
        // Set volume
        mixerNode.volume = 0.005

        do {
            try audioEngine.start()
            
            // Cancel any existing stop work item
            stopDispatchWorkItem?.cancel()
            
            // Create new work item for automatic stop
            let workItem = DispatchWorkItem { [weak self] in
                self?.stopDTMFTone(resolve: nil, reject: nil)
            }
            stopDispatchWorkItem = workItem
            
            // Schedule automatic stop after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
            
            resolve(["success": true])
        } catch {
            print("Failed to start audio engine: \(error)")
            reject("AUDIO_ENGINE_ERROR", error.localizedDescription, error)
        }
    }

    @objc public func stopDTMFTone(resolve: RCTPromiseResolveBlock?, reject: RCTPromiseRejectBlock?) {
        // Cancel any pending automatic stop
        stopDispatchWorkItem?.cancel()
        stopDispatchWorkItem = nil
        
        audioEngine?.stop()
        audioEngine = nil
        toneGenerator = nil
        currentSampleIndex = 0
        currentSamples = nil
        isPlaying = false
        
        // Reset audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error resetting audio session: \(error)")
        }
        
        resolve?(["success": true])
    }
}
