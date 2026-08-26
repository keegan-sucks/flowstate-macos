import Foundation
import Observation

/// The Pomodoro state machine. All live state (phase, round, seconds remaining)
/// lives here; the menu-bar title and panel are pure views of it.
///
/// Flow (mirrors the original Flowstate, per the brief's §2):
///   focus 1 → short → focus 2 → short → … → focus `cycles` → long break → done.
/// After the `cycles`-th focus block the break is the *long* one; when it ends the
/// session finishes and everything resets to idle.
@Observable
final class TimerEngine {

    enum Phase {
        case idle, focus, shortBreak, longBreak
    }

    // MARK: - Configuration
    // Defaults here; Milestone 3 wires these to persisted Settings.
    var workMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var cycles = 4

    // MARK: - Live state
    private(set) var phase: Phase = .idle
    private(set) var round = 1          // 1-based index of the current focus block
    private(set) var remaining = 25 * 60
    private(set) var isRunning = false

    private var completedFocusBlocks = 0
    private var ticker: Timer?

    init() {
        remaining = duration(for: .focus)
    }

    // MARK: - Derived display

    /// The headline feature: the current round + clock, live in the menu bar.
    var menuBarTitle: String {
        switch phase {
        case .idle:       return "🍅"
        case .focus:      return "🍅 \(round)/\(cycles) · \(clockText)"
        case .shortBreak: return "☕ \(round)/\(cycles) · \(clockText)"
        case .longBreak:  return "🌙 · \(clockText)"
        }
    }

    var clockText: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var phaseLabel: String {
        switch phase {
        case .idle:       return "Ready"
        case .focus:      return "Focus \(round) of \(cycles)"
        case .shortBreak: return "Short break"
        case .longBreak:  return "Long break"
        }
    }

    /// Filled/empty round dots, e.g. `●●○○`.
    var dotsText: String {
        let filled = min(max(0, filledDots), cycles)
        return String(repeating: "●", count: filled)
             + String(repeating: "○", count: cycles - filled)
    }

    private var filledDots: Int {
        switch phase {
        case .idle:                   return 0
        case .focus:                  return round               // current block counts as lit
        case .shortBreak, .longBreak: return completedFocusBlocks
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
        // The music side-effect intentionally stays engaged while paused (M4).
    }

    func toggle() { isRunning ? pause() : start() }

    func reset() {
        stopTicker()
        isRunning = false
        phase = .idle
        round = 1
        completedFocusBlocks = 0
        remaining = duration(for: .focus)
        // M4: stop music + restore volume once, here.
    }

    /// Manual advance. On a *focus* skip the block is NOT earned (matches the original).
    func skip() {
        switch phase {
        case .idle:       return
        case .focus:      enter(.shortBreak)
        case .shortBreak: round = completedFocusBlocks + 1; enter(.focus)
        case .longBreak:  finishSession()
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
            enter(completedFocusBlocks >= cycles ? .longBreak : .shortBreak)
            // M6: playPhaseBell()
        case .shortBreak:
            round = completedFocusBlocks + 1
            enter(.focus)
            // M6: playPhaseBell()
        case .longBreak:
            finishSession()   // M6: playCompletionSequence()
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
        // M4: fire the music side-effect once, here.
    }

    private func resume() {
        isRunning = true
        startTicker()
    }

    /// Enter a new phase, carrying the running state (continuous auto-advance).
    private func enter(_ newPhase: Phase) {
        phase = newPhase
        remaining = duration(for: newPhase)
        // isRunning is deliberately unchanged; the existing ticker keeps counting.
    }

    private func finishSession() {
        stopTicker()
        isRunning = false
        phase = .idle
        round = 1
        completedFocusBlocks = 0
        remaining = duration(for: .focus)
        // M4: stop music + restore volume.  M6: 3-bell completion chime.
    }

    private func duration(for phase: Phase) -> Int {
        switch phase {
        case .idle, .focus: return workMinutes * 60
        case .shortBreak:   return shortBreakMinutes * 60
        case .longBreak:    return longBreakMinutes * 60
        }
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common so the countdown keeps running while the panel/menu is open.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning else { return }
        remaining -= 1
        if remaining <= 0 {
            completeCurrentPhase()
        }
    }
}
