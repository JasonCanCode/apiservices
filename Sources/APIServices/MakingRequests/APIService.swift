import Foundation

/// Keeps track of whether or not we are waiting for the ``Configuration/unauthorizedResponseHandler`` to resolve.
/// This is passed into said function, in which it can be updated.
/// - SeeAlso: `sendRequest(_:)`
/// - Tag: AwaitingAuthorization
private var isAwaitingAuthorization: Bool = false

// MARK: - APIService

/// A service object used to streamline sending data requests to a dedicated backend API.
open class APIService: NSObject, APIServiceType {
    
    // MARK: - Instance Properties

    public var shouldUseMockData: Bool = Configuration.shouldUseMockData
    public var shouldCacheResponses: Bool = Configuration.shouldCacheResponses
    public let serviceName: String
    public let rootURLString: String
    
    // MARK: - Setup
    
    /// Create a new service to interact with the API within a certain feature extension.
    /// - Parameters:
    ///   - serviceName: The feature extension used within an API path.
    ///   - rootURLString: Provide a value to override the default root path used when constructing a complete API path.
    ///
    ///  - Example: When creating a service to fetch user information, you might provide the ``serviceName`` "Users".
    ///  Getting a user object from the endpoint ` https://www.mysite.com/service/Users/GetDetails` would look like this:
    ///  ```
    ///     let service = APIService(serviceName: "Users", rootURLString: "https://www.mysite.com/service")
    ///     let userData: Data = try await service.performRequest("GetDetails", parameters: userParams)
    ///     return userData
    ///  ```
    @objc public init(serviceName: String, rootURLString: String) {
        self.serviceName = serviceName

        var urlString = rootURLString
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        self.rootURLString = urlString
        
        super.init()
    }

    /// Create a new service to interact with the API within a certain feature extension.
    /// - Parameter serviceName: The feature extension used within an API path.
    @objc convenience public init(serviceName: String) {
        self.init(serviceName: serviceName, rootURLString: Configuration.defaultServerRootPath)
    }
}

// MARK: - Data Tasks

@objc public extension APIService {

    static func dataTask(_ request: URLRequest, completionHandler: RequestCompletionHandler?) -> CancelableTask {
        let taskHandler: () async throws -> Data = {
            try await sendRequest(request)
        }

        // Set up the possibility use of mock requests
        updateMockURLProtocol(withRequest: request, shouldUseMockData: Configuration.shouldUseMockData)

        guard Configuration.shouldCacheResponses else {
            // We don't need to worry about saving response data as mock JSON
            return ObjTask(taskHandler: taskHandler, completionHandler: completionHandler)
        }

        // Inject the side effect of caching the response into the original completionHandler
        return ObjTask(taskHandler: taskHandler, completionHandler: { data, error in

            if let data = data, let url = request.url, let fileURL = self.mockFileURL(fromRequestURL: url) {
                try? self.saveResponse(data: data, fileURL: fileURL)
            }
            completionHandler?(data, error)
        })
    }

    func dataTask(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        paramData: Data? = nil,
        completionHandler: RequestCompletionHandler?
    ) -> CancelableTask {

        let taskHandler: () async throws -> Data = {
            let request = try await self.request(
                resourcePath,
                httpMethod: httpMethod,
                parameterData: paramData
            )
            return try await Self.sendRequest(request)
        }

        // Set up the possibile use of mock requests
        updateMockFileLoader(forResourcePath: resourcePath)

        guard shouldCacheResponses else {
            // We don't need to worry about saving response data as mock JSON
            return ObjTask(taskHandler: taskHandler, completionHandler: completionHandler)
        }

        // Inject the side effect of caching the response into the original completionHandler
        return ObjTask(taskHandler: taskHandler, completionHandler: { [weak self] data, error in

            if let self = self, let data = data {
                _ = try? self.saveResponse(data: data, resourcePath: resourcePath)
            }
            completionHandler?(data, error)
        })
    }

    /// Create a task similar to `URLSessionDataTask` for performing and canceling a network request
    /// - Parameters:
    ///   - url: The absolute path of an API endpoint.
    ///   - parameters: A dictionary of information to be encoded as either JSON Data in the body or as a query string.
    ///   - completionHandler: A code block for handling the result of the request.
    /// - Returns: An abstraction of a `Task` that can be started with `resume()` and terminated prematurely with `cancel()`.
    ///
    /// This is a convenient way of generating a ``CancelableTask`` without needing to asynchronously generate a `URLRequest` first.
    static func dataTask(
        url: URL,
        parameters: JSON?,
        completionHandler: RequestCompletionHandler?
    ) -> CancelableTask {
        let paramData = requestBody(forParameters: parameters)

        let taskHandler: () async throws -> Data = {
            let request = await request(url: url, parameterData: paramData)

            // Set up the possibility use of mock requests
            updateMockURLProtocol(withRequest: request, shouldUseMockData: Configuration.shouldUseMockData)

            return try await sendRequest(request)
        }

        guard Configuration.shouldCacheResponses else {
            // We don't need to worry about saving response data as mock JSON
            return ObjTask(taskHandler: taskHandler, completionHandler: completionHandler)
        }

        let injectedHandler: (Data?, Error?) -> Void = { data, error in
            // Inject the side effect of caching the response into the original completionHandler
            if let data = data, let fileURL = self.mockFileURL(fromRequestURL: url) {
                try? self.saveResponse(data: data, fileURL: fileURL)
            }
            completionHandler?(data, error)
        }

        return ObjTask<Data>(taskHandler: taskHandler, completionHandler: injectedHandler)
    }
}

// MARK: - Private Helpers

private extension APIService {
    
    static func sendRequest(_ request: URLRequest) async throws -> Data {
        guard !isAwaitingAuthorization else {
            throw APIError.awaitingAuthorization
        }
        try Task.checkCancellation()
        
        do {
            let (data, _): (Data, URLResponse) = try await URLSession.shared.data(with: request)
            return data

        } catch {

            switch error {
            case APIError.unauthorized:
                let shouldRetry = try await Configuration.unauthorizedResponseHandler(&isAwaitingAuthorization)
                
                if shouldRetry {
                    return try await sendRequest(request)
                }
            default:
                break
            }
            throw error
        }
    }
}
