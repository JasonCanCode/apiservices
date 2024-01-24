import Foundation

/// HTTP method definitions.
///
/// See https://tools.ietf.org/html/rfc7231#section-4.3
@objc public class HTTPMethod: NSObject, ExpressibleByStringLiteral {
    public let rawValue: String
    
    public required init(stringLiteral value: String) {
        rawValue = value
    }
}

@objc public extension HTTPMethod {
    static var options: HTTPMethod { "OPTIONS" }
    static var get: HTTPMethod { "GET" }
    static var head: HTTPMethod { "HEAD" }
    static var post: HTTPMethod { "POST" }
    static var put: HTTPMethod { "PUT" }
    static var patch: HTTPMethod { "PATCH" }
    static var delete: HTTPMethod { "DELETE" }
    static var trace: HTTPMethod { "TRACE" }
    static var connect: HTTPMethod { "CONNECT" }
}
