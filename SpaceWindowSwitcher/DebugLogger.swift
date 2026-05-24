import Foundation

enum DebugLogger {
    private static let fileURL = URL(fileURLWithPath: "/tmp/SpaceWindowSwitcher-debug.log")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                return
            }

            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            handle.write(data)
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
