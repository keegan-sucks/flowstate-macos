import AppKit

/// Plays the phase-boundary cues. macOS ships named alert sounds in
/// /System/Library/Sounds (Glass, Submarine, Hero, Ping, Tink, …) — no bundling
/// needed. The Edit view will expose a sound choice + volume slider per cue.
final class SoundPlayer {
    var enabled = true

    // Defaults (overridden by Settings next milestone).
    var shortBreakSound = "Glass"
    var backToWorkSound = "Submarine"
    var longBreakSound  = "Hero"

    var shortBreakVolume: Float = 1.0
    var backToWorkVolume: Float = 1.0
    var longBreakVolume:  Float = 1.0

    /// Names available in the settings picker (the classic macOS alert sounds).
    static let available = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
                            "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
                            "Submarine", "Tink"]

    func play(_ cue: PhaseCue) {
        guard enabled else { return }
        switch cue {
        case .shortBreak: play(named: shortBreakSound, volume: shortBreakVolume)
        case .backToWork: play(named: backToWorkSound, volume: backToWorkVolume)
        case .longBreak:  play(named: longBreakSound,  volume: longBreakVolume)
        }
    }

    /// Also used by the settings preview buttons.
    func play(named name: String, volume: Float) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = max(0, min(1, volume))
        sound.stop()          // rewind if a shared instance is mid-play
        sound.play()
    }
}
