import SwiftUI

@main
struct FlowstateApp: App {
    @State private var engine: TimerEngine
    @State private var sounds: SoundPlayer

    init() {
        // Menu-bar accessory: no Dock icon, even during debug runs.
        NSApplication.shared.setActivationPolicy(.accessory)

        let s = SoundPlayer()
        let e = TimerEngine()
        e.onCue = { [s] cue in s.play(cue) }
        _engine = State(initialValue: e)
        _sounds = State(initialValue: s)
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(engine: engine)
        } label: {
            // Headline feature: focus glyph + round dots + clock, live in the menu bar.
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: Text {
        // Pure text — text glyphs render reliably in the menu bar; image labels don't.
        if engine.phase == .idle { return Text(engine.menuBarSymbol) }
        return Text("\(engine.menuBarSymbol)  \(engine.dotsText)  \(engine.clockText)")
    }
}
