import CallKit
import PushKit
import Combine
import VonageClientSDKVoice
import AVFoundation

typealias CallStream = AnyPublisher<Call,Never>

protocol CallController {
    // Public Stream of calls to drive custom UIs
    var calls: AnyPublisher<CallStream,Never> { get }
    var vonageActiveCalls: CurrentValueSubject<Dictionary<UUID,Call>,Never> { get }

    // Callkit actions initiated from custom application UI as opposed to System UI.
    func reportCXAction(_ cxaction:CXAction, completion: @escaping ((any Error)?) -> Void)
    
    // Provide Vonage Client with user JWT token for connection auth.
    func updateSessionToken(_ token: String?, completion: ((Error?) -> Void)?)
    
    // Register device notification tokens with Vonage
    func registerPushTokens(_ token: Data, isSandbox: Bool, callback: @escaping ((any Error)?, String?) -> Void)

    // Unregister device notification tokens with Vonage
    func unregisterPushTokens(_ deviceId: String, callback: @escaping ((any Error)?) -> Void)
    
    // Special case for CXStartCallAction
    func startOutboundCall(_ context:[String:String], completion: @escaping ((any Error)?, String?) -> Void)
    
    // Enable/Disable Noise Suppression in ongoing calls
    func toggleNoiseSuppression(call: Call, isOn: Bool)

    func setRegion(region: String?)

    func sendDTMF(_ dtmf: String, completion: @escaping ((any Error)?) -> Void)

    func saveDebugAdditionalInfo(info: String)
}

public class VonageCallController: NSObject {
    var cancellables = Set<AnyCancellable>()

    let logger: VGLogger?
    let client: VGVoiceClient
    let contactService = ContactService()

    // We create a series of Subjects (imperative publishers) to help
    // organise the different delegate callbacks received from VGClient
    let vonageWillReconnect = PassthroughSubject<Void, Never>()
    let vonageDidReconnect = PassthroughSubject<Void, Never>()
    let vonageSessionError = PassthroughSubject<VGSessionErrorReason, Never>()
    let vonageSession = CurrentValueSubject<String?, Never>(nil)
    
    // We transform delegate callbacks into a 'hot' stream of call updates
    // and a 'cold' subject which allows clients to understand current active calls
    let vonageCalls = PassthroughSubject<Call, Never>()
    let vonageCallUpdates = PassthroughSubject<(UUID, CallStatus), Never>()
    var vonageActiveCalls = CurrentValueSubject<Dictionary<UUID,Call>,Never>([:])

    var contactReady = false

    // Internal reactive storage for the token provided via `CallController.updateSessionToken()`
    private let vonageToken = CurrentValueSubject<String?,Never>(nil)
    
    var callProvider: CXProvider!
    lazy var cxController = CXCallController()

    var isRefreshing = false

    private var refreshSessionBlock: RefreshSessionBlock?
    
    @objc var debugAdditionalInfo: String? {
        get {
            return UserDefaults.standard.string(forKey: Constants.debugInfoKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.debugInfoKey)
        }
    }
    
    init(logger: VGLogger?) {
        self.logger = logger
        if let logger = logger {
            client = VGVoiceClient(VGClientInitConfig(
                loggingLevel: .error,
                customLoggers: [logger])
            )
        } else {
            client = VGVoiceClient(VGClientInitConfig(loggingLevel: .error))
        }

        super.init()
        client.delegate = self
        if let region = UserDefaults.standard.string(forKey: "vonage.region") {
            switch region {
            case "EU":
                client.setConfig(VGClientConfig(region: .EU))
            case "AP":
                client.setConfig(VGClientConfig(region: .AP))
            default:
                client.setConfig(VGClientConfig(region: .US))
            }
        }
        callProvider = initCXProvider()
        bindCallController()
        bindCallkit()

        contactService.resetCallInfo()
    }

    public func saveDebugAdditionalInfo(info: String) {
        debugAdditionalInfo = info
    }

