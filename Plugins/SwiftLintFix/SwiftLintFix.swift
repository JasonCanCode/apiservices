import Foundation
import PackagePlugin

@main
struct SwiftLintFix: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "swiftlint")
        
        let targetsToProcess = context.package.targets(ofType: SwiftSourceModuleTarget.self)
        
        // The target selector has issues and some targets aren't present so just always lint everything I guess
//        var targetsToProcess = context.package.targets(ofType: SwiftSourceModuleTarget.self)
//
//        var argExtractor = ArgumentExtractor(arguments)
//        let selectedTargets = argExtractor.extractOption(named: "target")
//
//        if !selectedTargets.isEmpty {
//            targetsToProcess = targetsToProcess.filter { target in
//                selectedTargets.contains(target.name)
//            }
//        }
        
        let config = context.package.directory.appending(".swiftlint.yml")
        let cache = context.pluginWorkDirectory.appending("cache")
        
        for target in targetsToProcess {
            let inputFilePaths = target.sourceFiles(withSuffix: "swift").map(\.path)
            try fix(targetName: target.name, tool: tool.path, files: inputFilePaths, config: config, cache: cache)
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLintFix: XcodeCommandPlugin {
    func performCommand(context: XcodeProjectPlugin.XcodePluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "swiftlint")
        
        var targetsToProcess = context.xcodeProject.targets
        
        var argExtractor = ArgumentExtractor(arguments)
        let selectedTargets = argExtractor.extractOption(named: "target")
        
        if !selectedTargets.isEmpty {
            targetsToProcess = targetsToProcess.filter { target in
                selectedTargets.contains(target.displayName)
            }
        }
        
        let config = context.xcodeProject.directory.appending(".swiftlint.yml")
        let cache = context.pluginWorkDirectory.appending("cache")
        
        for target in targetsToProcess {
            let swiftFilePaths = target
                .inputFiles
                .filter { $0.type == .source && $0.path.extension == "swift" }
                .map(\.path)
            
            try fix(targetName: target.displayName, tool: tool.path, files: swiftFilePaths, config: config, cache: cache)
        }
    }
}
#endif

private func fix(targetName: String, tool: Path, files: [Path], config: Path, cache: Path) throws {
    guard !files.isEmpty else {
        // Don't lint anything if there are no Swift source files in this target
        return
    }
    
    print("Fixing \(files.count) files in \(targetName)")
    
    var arguments: [String] = [
        "--fix",
        "--quiet",
        "--cache-path", cache.string,
        "--config", config.string
    ]
    
    arguments += files.map(\.string)
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool.string)
    process.arguments = arguments
    
    try process.run()
    process.waitUntilExit()
    
    if process.terminationReason != .exit || process.terminationStatus != 0 {
        let problem = "\(process.terminationReason):\(process.terminationStatus)"
        Diagnostics.error("lint invocation failed: \(problem)")
    }
}
