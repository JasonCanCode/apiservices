import Foundation

/// The block of code to execute when a request task has concluded.
/// ObjC code that calls a function with the return type `async throws -> Data` will provide this handler in lieu of using Swift Concurrency.
public typealias RequestCompletionHandler = ((Data?, Error?) -> Void)

/// A service object used to streamline sending data requests to a dedicated backend API.
@objc public protocol APIServiceType: AnyObject {
    /// Should we be resolving requests with locally stored mock JSON instead of sending them off to our server.
    var shouldUseMockData: Bool { get set }
    /// Should we generate local JSON files from response data to use as mock JSON later on.
    var shouldCacheResponses: Bool { get set }
    /// The name of the service; used as a path component in an outgoing request.
    var serviceName: String { get }
    /// The default root path used when constructing a complete API path.
    var rootURLString: String { get }

    /// Generate a ``CancelableTask`` object that works like a `URLSessionTask` but allows you to cancel during any part of an asyc process.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - paramData: Data to include in the `httpBody` of the generated request.
    ///   - completionHandler: The block of code to execute when a request task has concluded.
    /// - Returns: An abstraction of a `Task` that can be started with `resume()` and terminated prematurely with `cancel()`.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    func dataTask(
        _ resourcePath: String,
        httpMethod: HTTPMethod,
        paramData: Data?,
        completionHandler: RequestCompletionHandler?
    ) -> CancelableTask

    /// Create a task similar to `URLSessionDataTask` for performing and canceling a network request
    /// - Parameters:
    ///   - request: The request that shall be send on `resume()`
    ///   - completionHandler: A code block for handling the result of the request.
    /// - Returns: An abstraction of a `Task` that can be started with `resume()` and terminated prematurely with `cancel()`.
    static func dataTask(_ request: URLRequest, completionHandler: RequestCompletionHandler?) -> CancelableTask
}

// MARK: - Perform Request

public extension APIServiceType {

    /// Send a provided request and return the response as `Data` on success in a thread-safe manner.
    /// - Parameter request: A complete request object **WITH NECESSARY HEADERS AND PARAMETERS INCLUDED.**
    /// - Returns: Data created from the network response.
    @MainActor
    static func performRequest(_ request: URLRequest) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            dataTask(request) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: APIError.noData)
                }
            }.resume()
        }
    }

    /// Send a generated `URLRequest`, injected with the proper headers and body data,
    /// and return the response as `Data` on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - paramData: Data to include in the `httpBody` of the generated request.
    /// - Returns: Data created from the network response.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    @MainActor
    func performRequest(_ resourcePath: String, httpMethod: HTTPMethod = .get, paramData: Data? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            dataTask(resourcePath, httpMethod: httpMethod, paramData: paramData) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: APIError.noData)
                }
            }.resume()
        }
    }

    /// Send a generated `URLRequest` in the background, injected with the proper headers and body data. **The result of the request is ignored.**
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - paramData: Data to include in the `httpBody` of the generated request.
    func performRequestInBackground(_ resourcePath: String, httpMethod: HTTPMethod = .get, paramData: Data? = nil) {
        Task {
            try await performRequest(resourcePath, httpMethod: httpMethod, paramData: paramData)
        }
    }

    /// Send a generated `URLRequest`, injected with the proper headers and body data,
    /// and return the response as `Data` on success in a thread-safe manner.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - parameters: An optional dictionary of information to be encoded as either JSON Data in the body or as a query string.
    /// - Returns: Data created from the network response.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    @MainActor
    func performRequest(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        parameters: JSON?
    ) async throws -> Data {
        let paramData = Self.requestBody(forParameters: parameters)
        return try await performRequest(resourcePath, httpMethod: httpMethod, paramData: paramData)
    }

    /// Send a generated `URLRequest` in the background, injected with the proper headers and body data.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - encodableBody: An `Encodable` object used to generate the data for the request body.
    /// - Returns: Data created from the network response.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    @MainActor
    func performRequest<Body: Encodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        encodableBody: Body
    ) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = Configuration.dateEncodingStrategy
        let paramData = try encoder.encode(encodableBody)

        return try await performRequest(resourcePath, httpMethod: httpMethod, paramData: paramData)
    }
}

// MARK: - Request Generation

public extension APIServiceType {

