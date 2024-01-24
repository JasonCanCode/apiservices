import Foundation

/// ResponseLoader for loading data from the filesystem
///
/// Loads data from a sequence of files, looping back to the first one after reaching the end
class FileResponseLoader {
    
    private let urls: [URL]
    private var current: Int = 0
    
    /// Returns a ``FileResponseLoader`` that will load data from the given URLs in sequence
    ///
    /// - Parameter urls: File URLs to load data from
    init(urls: [URL]) {
        self.urls = urls
    }
    
    /// Returns a ``FileResponseLoader`` that will load data from the given json file
    ///
    /// - Parameters:
    ///   - fileName: Relative path of the file to load data from
    ///   - bundle: Bundle that the file is located in
    convenience init(_ fileName: String, bundle: Bundle) {
        self.init(files: [fileName], bundle: bundle)
    }
    
    /// Returns a ``FileResponseLoader`` that will load data from the given json files in sequence
    ///
    /// - Parameters:
    ///   - fileNames: List of relative paths to files to load data from
    ///   - bundle: Bundle that the files are located in
    convenience init(files fileNames: [String], bundle: Bundle) {
        let urls: [URL] = fileNames.map { fileName in
            guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
                fatalError("JSON file named \(fileName) not found")
            }
            
            return url
        }
        
        self.init(urls: urls)
    }
    
    /// Returns a ``FileResponseLoader`` that will load data from json files in the given directory in sequence
    ///
    /// Files will be loaded from in alphabetical order
    ///
    /// - Parameters:
    ///   - directory: Relative path to the directory to load data from
    ///   - bundle: Bundle that the directory is located in
    convenience init(directory: String, bundle: Bundle) {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: directory) else {
            fatalError("Directory named \(directory) not found")
        }
        
        let sorted = urls.sorted { left, right in
            left.absoluteString < right.absoluteString
        }
        
        self.init(urls: sorted)
    }
}

// MARK: - ResponseLoader
extension FileResponseLoader: ResponseLoader {
    func load(_ request: URLRequest) throws -> Data {
        let url = urls[current]
        print("🥸🎣 Loading response with mock data:", url.path)
        
        // Move to the next url, looping back to the first one when we reach the end
        current = (current + 1) % urls.count
        return try Data(contentsOf: url)
    }
}
