import Foundation

/// A set of methods that defines how to load data for a request
protocol ResponseLoader {
    /// Loads the response data for a given request
    func load(_ request: URLRequest) throws -> Data
}
