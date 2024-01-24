// Adapted from this: https://stackoverflow.com/a/70416311

import Foundation

public extension URLSession {
    private typealias TaskCompletion = @Sendable (Data?, URLResponse?, Error?) -> Void
    private typealias URLTaskGenerator = (URLRequest, @escaping TaskCompletion) -> URLSessionTask
    
    /// Retrieves the data from the specified URL  in the provided request and delivers it asynchronously.
    /// - Parameter request: A URL request object that provides request-specific information such as the URL, cache policy, request type, and body data or body stream.
    /// - Returns: An asynchronously-delivered tuple that contains the URL contents as a `Data` instance, and a `URLResponse`.
    func data(with request: URLRequest) async throws -> (Data, URLResponse) {
        try await makeDataRequest(with: request, taskGen: dataTask(with:completionHandler:))
    }
    
    /// Uploads the data to the specified URL in the provided request and delivers it asynchronously.
    /// - Parameter request: A URL request object that provides request-specific information such as the URL, cache policy, request type, and body data or body stream.
    /// - Returns: An asynchronously-delivered tuple that contains the URL contents as a `Data` instance, and a `URLResponse`.
    func upload(with request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        let taskGen: URLTaskGenerator = { request, completionHandler in
            self.uploadTask(with: request, fromFile: fileURL, completionHandler: completionHandler)
        }

        return try await makeDataRequest(with: request, taskGen: taskGen)
    }
    
    /// Downloads the data from the specified URL in the provided request and delivers it asynchronously.
    /// - Parameter request: A URL request object that provides request-specific information such as the URL, cache policy, request type, and body data or body stream.
    /// - Returns: An asynchronously-delivered tuple that contains the downloaded file location encoded as a `Data` instance, and a `URLResponse`.
    func download(with request: URLRequest) async throws -> (Data, URLResponse) {
        let taskGen: URLTaskGenerator = { request, completionHandler in
            self.downloadTask(with: request) { url, response, error in
                // A hacky way to make the download task conform with the other types
                let data: Data? = url?.absoluteString.data(using: .utf8)
                completionHandler(data, response, error)
            }
        }
        
        return try await makeDataRequest(with: request, taskGen: taskGen)
    }
    
    private func makeDataRequest(
        with request: URLRequest,
        taskGen: @escaping URLTaskGenerator
    ) async throws -> (Data, URLResponse) {
        let sessionTask = URLSessionTaskActor()

        #if DEBUG
        print(NetworkLogger.cURLLog(request: request))
        #endif
        
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await sessionTask.start(taskGen(request) { data, response, error in
                        if let error: Error = error ?? Self.statusError(fromResponse: response) {
                            #if DEBUG
                            print(NetworkLogger.requestFailureLog(error: error, response: response))
                            #endif

                            continuation.resume(throwing: error)
                            return
                        }

                        guard let data = data, let response = response else {
                            let error = APIError.noData
                            continuation.resume(throwing: error)
                            Configuration.errorLogger.logError(error)
                            return
                        }
                        #if DEBUG
                        print(NetworkLogger.requestSuccessLog(data: data, response: response))
                        #endif

                        continuation.resume(returning: (data, response))
                    })
                }
            }

        }, onCancel: {
            Task { await sessionTask.cancel() }
        })
    }
    
    private static func statusError(fromResponse response: URLResponse?) -> Error? {
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return nil
        }

        switch statusCode {
        case 200...299:
            return nil
        case 401:
            return APIError.unauthorized
        default:
            let message = String(format: "There was an error processing your request (%ld)", statusCode)
            return APIError.server(code: statusCode, message: message)
        }
    }
}

private actor URLSessionTaskActor {
    weak var task: URLSessionTask?

    func start(_ task: URLSessionTask) {
        self.task = task
        task.resume()
    }

    func cancel() {
        task?.cancel()
    }
}
