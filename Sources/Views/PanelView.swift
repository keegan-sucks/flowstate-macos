import SwiftUI

/// The main menu-bar panel. Milestone 1 is a calm placeholder; the timer,
/// round dots, transport, and soundtrack buttons arrive in later milestones.
struct PanelView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Flowstate")
                .font(.headline)

            Text("🍅")
                .font(.system(size: 44))

            Text("Timer arrives in Milestone 2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 260)
    }
}

#Preview {
    PanelView()
}