    public func setRegion(region: String?) {
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
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension VonageCallController: CallController {
    // Calls updates are 'demuxed' into seperate streams to help subscribers
    // concentrate on specific call updates
    var calls: AnyPublisher<CallStream,Never> {
        return vonageCalls.map { call in
            self.vonageCallUpdates
                .filter { $0.0 == call.id }
                .map {
                    Call(call: call, status: $0.1)
                }
                .prepend(call)
                .removeDuplicates(by: {a,b in a.status == b.status })
                .share()
                .eraseToAnyPublisher()
        }
        .share()
        .eraseToAnyPublisher()
    }

    private func extractCallerNumber(from notification: Dictionary<String, Any>) -> String? {
        let nexmo = notification["nexmo"] as? [String: Any]
        let body = nexmo?["body"] as? [String: Any]
        let channel = body?["channel"] as? [String: Any]
        let from = channel?["from"] as? [String: Any]

        return from?["number"] as? String
    }

    private func reportVoipPush(_ notification: Dictionary<String, Any>, refreshVonageTokenUrl: String, refreshSessionBlock: (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void) {
        guard let number = extractCallerNumber(from: notification) else {
            self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":warning: Failed to extract phone number. Notification: \(notification)")
            callProvider.reportCall(with: UUID(), endedAt: Date(), reason: .failed)
            return
        }
        let maxWaitTime: TimeInterval = 4.0
        let semaphore = DispatchSemaphore(value: 0)
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":hourglass_flowing_sand: Refresh session background task expired")
        }

        self.isRefreshing = true
        refreshSessionBlock({ response in
            if let response = response as? [String: Any],
               let token = response["accessToken"] as? String {
                self.contactReady = false
                self.contactService.prepareCallInfo(number: number, token: token) { success, error in
                    if let error = error {
                        print("Error: \(error)")
                        self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to update contact image: \(error)")
                    } else {
                        print("No error. Contact ready.")
                        self.contactReady = true
                    }
                }


                let networkController = NetworkController()
                let api = RefreshTokenAPI(token: token, url: refreshVonageTokenUrl)

                networkController.sendRequest(apiType: api)
                    .sink { [weak self] completion in
                        guard let self = self else { 
                            semaphore.signal()
                            return 
                        }
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to refresh Vonage token: \(error)")
                        }
                    } receiveValue: { [weak self] (response: TokenResponse) in
                        guard let self = self else {
                            semaphore.signal()
                            return
                        }
                        self.updateSessionToken(response.data.token)
                        semaphore.signal()
                    }
                    .store(in: &self.cancellables)
            } else {
                self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":key: Failed to refresh session: No token in response.\nResponse: \(String(describing: response))")
                semaphore.signal()
            }
        }, { code, message, error in
            self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":key: Failed to refresh session\ncode: \(String(describing: code))\nmessage: \(String(describing: message))\nError: \(String(describing: error))")
            semaphore.signal()
        })

        let result = semaphore.wait(timeout: .now() + maxWaitTime)

        if result == .timedOut {
            self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":hourglass_flowing_sand: Call UI timed out after \(maxWaitTime) seconds. Call reported successfully :white_check_mark:")
        }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        self.isRefreshing = false
        self.client.processCallInvitePushData(notification)
    }

    func reportCXAction(_ cxaction: CXAction, completion: @escaping ((any Error)?) -> Void) {
        cxController.requestTransaction(with: [cxaction], completion: completion)
    }

    func updateSessionToken(_ token: String?, completion: ((Error?) -> Void)? = nil) {
        // If token is nil, just delete the session
        guard let token = token, token != "" else {
            client.deleteSession { error in
                completion?(error)
                if error == nil {
                    self.vonageToken.value = nil
                    self.vonageSession.send(nil)
                }
            }
            return
        }

        // Create session using Future
        Future<String?, Error> { promise in
            self.client.createSession(token) { error, session in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(session))
                }
            }
        }
        .sink(
            receiveCompletion: { result in
                switch result {
                case .failure(let error):
                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":eyes: Failed to create session: \(error)")
                    completion?(error)
                case .finished:
                    completion?(nil)
                }
            },
            receiveValue: { session in
                self.vonageSession.send(session)
                self.vonageToken.value = token
            }
        )
        .store(in: &cancellables)
    }

    // Normally we just forward all CXActions to Callkit
    // but we special case the start of outbound calls
    // so we can ensure the correct UUID can be provided to Callkit
    func startOutboundCall(_ context: [String : String], completion: @escaping ((any Error)?, String?) -> Void) {
        let session = Future<String?,Error> { p in
            self.client.createSession(self.vonageToken.value ?? "") { err, session in
                p(err != nil ? Result.failure(err!) : Result.success(session!))
            }
        }

        let call = session.flatMap { _ in
            Future<String,Error> { p in
                self.client.serverCall(context) { err, callId in
                    p(err != nil ? Result.failure(err!) : Result.success(callId!))
                }
            }
            .first()
        }

        call.asResult()
            .sink { result in
            switch (result) {
            case .success(let callId):
                self.vonageCalls.send(
                    Call.outbound(id: UUID(uuidString: callId)!, to: context["to"] ?? "unknown", status: .ringing)
                )
                completion(nil, callId)
            case .failure:
                completion(NSError(domain: "VonageVoice", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start server call"]), nil)
                return
            }
        }
        .store(in: &cancellables)
    }

    func sendDTMF(_ dtmf: String, completion: @escaping ((any Error)?) -> Void) {
        // Get the first active call from vonageActiveCalls
        guard let activeCall = vonageActiveCalls.value.first?.value else {
            self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "No active call found when trying to send DTMF")
            completion(NSError(domain: "VonageVoice", code: -3, userInfo: [NSLocalizedDescriptionKey: "No active call found when trying to send DTMF"]))
            return
        }
        
        client.sendDTMF(activeCall.id.toVGCallID(), withDigits: dtmf, callback: { error in
            if error == nil {
                completion(nil)
            } else {
                self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: "Failed to send DTMF: \(error?.localizedDescription ?? "unknown error")")
                completion(NSError(domain: "VonageVoice", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to send DTMF"]))
            }
        })
    }

    func unregisterPushTokens(_ deviceId: String, callback: @escaping ((any Error)?) -> Void) {
        client.unregisterDeviceTokens(byDeviceId: deviceId, callback: callback)
    }

    func registerPushTokens(_ token: Data, isSandbox: Bool = false, callback: @escaping ((any Error)?, String?) -> Void) {
        vonageSession.compactMap {$0}.first().sink { _ in
            self.client.registerVoipToken(token, isSandbox: isSandbox, callback: callback)
        }
        .store(in: &cancellables)
    }

    func toggleNoiseSuppression(call: Call, isOn: Bool) {
        let callId = call.id.toVGCallID()

        if isOn == true {
            client.enableNoiseSuppression(callId) { err in
                // Handle the completion/error if needed
            }
        } else {
            client.disableNoiseSuppression(callId) { err in
                // Handle the completion/error if needed
            }
        }
    }
}

extension VonageCallController {
    private func initCXProvider()-> CXProvider {
        let config: CXProviderConfiguration

        if #available(iOS 14.0, *) {
            config = CXProviderConfiguration()
        } else {
            config = CXProviderConfiguration(localizedName: "Allô")
        }

        config.includesCallsInRecents = true
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.iconTemplateImageData = UIImage(named: "callKitAppIcon")?.pngData()
        config.supportedHandleTypes = [.phoneNumber]

        let provider = CXProvider(configuration: config)

        provider.setDelegate(self, queue: nil)
        return provider
    }

    func bindCallController() {
        // Handle session deletion when token becomes nil
        vonageToken.dropFirst().filter { $0 == nil }.sink { _ in
            self.client.deleteSession { error in
                // Just log the error if needed
                if let error = error {
                    self.logger?.didReceiveLog(logLevel: .warn, topic: .DEFAULT.first!, message: ":eyes: Failed to delete session: \(error)")
                }
            }
        }.store(in: &cancellables)

        // Book keeping for active call
        self.calls
            .flatMap{ $0 }
            .scan(Dictionary<UUID,Call>()) { all, update  in
                var new = all
                if case .completed = update.status {
                    new.removeValue(forKey: update.id)
                }
                else {
                    new[update.id] = update
                }
                return new
            }
            .assign(to: \.value, on: vonageActiveCalls)
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: NSNotification.Name.voipPushReceived, object: nil, queue: nil) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let block = userInfo["refreshSessionBlock"] as? AnyObject,
                  let refreshVonageTokenUrl = userInfo["refreshVonageTokenUrlString"] as? String  else {
                print("failed: \(String(describing: notification.userInfo)) \(String(describing: self?.vonageActiveCalls.value))")
                return
            }
            let refreshSessionBlock = unsafeBitCast(block, to: (@convention(block) (@escaping RCTPromiseResolveBlock, @escaping RCTPromiseRejectBlock) -> Void).self)

            self.reportVoipPush(
                notification.object as! Dictionary<String, Any>,
                refreshVonageTokenUrl: refreshVonageTokenUrl,
                refreshSessionBlock: refreshSessionBlock
            )
        }
    }
}
