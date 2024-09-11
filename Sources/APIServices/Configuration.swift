import Foundation

/// Provides a means of capturing/communicating any errors that may occur.
public protocol ErrorLogger {
    func logError(_ error: Error)
}

/// A shared object to manage any dependency injections into the Network module.
public struct Configuration {
    /// A service for logging any issues. By default, this means printing to the console
    /// but we typically replace that with logging non-fatal errors in Crashlytics using a FirebaseHelper.
    public static var errorLogger: ErrorLogger = StandardErrorLogger()
    /// The root path used for url generation. For example: `"https://www.mysite.com/api"`
    public static var defaultServerRootPath = "https://www.mysite.com/api"
    /// Provide the function for providing an update request with custom headers.
    public static var addHeadersToRequest: (_ request: URLRequest) async -> URLRequest = { return $0 }
    /// The strategy to use in decoding dates.
    public static var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601
    /// The strategy to use for encoding dates.
    public static var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601
    /// Provide a block of code to execute when a network request returns a 401 (Unauthorized) error code.
    /// A mutatable boolean is passed in to be updated for tracking the progress of the response.
    /// The returned boolean indicates whether or not to retry the request. By default, it returns `false`.
    ///
    /// See how we mutate our [provided local variable](x-source-tag://AwaitingAuthorization) in order to prevent
    /// subsequent network calls to go through while we work on re-establishing authorization.
    public static var unauthorizedResponseHandler: (inout Bool) async throws -> Bool = { _ in return false }
    /// Should we be resolving requests with locally stored mock JSON instead of sending them off to our server.
    public static var shouldUseMockData: Bool = BuildConfig.isTesting
    /// Should we generate local JSON files from response data to use as mock JSON later on.
    public static var shouldCacheResponses: Bool = false
}

/// A default error logging service that prints to the console.
internal struct StandardErrorLogger: ErrorLogger {
    
    func logError(_ error: Error) {
        print("An error has occured:", error)
    }
}
