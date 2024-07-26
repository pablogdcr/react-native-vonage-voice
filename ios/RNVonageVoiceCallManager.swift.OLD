final class ClientManager: NSObject {
    public var pushToken: Data?

    func invalidatePushToken(_ completion: (() -> Void)? = nil) {
        print("VPush: Invalidate token")
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