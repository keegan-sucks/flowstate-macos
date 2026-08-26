import SwiftUI

/// The main menu-bar panel: round dots, phase, clock, transport, and a ⚙ that
/// opens the Edit view. Soundtrack buttons arrive with the music milestone.
struct PanelView: View {
    let engine: TimerEngine
    var edit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: edit) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Edit settings")
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
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .frame(width: 264)
    }
}

#Preview {
    PanelView(engine: TimerEngine(settings: Settings()), edit: {})
}
