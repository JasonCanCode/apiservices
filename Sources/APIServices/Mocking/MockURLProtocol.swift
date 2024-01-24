import Foundation

extension URLSession {
    /// Toggles whether URLSession data is loaded from the ``MockURLProtocol``
    public static var useMockData: Bool = false {
        didSet {
            guard oldValue != useMockData else {
                return
            }
            
            if useMockData {
                URLProtocol.registerClass(MockURLProtocol.self)
            } else {
                URLProtocol.unregisterClass(MockURLProtocol.self)
            }
        }
    }
}

/// Implementation of `URLProtocol` that loads data from a registered ResponseLoader
/// instead of hitting the network for requests that it can handle.
class MockURLProtocol: URLProtocol {
    
    /// Delay automatically added to the time it takes to a load a response
    static var responseDelay: TimeInterval = 0
    
    /// Response loaders that will be used to load data for different endpoints
    static var responseLoaders: [Endpoint: ResponseLoader] = [:]
    
    /// Automatically configures the ``responseLoaders`` with the contents of the given directory
    ///
    /// The directory should be structed as:
    ///
    /// - [Root]
    ///     - [Endpoint.Service]
    ///         - [Endpoint.Method]
    ///         - [Endpoint.Method]
    ///     - [Endpoint.Service]
    ///         - [Endpoint.Method]
    ///
    /// The methods can either be a single json file with a name matching the method or a directory
    /// with a name matching the method containing multiple json files which will be loaded in sequence.
    /// 
    /// - Parameters:
    ///   - root: Relative path to the directory containing the json files
    ///   - bundle: Bundle that the directory is in
    static func configure(root: String, bundle: Bundle) throws {
        let rootUrl: URL = findFolder(named: root, within: bundle.bundleURL)
            ?? bundle.bundleURL.appendingPathComponent(root)
        
        for service in try contents(of: rootUrl) {
            for method in try contents(of: service) {
                let endpoint = method.deletingPathExtension().endpoint
                
                if method.hasDirectoryPath {
                    let files = try contents(of: method).sorted { first, second in
                        first.lastPathComponent < second.lastPathComponent
                    }
                    
                    responseLoaders[endpoint] = FileResponseLoader(urls: files)
                } else {
                    responseLoaders[endpoint] = FileResponseLoader(urls: [method])
                }
            }
        }
    }
    
    private static func loader(for url: URL) -> ResponseLoader? {
        responseLoaders[url.endpoint]
    }
}

// MARK: - Overrides
extension MockURLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        
        return loader(for: url) != nil
    }
    
    override func startLoading() {
        guard let client = client else { return }
        
        do {
            guard let url = request.url else {
                throw Error.unknown
            }
            
            guard let loader = Self.loader(for: url) else {
                throw Error.unknown
            }
            
            let data = try loader.load(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.responseDelay) {
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: data)
                client.urlProtocolDidFinishLoading(self)
            }
        } catch {
            client.urlProtocol(self, didFailWithError: error)
            client.urlProtocolDidFinishLoading(self)
        }
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    
    private enum Error: Swift.Error {
        case unknown
    }
}

// MARK: - Helpers

private func contents(of directory: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [],
        options: [.skipsHiddenFiles]
    )
}

private func findFolder(named root: String, within directory: URL) -> URL? {
    let folders: [URL] = folders(in: directory)

    if folders.isEmpty {
        return nil
    } else if let foundFolder: URL = folders.first(where: { $0.lastPathComponent == root }) {
        return foundFolder
    } else {

        for subFolder in folders {
            if let foundFolder = findFolder(named: root, within: subFolder) {
                return foundFolder
            }
        }
        return nil
    }
}

private func folders(in directory: URL) -> [URL] {
    guard let paths: [URL] = try? contents(of: directory) else {
        return []
    }
    return paths.filter(\.hasDirectoryPath)
}
