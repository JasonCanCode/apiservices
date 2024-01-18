import Foundation

/// An abstraction of a task that can be started with ``resume()`` and terminated prematurely with ``cancel()``
@objc public protocol CancelableTask: AnyObject {
    /// Call this method to start the network request
    func resume()
    /// Call this method to cancel the network request if if has not yet completed.
    func cancel()
}
