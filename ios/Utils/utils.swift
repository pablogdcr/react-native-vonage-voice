import Foundation
import Combine
import VonageClientSDKVoice

extension Publisher {
    func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        self.map(Result.success)
            .catch { error in
                Just(.failure(error))
            }
            .eraseToAnyPublisher()
    }
}

extension VGSessionErrorReason: Error {}

extension UUID {
    func toVGCallID() -> String {
        return self.uuidString.lowercased()
    }
}
