import Foundation

// True when running inside an Xcode SwiftUI #Preview.
enum AppEnv {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
