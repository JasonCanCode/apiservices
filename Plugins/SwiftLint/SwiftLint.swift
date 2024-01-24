import Foundation
import PackagePlugin

@main
/// Custom plugin for running SwiftLint
///
/// The [plugin provided by SwiftLint](https://github.com/realm/SwiftLint/blob/main/Plugins/SwiftLintPlugin/SwiftLintPlugin.swift)
/// specifies the inputs and outputs differently and mysteriously causes ObjC classes to be unable to find the swift header
/// when run on our Xcode project
struct SwiftLint: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }
        
        let tool = try context.tool(named: "swiftlint")
        let swiftFilePaths = sourceTarget.sourceFiles(withSuffix: "swift").map(\.path)
        let config = context.package.directory.appending(".swiftlint.yml")
        let cache = context.pluginWorkDirectory.appending("cache")

        return try lint(targetName: target.name, tool: tool.path, files: swiftFilePaths, config: config, cache: cache)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLint: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        let tool = try context.tool(named: "swiftlint")
        
        let swiftFilePaths = target
            .inputFiles
            .filter { $0.type == .source && $0.path.extension == "swift" }
            .map(\.path)
        
        let config = context.xcodeProject.directory.appending(".swiftlint.yml")
        let cache = context.pluginWorkDirectory.appending("cache")
        
        return try lint(targetName: target.displayName, tool: tool.path, files: swiftFilePaths, config: config, cache: cache)
    }
}
#endif

private func lint(targetName: String, tool: Path, files: [Path], config: Path, cache: Path) throws -> [PackagePlugin.Command] {
    guard !files.isEmpty else {
        // Don't lint anything if there are no Swift source files in this target
        return []
    }
    
    var arguments: [String] = [
        "lint",
        "--quiet",
        "--cache-path", cache.string,
        "--config", config.string
    ]
    
    arguments += files.map(\.string)
    
    return [
        .buildCommand(
            displayName: "Linting \(files.count) files in \(targetName)",
            executable: tool,
            arguments: arguments
        )
    ]
}
