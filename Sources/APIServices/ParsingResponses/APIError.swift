import Foundation

/// Represents the type of error thrown when using an API Service.
public enum APIError: LocalizedError {
    /// The request has returned a 401 error, meaning the user does not have to proper credentials to receive that data.
    case unauthorized
    /// The request returned an empty payload.
    case noData
    /// The request returned `Data` that could not be decoded for a known content encoding.
    case invalidData
    /// A malformed URL prevented a URL request from being initiated.
    case badURL
    /// The request returned a response indicating a failure to update.
    case failureResponse
    /// The request was dropped because we are still waiting for the user to sign in again.
    case awaitingAuthorization
    /// A custom server-side error provided through an [APIResponse](x-source-tag://APIResponse ).
    /// - Parameters:
    ///   - code: The raw value of an error code
    ///   - message: Provide user friendly text to represent the error. If you do not, the following default message will be provided:
    ///     `"There was an error processing your request ({code})"`
    case server(code: Int, message: String?)
    /// An external error occurred that can be capture through this error case to provide a more user-friendly `errorDescription`
    /// - Parameters:
    ///   - code: The raw value of an error code
    case httpError(code: Int)

    /// A localized user-facing message describing the error.
    public var errorDescription: String? {
        switch self {
        case .server(let code, let message):
            if let message = message {
                return message
            }
            return Self.message(forCode: code)

        case .httpError(let code):
            return Self.message(forCode: code)

        case .unauthorized:
            return NSLocalizedString(
                "Something went wrong. Please sign in to continue.",
                comment: "Error message when a request returned an unauthorized error & we were forced to sign them out."
            )
        case .awaitingAuthorization:
            // Providing an empty string to avoid showing an error messge toast
            return ""

        default:
            return NSLocalizedString(
                "An error occurred, please try again",
                comment: "A generic APIError message body."
            )
        }
    }

    private static func message(forCode code: Int) -> String {
        let format = NSLocalizedString(
            "There was an error processing your request (%ld)",
            comment: "Request error message with error code."
        )
        return String(format: format, code)
    }
}
