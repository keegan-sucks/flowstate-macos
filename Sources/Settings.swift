import Foundation
import Observation

/// Persisted, observable app settings — the single source of truth for the timer,
/// menu-bar glyphs, sounds, and the Spotify soundtrack. Backed by UserDefaults;
/// @Observable so the menu bar and panel update live when a value changes.
@Observable
final class Settings {
    // MARK: Timer
    var workMinutes: Int        { didSet { d.set(workMinutes, forKey: "workMinutes") } }
    var shortBreakMinutes: Int  { didSet { d.set(shortBreakMinutes, forKey: "shortBreakMinutes") } }
    var cycles: Int             { didSet { d.set(cycles, forKey: "cycles") } }

    // MARK: Menu-bar glyphs
    var focusGlyph: String      { didSet { d.set(focusGlyph, forKey: "focusGlyph") } }
    var breakGlyph: String      { didSet { d.set(breakGlyph, forKey: "breakGlyph") } }

    // MARK: Sounds
    var soundsEnabled: Bool     { didSet { d.set(soundsEnabled, forKey: "soundsEnabled") } }
    var shortBreakSound: String { didSet { d.set(shortBreakSound, forKey: "shortBreakSound") } }
    var backToWorkSound: String { didSet { d.set(backToWorkSound, forKey: "backToWorkSound") } }
    var longBreakSound: String  { didSet { d.set(longBreakSound, forKey: "longBreakSound") } }
    var shortBreakVolume: Double { didSet { d.set(shortBreakVolume, forKey: "shortBreakVolume") } }
    var backToWorkVolume: Double { didSet { d.set(backToWorkVolume, forKey: "backToWorkVolume") } }
    var longBreakVolume: Double  { didSet { d.set(longBreakVolume, forKey: "longBreakVolume") } }

    // MARK: Soundtrack (spotify_player)
    var playSoundtrack: Bool    { didSet { d.set(playSoundtrack, forKey: "playSoundtrack") } }
    var spotifyVolume: Int      { didSet { d.set(spotifyVolume, forKey: "spotifyVolume") } }
    var alwaysShuffle: Bool     { didSet { d.set(alwaysShuffle, forKey: "alwaysShuffle") } }
    var activeSlot: Int         { didSet { d.set(activeSlot, forKey: "activeSlot") } }
    var slot1Label: String      { didSet { d.set(slot1Label, forKey: "slot1Label") } }
    var slot1Target: String     { didSet { d.set(slot1Target, forKey: "slot1Target") } }
    var slot2Label: String      { didSet { d.set(slot2Label, forKey: "slot2Label") } }
    var slot2Target: String     { didSet { d.set(slot2Target, forKey: "slot2Target") } }
    var slot3Label: String      { didSet { d.set(slot3Label, forKey: "slot3Label") } }
    var slot3Target: String     { didSet { d.set(slot3Target, forKey: "slot3Target") } }
    var spotifyWorkspace: Int   { didSet { d.set(spotifyWorkspace, forKey: "spotifyWorkspace") } }

    // MARK: Derived
    var slotLabels: [String]  { [slot1Label, slot2Label, slot3Label] }
    var slotTargets: [String] { [slot1Target, slot2Target, slot3Target] }
    var activeSlotTarget: String { slotTargets[clampedSlot] }
    var activeSlotLabel: String  { slotLabels[clampedSlot] }
    private var clampedSlot: Int { min(max(0, activeSlot), 2) }

    @ObservationIgnored private let d = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        func i(_ k: String, _ def: Int) -> Int { d.object(forKey: k) as? Int ?? def }
        func s(_ k: String, _ def: String) -> String { d.object(forKey: k) as? String ?? def }
        func b(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) as? Bool ?? def }
        func f(_ k: String, _ def: Double) -> Double { d.object(forKey: k) as? Double ?? def }

        // Property observers do not fire during init, so these load without re-writing.
        workMinutes       = i("workMinutes", 25)
        shortBreakMinutes = i("shortBreakMinutes", 5)
        cycles            = i("cycles", 4)
        focusGlyph        = s("focusGlyph", "⌖")
        breakGlyph        = s("breakGlyph", "☾")
        soundsEnabled     = b("soundsEnabled", true)
        shortBreakSound   = s("shortBreakSound", "Glass")
        backToWorkSound   = s("backToWorkSound", "Submarine")
        longBreakSound    = s("longBreakSound", "Hero")
        shortBreakVolume  = f("shortBreakVolume", 1.0)
        backToWorkVolume  = f("backToWorkVolume", 1.0)
        longBreakVolume   = f("longBreakVolume", 1.0)

        playSoundtrack    = b("playSoundtrack", true)
        spotifyVolume     = i("spotifyVolume", 35)
        alwaysShuffle     = b("alwaysShuffle", true)
        activeSlot        = i("activeSlot", 2)                    // 0-based → Liked
        slot1Label        = s("slot1Label", "Lofi")
        slot1Target       = s("slot1Target", "spotify:playlist:37i9dQZF1DWWQRwui0ExPn")
        slot2Label        = s("slot2Label", "Nature")
        slot2Target       = s("slot2Target", "spotify:playlist:37i9dQZF1DX4PP3DA4J0N8")
        slot3Label        = s("slot3Label", "Liked")
        slot3Target       = s("slot3Target", "liked")
        spotifyWorkspace  = i("spotifyWorkspace", 9)             // 0 = leave in place
    }
}
