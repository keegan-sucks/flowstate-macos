import SwiftUI

/// Swaps between the timer panel and the ⚙ Edit view inside the menu-bar window.
struct RootView: View {
    let engine: TimerEngine
    let settings: Settings
    let sounds: SoundPlayer
    let music: MusicController

    @State private var editing = false

    var body: some View {
        if editing {
            EditView(settings: settings, sounds: sounds) { editing = false }
        } else {
            PanelView(engine: engine, settings: settings, music: music) { editing = true }
        }
    }
}
