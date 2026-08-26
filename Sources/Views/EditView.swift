import SwiftUI

/// The ⚙ settings view: durations, cycles, menu-bar glyphs, and per-cue sounds
/// with a volume slider + preview. Bindings write straight through to persisted Settings.
struct EditView: View {
    @Bindable var settings: Settings
    let sounds: SoundPlayer
    var done: () -> Void

    private let focusGlyphs = ["⌖", "◉", "◎", "⧗", "✦", "◆", "●"]
    private let breakGlyphs = ["☾", "◐", "◑", "✦", "○", "◇", "◦"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timerSection
                    glyphSection
                    soundSection
                    soundtrackSection
                }
                .padding(18)
            }
            .frame(maxHeight: 700)
            Divider()
            footer
        }
        .frame(width: 460)
    }

    // MARK: Header / footer

    private var header: some View {
        HStack {
            Text("Settings").font(.headline)
            Spacer()
            Button("Done", action: done).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Button("Quit Flowstate") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Sections

    private var timerSection: some View {
        section("Timer") {
            stepperRow("Focus", value: $settings.workMinutes, range: 1...120, unit: "min")
            stepperRow("Short break", value: $settings.shortBreakMinutes, range: 1...60, unit: "min")
            stepperRow("Rounds before long break", value: $settings.cycles, range: 1...12, unit: nil)
        }
    }

    private var glyphSection: some View {
        section("Menu-bar glyphs") {
            glyphRow("Focus", selection: $settings.focusGlyph, options: focusGlyphs)
            glyphRow("Break", selection: $settings.breakGlyph, options: breakGlyphs)
        }
    }

    private var soundSection: some View {
        section("Sounds") {
            Toggle("Enable sounds", isOn: $settings.soundsEnabled)
            soundRow("Short break", sound: $settings.shortBreakSound, volume: $settings.shortBreakVolume)
            soundRow("Back to work", sound: $settings.backToWorkSound, volume: $settings.backToWorkVolume)
            soundRow("Long break", sound: $settings.longBreakSound, volume: $settings.longBreakVolume)
        }
        .opacity(settings.soundsEnabled ? 1 : 0.5)
    }

    private var soundtrackSection: some View {
        section("Soundtrack") {
            Toggle("Play soundtrack during focus", isOn: $settings.playSoundtrack)

            HStack {
                Text("Focus volume")
                Spacer()
                Text("\(settings.spotifyVolume)%").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(settings.spotifyVolume) },
                                  set: { settings.spotifyVolume = Int($0.rounded()) }),
                   in: 0...100)

            Toggle("Always shuffle", isOn: $settings.alwaysShuffle)

            slotEditor("Slot 1", label: $settings.slot1Label, target: $settings.slot1Target)
            slotEditor("Slot 2", label: $settings.slot2Label, target: $settings.slot2Target)
            slotEditor("Slot 3", label: $settings.slot3Label, target: $settings.slot3Target)

            Text("Target: a Spotify URI/URL, or “liked” for Liked Songs.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .opacity(settings.playSoundtrack ? 1 : 0.5)
    }

    private func slotEditor(_ title: String, label: Binding<String>, target: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("Label", text: label).textFieldStyle(.roundedBorder)
            TextField("liked or spotify:playlist:…", text: target).textFieldStyle(.roundedBorder)
        }
    }

    // MARK: Row builders

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(unit.map { "\(value.wrappedValue) \($0)" } ?? "\(value.wrappedValue)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range).labelsHidden()
        }
    }

    private func glyphRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 84)
        }
    }

    private func soundRow(_ label: String, sound: Binding<String>, volume: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).frame(width: 96, alignment: .leading)
                Picker("", selection: sound) {
                    ForEach(SoundPlayer.available, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                Button {
                    sounds.play(named: sound.wrappedValue, volume: Float(volume.wrappedValue))
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.plain)
                .help("Preview")
            }
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.secondary)
                Slider(value: volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .disabled(!settings.soundsEnabled)
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    let s = Settings()
    return EditView(settings: s, sounds: SoundPlayer(settings: s), done: {})
}
