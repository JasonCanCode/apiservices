import Foundation

/// Indicates how we should encode the request parameters/body when forming a `URLRequest`.
@objc public enum APIServiceDataEncoding: Int {
    case url
    case json
}
