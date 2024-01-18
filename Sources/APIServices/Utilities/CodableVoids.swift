import Foundation

/// When you have to provide an decodable result but your are expecting an empty response on success, use this.
public struct VoidResult: Decodable {
    public init() {}
}

/// When you have to provide an encodable request but have nothing that needs encoding, use this.
public struct VoidRequest: Encodable {
    public init() {}
}
