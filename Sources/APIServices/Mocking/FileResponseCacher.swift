import Foundation

/// The path to the folder in which we store any cached network responses.
///
/// This is set using the key `"mock_data_directory"` in the Info.plist (ex. `${PROJECT_DIR}/MockJSON/`)
var mockDataDirectoryPath: String {
    guard let path = Bundle.main.object(forInfoDictionaryKey: "mock_data_directory") as? String else {

        if Configuration.shouldUseMockData || Configuration.shouldCacheResponses {
            fatalError("Please add your test JSON root folder path to the main target's Info.plist as \"mock_data_directory\"")
        } else {
            return ""
        }
    }
    return path
}

/// Represents an object capable of saving a network response in a local directory as a JSON file.
/// Most functionality is provided to the adopter through extensions of this protocol.
protocol FileResponseCacher {
    /// The name of the service; used as a path component in an outgoing request
    /// and as a folder name when caching the response.
    var serviceName: String { get }
    /// The location of the folder on your local harddrive in which responses should be cached.
    /// Uses ``mockDataDirectoryPath`` by default.
    var rootFolderPath: String { get }
    /// A convenient interface to the contents of the file system, and the primary means of interacting with it.
    /// Uses `.default` by default.
    var fileManager: FileManager { get }
}

/// Defines the desired course of action should we attempt to save a file matching the name of an existing file.
enum ResponseCacheDuplicateOption {
    case overwrite
    //    case createExtraInstance Coming soon?
    case ignore
}

extension FileResponseCacher {
    var fileManager: FileManager { FileManager.default }
    var rootFolderPath: String { mockDataDirectoryPath }

    private var folderPath: String? {
        var bundlePathURL = URL(fileURLWithPath: rootFolderPath)
        bundlePathURL = bundlePathURL.appendingPathComponent(serviceName)

        let bundlePath = bundlePathURL.path
        try? fileManager.createDirectory(atPath: bundlePath, withIntermediateDirectories: true, attributes: nil)

        return bundlePath
    }

    /// Generate a complete file location URL for the network response of the resource path provided.
    /// - Parameter fileName: The name of the file to be saved, matching the final path component of a network request.
    /// - Returns: The (desired) location of a JSON file reprepenting a network response.
    func mockDataUrl(forResourcePath fileName: String) -> URL? {
        guard let path = folderPath else {
            return nil
        }
        return URL(fileURLWithPath: path)
            .appendingPathComponent(fileName)
            .appendingPathExtension("json")
    }

    /// Save the response of a network call to a local folder for use in unit testing or running the app without a network connection.
    /// - Parameters:
    ///   - data: The raw data of a network respnse.
    ///   - fileName: The name of the file to be saved, matching the final path component of a network request.
    ///   - duplicateOption: The desired course of action should we attempt to save a file matching the name of an existing file.
    /// - Returns: The location in which the file was saved. This result can be ignored.
    @discardableResult
    func saveResponse(
        data: Data,
        resourcePath fileName: String,
        duplicateOption: ResponseCacheDuplicateOption = .ignore
    ) throws -> String {
        guard let fileURL = mockDataUrl(forResourcePath: fileName) else {
            throw URLError(.cannotCreateFile)
        }

        try Self.saveResponse(
            data: data,
            fileURL: fileURL,
            duplicateOption: duplicateOption,
            fileManager: fileManager
        )

        return fileURL.absoluteString
    }

    /// Save the response of a network call to a local folder for use in unit testing or running the app without a network connection.
    /// - Parameters:
    ///   - data: The raw data of a network respnse.
    ///   - fileURL: The desired location of a JSON file reprepenting a network response.
    ///   - duplicateOption: The desired course of action should we attempt to save a file matching the name of an existing file.
    ///   - fileManager: The object used to determine whether or not the file already exsists.
    /// - Returns: The location in which the file was saved. This result can be ignored.
    static func saveResponse(
        data: Data,
        fileURL: URL,
        duplicateOption: ResponseCacheDuplicateOption = .ignore,
        fileManager: FileManager = FileManager.default
    ) throws {
        // Make sure we have a folder to save our response into
        let folderPath = String(fileURL.path.dropLast(fileURL.lastPathComponent.count))
        try? fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)

        switch duplicateOption {
        case .ignore where fileManager.fileExists(atPath: fileURL.path):
            return

        default:
            do {
                try data.write(to: fileURL)
                print("🥸💾 Response successfully saved to", fileURL.path)

            } catch {
                print(
                    "🥸❌ Response could not be saved to",
                    fileURL.path,
                    "ERROR:",
                    error.localizedDescription
                )
                throw error
            }
        }
    }
}
