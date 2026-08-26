import Foundation
import Observation

/// Distinct audible cues at phase boundaries. The engine only *signals* these;
/// SoundPlayer (AppKit) decides what actually plays, so the engine stays testable.
enum PhaseCue: Equatable {
    case shortBreak   // a focus block ended → time for a short break
    case backToWork   // a short break ended → get back to work
    case longBreak    // the final focus block ended → long break (session ends here)
}

/// The Pomodoro state machine. All live state lives here; the menu-bar label and
/// panel are pure views of it.
///
/// Flow: focus 1 → short → focus 2 → short → … → focus `cycles`, then the session
/// ends with a long-break *cue* (no timed long break — you rest as long as you like
/// and start again when ready).
@Observable
final class TimerEngine {

    enum Phase: Equatable {
        case idle, focus, shortBreak
    }

    // MARK: - Configuration (Settings wires these next milestone)
    var workMinutes = 25
    var shortBreakMinutes = 5
    var cycles = 4

    /// Menu-bar glyphs (SF Symbols — monochrome in the menu bar). Configurable later.
    var focusSymbol = "target"
    var breakSymbol = "cup.and.saucer.fill"

    // MARK: - Live state
    private(set) var phase: Phase = .idle
    private(set) var round = 1
    private(set) var remaining = 25 * 60
    private(set) var isRunning = false

    /// Fired at each phase boundary so the app can play a sound. nil in tests.
    var onCue: ((PhaseCue) -> Void)?

    private var completedFocusBlocks = 0
    private var ticker: Timer?

    init() { remaining = duration(for: .focus) }

    // MARK: - Derived display

    var clockText: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var phaseLabel: String {
        switch phase {
        case .idle:       return "Ready"
        case .focus:      return "Focus \(round) of \(cycles)"
        case .shortBreak: return "Short break"
        }
    }

    /// SF Symbol shown in the menu bar for the current phase.
    var menuBarSymbol: String {
        switch phase {
        case .idle, .focus: return focusSymbol
        case .shortBreak:   return breakSymbol
        }
    }

    /// Filled/empty round dots for the menu bar and panel, e.g. `●●○○`.
    var dotsText: String {
        let filled = min(max(0, filledDots), cycles)
        return String(repeating: "●", count: filled)
             + String(repeating: "○", count: cycles - filled)
    }

    private var filledDots: Int {
        switch phase {
        case .idle:       return 0
        case .focus:      return round               // current block counts as lit
        case .shortBreak: return completedFocusBlocks
        }
    }

    // MARK: - Intents (mirror the original's Space / R / S controls)

    func start() {
        switch phase {
        case .idle:            beginSession()
        default: if !isRunning { resume() }
        }
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        stopTicker()
        // Music side-effect intentionally stays engaged while paused (M5).
    }

    func toggle() { isRunning ? pause() : start() }

    func reset() {
        stopTicker()
        isRunning = false
        phase = .idle
        round = 1
        completedFocusBlocks = 0
        remaining = duration(for: .focus)
        // M5: stop music + restore volume.
    }

    /// Manual advance. A *focus* skip does NOT earn the block (matches the original).
    func skip() {
        switch phase {
        case .idle:       return
        case .focus:      enter(.shortBreak); onCue?(.shortBreak)
        case .shortBreak: round = completedFocusBlocks + 1; enter(.focus); onCue?(.backToWork)
        }
    }

    // MARK: - Transitions

    /// Called when the current phase's clock reaches zero. Internal so the state
    /// machine can be exercised deterministically in tests.
    func completeCurrentPhase() {
        switch phase {
        case .idle:
            return
        case .focus:
            completedFocusBlocks = min(cycles, completedFocusBlocks + 1)
            if completedFocusBlocks >= cycles {
                finishSession()          // no timed long break — just the cue
                onCue?(.longBreak)
            } else {
                enter(.shortBreak)
                onCue?(.shortBreak)
            }
        case .shortBreak:
            round = completedFocusBlocks + 1
            enter(.focus)
            onCue?(.backToWork)
        }
    }

    // MARK: - Lifecycle helpers

    private func beginSession() {
        phase = .focus
        round = 1
        completedFocusBlocks = 0
        remaining = duration(for: .focus)
        isRunning = true
        startTicker()
        // M5: fire the music side-effect once, here.
    }

    private func resume() { isRunning = true; startTicker() }

    private func enter(_ newPhase: Phase) {
        phase = newPhase
        remaining = duration(for: newPhase)
        // isRunning unchanged; the existing ticker keeps counting (continuous advance).
    }

    private func finishSession() {
        stopTicker()
        isRunning = false
        phase = .idle
        round = 1
        completedFocusBlocks = 0
        remaining = duration(for: .focus)
    }

    private func duration(for phase: Phase) -> Int {
        switch phase {
        case .idle, .focus: return workMinutes * 60
        case .shortBreak:   return shortBreakMinutes * 60
        }
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        // .common so the countdown keeps running while the panel/menu is open.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() { ticker?.invalidate(); ticker = nil }

    private func tick() {
        guard isRunning else { return }
        remaining -= 1
        if remaining <= 0 { completeCurrentPhase() }
    }
}
