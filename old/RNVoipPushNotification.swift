import PushKit

class RNVoipPushNotification: NSObject {
    let voipRegistry = PKPushRegistry(queue: nil)

    @objc(registerForVoIPPushes)
    func registerForVoIPPushes() {
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }
}

extension RNVoipPushNotification: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let deviceToken = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        print("[RNVoipPushNotification] didUpdatePushCredentials: \(deviceToken)")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        print("[RNVoipPushNotification] didReceiveIncomingPushWithPayload: \(payload.dictionaryPayload)")
    }
}
