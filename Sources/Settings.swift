import Foundation
import Observation

/// Persisted, observable app settings — the single source of truth for the timer,
/// menu-bar glyphs, and sounds. Backed by UserDefaults; @Observable so the menu bar
/// and panel update live when a value changes in the Edit view.
@Observable
final class Settings {
    var workMinutes: Int        { didSet { d.set(workMinutes, forKey: "workMinutes") } }
    var shortBreakMinutes: Int  { didSet { d.set(shortBreakMinutes, forKey: "shortBreakMinutes") } }
    var cycles: Int             { didSet { d.set(cycles, forKey: "cycles") } }

    var focusGlyph: String      { didSet { d.set(focusGlyph, forKey: "focusGlyph") } }
    var breakGlyph: String      { didSet { d.set(breakGlyph, forKey: "breakGlyph") } }

    var soundsEnabled: Bool     { didSet { d.set(soundsEnabled, forKey: "soundsEnabled") } }
    var shortBreakSound: String { didSet { d.set(shortBreakSound, forKey: "shortBreakSound") } }
    var backToWorkSound: String { didSet { d.set(backToWorkSound, forKey: "backToWorkSound") } }
    var longBreakSound: String  { didSet { d.set(longBreakSound, forKey: "longBreakSound") } }
    var shortBreakVolume: Double { didSet { d.set(shortBreakVolume, forKey: "shortBreakVolume") } }
    var backToWorkVolume: Double { didSet { d.set(backToWorkVolume, forKey: "backToWorkVolume") } }
    var longBreakVolume: Double  { didSet { d.set(longBreakVolume, forKey: "longBreakVolume") } }

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
    }
}
