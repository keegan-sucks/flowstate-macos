import AppKit

/// Plays the phase-boundary cues. macOS ships named alert sounds in
/// /System/Library/Sounds (Glass, Submarine, Hero, Ping, Tink, …) — no bundling
/// needed. Reads the chosen sound + per-cue volume from Settings.
final class SoundPlayer {
    private let settings: Settings

    init(settings: Settings) { self.settings = settings }

    /// Names offered in the settings picker (the classic macOS alert sounds).
    static let available = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
                            "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
                            "Submarine", "Tink"]

    func play(_ cue: PhaseCue) {
        guard settings.soundsEnabled else { return }
        switch cue {
        case .shortBreak: play(named: settings.shortBreakSound, volume: Float(settings.shortBreakVolume))
        case .backToWork: play(named: settings.backToWorkSound, volume: Float(settings.backToWorkVolume))
        case .longBreak:  play(named: settings.longBreakSound,  volume: Float(settings.longBreakVolume))
        }
    }

    /// Also used by the Edit view's preview buttons.
    func play(named name: String, volume: Float) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = max(0, min(1, volume))
        sound.stop()          // rewind if a shared instance is mid-play
        sound.play()
    }
}
