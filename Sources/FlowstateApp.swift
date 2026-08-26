import SwiftUI

@main
struct FlowstateApp: App {
    @State private var settings: Settings
    @State private var engine: TimerEngine
    @State private var sounds: SoundPlayer
    @State private var music: MusicController

    init() {
        // Menu-bar accessory: no Dock icon, even during debug runs.
        NSApplication.shared.setActivationPolicy(.accessory)

        let s = Settings()
        let snd = SoundPlayer(settings: s)
        let mus = MusicController(settings: s)
        let e = TimerEngine(settings: s)
        e.onCue = { [snd] cue in snd.play(cue) }
        e.onSessionStart = { [mus] in mus.startSoundtrack() }   // once, on begin
        e.onSessionEnd = { [mus] in mus.stopSoundtrack() }      // once, on stop/finish

        _settings = State(initialValue: s)
        _sounds = State(initialValue: snd)
        _music = State(initialValue: mus)
        _engine = State(initialValue: e)
    }

    var body: some Scene {
        MenuBarExtra {
            RootView(engine: engine, settings: settings, sounds: sounds, music: music)
        } label: {
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
