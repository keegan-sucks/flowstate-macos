import SwiftUI

/// The main menu-bar panel: round dots, phase, clock, and transport.
/// Soundtrack buttons and the ⚙ Edit view arrive in later milestones.
struct PanelView: View {
    let engine: TimerEngine

    var body: some View {
        VStack(spacing: 16) {
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
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 28, height: 20)
                }
                .help("Reset")

                Button(action: engine.toggle) {
                    Label(engine.isRunning ? "Pause" : "Start",
                          systemImage: engine.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: engine.skip) {
                    Image(systemName: "forward.fill")
                        .frame(width: 28, height: 20)
                }
                .help("Skip")
            }
        }
        .padding(18)
        .frame(width: 264)
    }
}

#Preview {
    PanelView(engine: TimerEngine())
}
