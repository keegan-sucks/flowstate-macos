import ServiceManagement

/// Wraps "launch at login" via SMAppService (macOS 13+). The system status is the
/// source of truth, so there's nothing to persist ourselves.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register/unregister the app as a login item. Returns whether the actual status
    /// now matches the request (registration can fail for an unsigned/ad-hoc build not
    /// in /Applications).
    @discardableResult
    static func setEnabled(_ on: Bool) -> Bool {
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            return false
        }
        return isEnabled == on
    }
}
