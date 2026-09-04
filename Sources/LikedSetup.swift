import AppKit

/// Launches the bundled, interactive Liked-Songs setup script in Terminal.
///
/// The `scripts/` folder is bundled into the app (Contents/Resources/scripts), so a
/// Homebrew-only user — who never clones the repo — can still run the guided setup
/// straight from the app. The setup itself is interactive (prompts + a browser OAuth),
/// which is exactly what Terminal is for; playback never touches Terminal.
enum LikedSetup {
    /// Path to the bundled setup script, if present.
    static var scriptPath: String? {
        Bundle.main.resourceURL?
            .appendingPathComponent("scripts/setup_liked.sh").path
    }

    /// Open Terminal and run the guided setup. Returns false if the script is missing.
    @discardableResult
    static func launch() -> Bool {
        guard let path = scriptPath,
              FileManager.default.fileExists(atPath: path) else { return false }

        // Escape the path for an AppleScript string literal; `quoted form of` then makes
        // it shell-safe for `do script`. `zsh <path>` runs it without needing +x.
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            do script "zsh " & quoted form of "\(escaped)"
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        return err == nil
    }
}
