import Foundation

private let kIsUnitTesting: String = "UNIT-TESTING"
private let kIsUITesting: String = "UI-TESTING"

/// An enum used to specify the purpose of running the app
///
/// Be sure to add "UNIT-TESTING" to Arguements Passed on Launch of the Test phase of your Build Scheme(s)
public enum BuildConfig {
    case release
    case debug
    case unitTest
    case uiTest

    /// What type of build are we currently running?
    public static var current: Self {
        if hasArgument(kIsUITesting) {
            return .uiTest
        } else if hasArgument(kIsUnitTesting) {
            return .unitTest
        }

        #if DEBUG
            return .debug
        #else
            return .release
        #endif
    }

    /// A convenient way to check if we are currently running the app for testing purposes
    public static var isTesting: Bool {
        switch current {
        case .unitTest, .uiTest:
            return true
        default:
            return false
        }
    }

    private static func hasArgument(_ key: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(key)
    }
}