    /// Generate a `URLRequest` injected with the proper headers and body data.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - encodableBody: An `Encodable` object used to generate the data for the request body.
    /// - Returns: A complete request object with the necessary headers and parameters included.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    func request<Body: Encodable>(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        encodableBody: Body
    ) async throws -> URLRequest {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = Configuration.dateEncodingStrategy
        let paramData = try encoder.encode(encodableBody)
        return try await request(resourcePath, httpMethod: httpMethod, parameterData: paramData)
    }

    /// Generate a `URLRequest` injected with the proper headers and body data.
    /// - Parameters:
    ///   - resourcePath: The absolute path for creating the full endpoint path.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - parameterData: Data to include in the `httpBody` of the generated request.
    /// - Returns: A complete request object with the necessary headers and parameters included.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    func request(
        _ resourcePath: String,
        httpMethod: HTTPMethod = .get,
        parameterData: Data? = nil
    ) async throws -> URLRequest {

        let methodPath = (serviceName as NSString).appendingPathComponent(resourcePath)
        let urlString = rootURLString + methodPath

        guard let url = URL(string: urlString) else {
            throw APIError.badURL
        }
        return await Self.request(url: url, httpMethod: httpMethod, parameterData: parameterData)
    }

    /// Generate a `URLRequest` injected with the proper headers and body data.
    /// - Parameters:
    ///   - url: The absolute path of an API endpoint.
    ///   - httpMethod: The HTTP request method. Defaults to POST.
    ///   - encoding: The way in which our request parameters are being encoded within the request. Defaults to `APIServiceDataEncoding.json`.
    ///   - parameterData: Data to include in the `httpBody` of the generated request.
    /// - Returns: A complete request object with the necessary headers and parameters included.
    /// - SeeAlso: ``Configuration.addHeadersToRequest``
    static func request(
        url: URL,
        httpMethod: HTTPMethod = .get,
        encoding: APIServiceDataEncoding = .json,
        parameterData: Data? = nil
    ) async -> URLRequest {

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = httpMethod.rawValue

        if let params = parameterData {
            request.httpBody = params
        }
        return await addCustomHeaders(toRequest: request, encoding: encoding)
    }
}

// MARK: - Static Helpers

public extension APIServiceType {

    /// Create a new instance of the request object provided, now with the correct "Content-Type" header as well as any others provided through our injected Configuration.
    /// - Parameters:
    ///   - request: The original request in need of some headers.
    ///   - encoding: The way in which our request parameters are being encoded within the request. Defaults to `APIServiceDataEncoding.json`.
    /// - Returns: A new request instance with all the proper headers.
    static func addCustomHeaders(toRequest request: URLRequest, encoding: APIServiceDataEncoding = .json) async -> URLRequest {
        var improvedRequest = request

        let applicationFormat: String
        switch encoding {
        case.json:
            applicationFormat = "application/json;"
        case .url:
            applicationFormat = "application/x-www-form-urlencoded;"
        }
        improvedRequest.setValue(applicationFormat, forHTTPHeaderField: "Content-Type")

        return await Configuration.addHeadersToRequest(improvedRequest)
    }

    /// Generate encoded `Data` to assign to a request's `httpBody`
    /// - Parameters:
    ///   - params: A dictionary of information to be encoded as either JSON Data in the body or as a query string.
    ///   - encoding: The way in which our request parameters are being encoded within the request.  Defaults to `APIServiceDataEncoding.json`.
    /// - Returns: A data object for an `httpBody`
    static func requestBody(forParameters params: JSON?, encoding: APIServiceDataEncoding = .json) -> Data? {
        guard let params = params else {
            return nil
        }

        switch encoding {
        case .url:
            return params.stringWithFormEncodedComponents.data(using: .utf8)
        case .json:
            return try? jsonEncoding(parameters: params)
        }
    }

    /// Encode dictionary of information as JSON Data.
    static func jsonEncoding(parameters: JSON) throws -> Data {
        try JSONSerialization.data(withJSONObject: parameters)
    }
}

// MARK: - Private Helper Extensions

private extension JSON {
    /// Convert a JSON dictionary into a request path's query string
    var stringWithFormEncodedComponents: String {
        let parameters = self
        var arguments: [String] = []

        for (key, value) in parameters {
            guard let keyString = queryString(from: key) else {
                continue
            }
            let valueString = queryString(from: value) ?? "\(value)"
            arguments.append(keyString + "=" + valueString)
        }
        return arguments.joined(separator: "&")
    }

    /// A query string generated by replacing all characters not `urlQueryAllowed`.
    ///
    /// This method is intended to percent-encode a URL component or subcomponent string, NOT the entire URL string.
    func queryString(from textObj: Any) -> String? {
        (textObj as? NSString)?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
    }
}
