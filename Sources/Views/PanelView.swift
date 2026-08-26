import SwiftUI

/// The main menu-bar panel: round dots, phase, clock, transport, soundtrack slots,
/// and a ⚙ that opens the Settings window.
struct PanelView: View {
    let engine: TimerEngine
    let settings: Settings
    let music: MusicController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    openSettings()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Settings")
            }

            // Round dots — reads at a glance: ●●○○
            Text(engine.dotsText)
                .font(.system(size: 13))
                .tracking(5)
                .foregroundStyle(.primary)

            VStack(spacing: 2) {
                Text(engine.phaseLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(engine.clockText)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                Button(action: engine.reset) {
                    Image(systemName: "arrow.counterclockwise").frame(width: 28, height: 20)
                }
                .help("Reset")

                Button(action: engine.toggle) {
                    Label(engine.isRunning ? "Pause" : "Start",
                          systemImage: engine.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: engine.skip) {
                    Image(systemName: "forward.fill").frame(width: 28, height: 20)
                }
                .help("Skip")
            }

            soundtrackRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .frame(width: 264)
    }

    /// Soundtrack slots — tap to select (and switch live if a focus block is playing).
    private var soundtrackRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    settings.activeSlot = i
                    // Switch live only during focus — during a break the music is paused,
                    // so a tap just sets the slot for the next focus block.
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
        }
        .opacity(settings.playSoundtrack ? 1 : 0.4)
    }
}
