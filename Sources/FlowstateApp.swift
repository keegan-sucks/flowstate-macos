import SwiftUI

@main
struct FlowstateApp: App {
    @State private var engine: TimerEngine

    init() {
        // Menu-bar accessory: no Dock icon, even during debug runs.
        NSApplication.shared.setActivationPolicy(.accessory)
        _engine = State(initialValue: TimerEngine())
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(engine: engine)
        } label: {
            // The headline feature: current round + clock, live in the menu bar.
            Text(engine.menuBarTitle)
        }
        .menuBarExtraStyle(.window)   // a real panel, not a dropdown menu
    }
}
