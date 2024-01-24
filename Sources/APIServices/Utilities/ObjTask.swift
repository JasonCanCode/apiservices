import Foundation

/// An object for providing an ObjC class with a way to cancel a running `Task`.
public class ObjTask<T>: NSObject, CancelableTask {
    private var actualTask: Task<Void, Error>?
    private let taskHandler: () async throws -> T
    private let completionHandler: (T?, Error?) -> Void
    
    /// Create a ``CancelableTask`` object to execute an asynchronous block at a later time.
    /// - Parameters:
    ///   - taskHandler: A failable asynchronous block of code to be executed when needed.
    ///   - completionHandler: A block of code to run once the provided task block has finished. This **does not** execute of the task is cancelled before completion. 
    public init(taskHandler: @escaping () async throws -> T, completionHandler: ((T?, Error?) -> Void)? = nil) {
        self.taskHandler = taskHandler
        self.completionHandler = completionHandler ?? { _, _ in }
        super.init()
    }
    
    /// Execute the failable asynchronous block of code provided on init.
    @objc public func resume() {
        self.actualTask = Task {
            do {
                let value = try await taskHandler()
                try Task.checkCancellation()
                await MainActor.run { completionHandler(value, nil) }
            } catch {
                await MainActor.run {
                    Configuration.errorLogger.logError(error)
                    completionHandler(nil, error)
                }
            }
        }
    }
    
    /// Stop the current in-flight `Task` if it has not already completed. If called before completion, the completionHandler will never run.
    @objc public func cancel() {
        actualTask?.cancel()
        actualTask = nil
    }
}
