import SwiftUI

@main
struct FlowstateApp: App {
    @State private var settings: Settings
    @State private var engine: TimerEngine
    @State private var sounds: SoundPlayer

    init() {
        // Menu-bar accessory: no Dock icon, even during debug runs.
        NSApplication.shared.setActivationPolicy(.accessory)

        let s = Settings()
        let snd = SoundPlayer(settings: s)
        let e = TimerEngine(settings: s)
        e.onCue = { [snd] cue in snd.play(cue) }

        _settings = State(initialValue: s)
        _sounds = State(initialValue: snd)
        _engine = State(initialValue: e)
    }

    var body: some Scene {
        MenuBarExtra {
            RootView(engine: engine, settings: settings, sounds: sounds)
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
