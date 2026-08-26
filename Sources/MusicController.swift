import Foundation

/// Drives spotify_player to play the focus soundtrack (incl. Liked-Songs shuffle).
///
/// Lifecycle (per Keegan's spec):
///  • session start → launch/connect, `start liked --random` (random first track,
///    verified on 0.24.1) + ensure shuffle + duck volume
///  • focus → break → pause;   break → focus → resume
///  • end of cycle (or reset) → pause + restore volume; the player is LEFT open
/// All work runs off the main thread on a serial queue.
final class MusicController {
    private let settings: Settings
    private let sp = "/opt/homebrew/bin/spotify_player"
    private let device = "spotify-player"
    private let queue = DispatchQueue(label: "com.keegan.flowstate.music")
    private var savedVolume: Int?

    init(settings: Settings) { self.settings = settings }

    // MARK: Public — called on the main thread; work is dispatched.

    func startSoundtrack() {
        guard settings.playSoundtrack else { return }
        queue.async { [weak self] in self?.engage() }
    }

    /// Switch to the currently-selected slot while a session is already playing.
    func switchSoundtrack() {
        guard settings.playSoundtrack else { return }
        queue.async { [weak self] in self?.engage() }
    }

    func pauseForBreak() {
        guard settings.playSoundtrack else { return }
        queue.async { [weak self] in guard let self else { return }
            _ = Shell.run("\(self.sp) playback pause")
        }
    }

    func resumeFromBreak() {
        guard settings.playSoundtrack else { return }
        queue.async { [weak self] in guard let self else { return }
            _ = Shell.run("\(self.sp) playback play")
        }
    }

    /// End of cycle / reset — pause the music and restore the pre-session volume,
    /// but LEAVE the player (and its terminal window) open.
    func stopSoundtrack() {
        queue.async { [weak self] in
            guard let self else { return }
            if let v = self.savedVolume { _ = Shell.run("\(self.sp) playback volume \(v)") }
            _ = Shell.run("\(self.sp) playback pause")
            self.savedVolume = nil
        }
    }

    // MARK: Sequence

    private func engage() {
        ensurePlayerRunning()
        guard waitForDevice() else { return }
        _ = Shell.run("\(sp) connect --name \(device)")
        if savedVolume == nil { savedVolume = currentVolume() ?? 100 }
        startTarget()
        if settings.alwaysShuffle { ensureShuffleOn() }
        _ = Shell.run("\(sp) playback volume \(settings.spotifyVolume)")
    }

    private func ensurePlayerRunning() {
        let running = !Shell.run("/usr/bin/pgrep -x spotify_player")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !running else { return }
        // Launch the TUI in a terminal (Milestone 5 moves it to the configured workspace).
        _ = Shell.run(#"osascript -e 'tell application "Terminal" to do script "exec /opt/homebrew/bin/spotify_player"'"#)
    }

    private func waitForDevice() -> Bool {
        for _ in 0..<60 {
            if Shell.run("\(sp) get key devices").contains("\"name\":\"\(device)\"") { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    private func startTarget() {
        let target = settings.activeSlotTarget
        if isLiked(target) {
            // `--random` picks a RANDOM starting track (verified on 0.24.1) — no fixed
            // first song. Shuffle is ensured separately for continued playback.
            _ = Shell.run("\(sp) playback start liked --random")
        } else if let ctx = parseContext(target) {
            let shuffle = settings.alwaysShuffle ? " --shuffle" : ""
            _ = Shell.run("\(sp) playback start context --id \(ctx.id)\(shuffle) \(ctx.type)")
        }
        Thread.sleep(forTimeInterval: 1.0)
        if !isPlaying() { _ = Shell.run("\(sp) playback play") }
    }

    private func ensureShuffleOn() {
        // Shuffle is a toggle — only fire it if currently off.
        if shuffleState() == false { _ = Shell.run("\(sp) playback shuffle") }
    }

    // MARK: JSON reads (parsed in Swift — no jq dependency)

    private func playbackJSON() -> [String: Any]? {
        let out = Shell.run("\(sp) get key playback")
        guard let data = out.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }
    private func isPlaying() -> Bool { playbackJSON()?["is_playing"] as? Bool ?? false }
    private func shuffleState() -> Bool? { playbackJSON()?["shuffle_state"] as? Bool }
    private func currentVolume() -> Int? {
        (playbackJSON()?["device"] as? [String: Any])?["volume_percent"] as? Int
    }

    // MARK: Target parsing (spotify:TYPE:ID | open.spotify.com/…/TYPE/ID | liked | bare id)

    private func isLiked(_ s: String) -> Bool {
        let l = s.lowercased()
        return l == "liked" || l == "likes" || l.contains(":collection")
    }

    private func parseContext(_ raw: String) -> (type: String, id: String)? {
        let r = raw.trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty else { return nil }
        let kinds = ["playlist", "album", "artist"]
        if r.hasPrefix("spotify:") {
            let parts = r.split(separator: ":").map(String.init)
            if parts.count >= 3, kinds.contains(parts[1]) { return (parts[1], parts[2]) }
        }
        if r.contains("open.spotify.com") {
            let comps = r.components(separatedBy: "/")
            if let idx = comps.firstIndex(where: { kinds.contains($0) }), idx + 1 < comps.count {
                var id = comps[idx + 1]
                if let q = id.firstIndex(of: "?") { id = String(id[..<q]) }
                return (comps[idx], id)
            }
        }
        return ("playlist", r)   // bare id → assume a playlist
    }
}
