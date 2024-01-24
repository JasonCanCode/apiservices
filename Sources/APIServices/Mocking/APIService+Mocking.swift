import Foundation

extension APIService: FileResponseCacher {

    /// Update the `MockURLProtocol` with a loader to access the file or remove the loader if we should no longer be providing mock data.
    /// - Parameter resourcePath: The name of the file to be loaded, matching the final path component of a network request.
    func updateMockFileLoader(forResourcePath resourcePath: String) {
        let endpoint = Endpoint(service: serviceName, method: resourcePath)
        let fileURL = mockDataUrl(forResourcePath: resourcePath)

        Self.updateMockFileLoader(forFileAt: fileURL, endpoint: endpoint, shouldUseMockData: shouldUseMockData)
    }

    /// Generate a complete file location URL for the network response of the resource path provided.
    /// - Parameter url: The URL of the network request the mock JSON file should be mimicing a response for.
    /// - Returns: The (desired) location of a JSON file reprepenting a network response.
    static func mockFileURL(fromRequestURL url: URL) -> URL? {
        let serverPathComponents: [String] = Configuration.defaultServerRootPath.components(separatedBy: "/")

        guard let lastServerPathComponent = serverPathComponents.last(where: { !$0.isEmpty }),
              let relativeFilePath = url.path.components(separatedBy: lastServerPathComponent).last else {
            return nil
        }
        let mockFilePath = (mockDataDirectoryPath + relativeFilePath).replacingOccurrences(of: "//", with: "/")

        return URL(fileURLWithPath: mockFilePath).appendingPathExtension("json")
    }

    /// Update the `MockURLProtocol` with a loader to access the file or remove the loader if we should no longer be providing mock data.
    /// - Parameters:
    ///   - request: The network request we should be providing a response for using lock mock JSON.
    ///   - shouldUseMockData: Should we be resolving requests with locally stored mock JSON instead of sending them off to our server.
    static func updateMockURLProtocol(withRequest request: URLRequest, shouldUseMockData: Bool) {
        guard let url = request.url?.deletingPathExtension(), let fileURL = mockFileURL(fromRequestURL: url) else {
            return
        }
        // Toggles whether URLSession data is loaded from the MockURLProtocol
        URLSession.useMockData = shouldUseMockData

        let resourcePath = url.lastPathComponent
        let service = url.deletingLastPathComponent().lastPathComponent
        let endpoint = Endpoint(service: service, method: resourcePath)

        updateMockFileLoader(forFileAt: fileURL, endpoint: endpoint, shouldUseMockData: shouldUseMockData)
    }

    private static func updateMockFileLoader(
        forFileAt fileURL: URL?,
        endpoint: Endpoint?,
        shouldUseMockData: Bool,
        fileManager: FileManager = .default
    ) {
        guard let endpoint = endpoint else {
            return
        }
        let isMockLoaderNeeded = MockURLProtocol.responseLoaders[endpoint] == nil

        if !shouldUseMockData {
            MockURLProtocol.responseLoaders[endpoint] = nil

        } else if isMockLoaderNeeded, let fileURL = fileURL, fileManager.fileExists(atPath: fileURL.path) {
            MockURLProtocol.responseLoaders[endpoint] = FileResponseLoader(urls: [fileURL])
        }
    }
}
