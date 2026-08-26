import SwiftUI

@main
struct FlowstateApp: App {
    init() {
        // Menu-bar accessory: no Dock icon, even during debug runs.
        // (LSUIElement in Info.plist covers release; this covers everything.)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
        } label: {
            // Milestone 1: static tomato. The live round/clock title lands in Milestone 2.
            Text("🍅")
        }
        .menuBarExtraStyle(.window)   // a real panel, not a dropdown menu
    }
}
