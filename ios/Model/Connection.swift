import Foundation

enum Connection {
    case connected
    case error(err:Error?)
    case reconnecting
    case disconnected(err:Error?)
}
