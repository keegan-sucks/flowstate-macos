import SwiftUI

/// The main menu-bar panel: round dots, phase, clock, transport, soundtrack slots,
/// and a ⚙ that opens the Edit view. Keyboard: Space toggle · R reset · S skip · E edit.
struct PanelView: View {
    let engine: TimerEngine
    let settings: Settings
    let music: MusicController
    var edit: () -> Void

    @State private var justLiked = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button(action: edit) { Image(systemName: "gearshape") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("e", modifiers: [])
                    .help("Edit settings (E)")
            }

            // Round dots — reads at a glance: ●●○○
            Text(engine.dotsText)
                .font(.system(size: 14))
                .tracking(6)
                .foregroundStyle(.primary)

            VStack(spacing: 3) {
                Text(engine.phaseLabel)
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(engine.clockText)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                Button(action: engine.reset) {
                    Image(systemName: "arrow.counterclockwise").frame(width: 30, height: 22)
                }
                .keyboardShortcut("r", modifiers: [])
                .help("Reset (R)")

                Button(action: engine.toggle) {
                    Label(engine.isRunning ? "Pause" : "Start",
                          systemImage: engine.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                .help("Start / Pause (Space)")

                Button(action: engine.skip) {
                    Image(systemName: "forward.fill").frame(width: 30, height: 22)
                }
                .keyboardShortcut("s", modifiers: [])
                .help("Skip (S)")
            }

            soundtrackRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .frame(width: 268)
    }

    /// Soundtrack slots (tap to select; switch live during focus) + a skip-song button.
    private var soundtrackRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    settings.activeSlot = i
                    if engine.phase == .focus { music.switchSoundtrack() }
                } label: {
                    Text(settings.slotLabels[i])
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(settings.activeSlot == i ? .accentColor : .secondary)
            }

            Button {
                music.likeCurrentSong()
                justLiked = true
                Task { try? await Task.sleep(for: .seconds(1.2)); justLiked = false }
            } label: {
                Image(systemName: justLiked ? "heart.fill" : "heart")
                    .foregroundStyle(justLiked ? .pink : .primary)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("l", modifiers: [])
            .help("Like current song (L)")

            Button(action: music.nextTrack) {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("n", modifiers: [])
            .help("Skip song (N)")
        }
        .opacity(settings.playSoundtrack ? 1 : 0.4)
    }
}
