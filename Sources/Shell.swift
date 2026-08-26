import Foundation

/// Tiny synchronous shell helper. Runs through a login shell so Homebrew paths
/// resolve, though callers use absolute paths anyway (a menu-bar app's PATH
/// usually lacks /opt/homebrew/bin). Never call on the main thread with commands
/// that block (device polling, sleeps) — MusicController dispatches to a queue.
enum Shell {
    @discardableResult
    static func run(_ script: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", script]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice   // discard; avoids a full-pipe deadlock
        do { try p.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
