import Foundation

/// Drives spotify_player to play the focus soundtrack (incl. Liked-Songs shuffle).
///
/// Lifecycle: session start → launch/connect + start (Liked `--random`, or a context
/// via muted shuffle-and-skip) + duck volume; focus↔break → pause/resume; end → pause
/// + restore volume (player left open). New player windows are moved to the configured
/// AeroSpace workspace.
///
/// Concurrency: public methods are called on the main thread. They snapshot the needed
/// Settings values there (Settings is @Observable and mutated on the main thread, so it
/// must NOT be read from the background queue), then dispatch work to a serial queue.
/// A generation counter lets a pause/stop cancel an in-flight `engage()` promptly, and
/// every start path leaves the device at the focus volume even when it bails early.
final class MusicController {
    private let settings: Settings
    private let sp = "/opt/homebrew/bin/spotify_player"
    private let aerospace = "/opt/homebrew/bin/aerospace"
    private let device = "spotify-player"
    private let queue = DispatchQueue(label: "com.keegan.flowstate.music")

    private var savedVolume: Int?            // queue-only
    private let genLock = NSLock()
    private var generation = 0               // guarded by genLock

    /// Immutable snapshot of the Settings the background work needs.
    private struct Config {
        let alwaysShuffle: Bool
        let volume: Int
        let workspace: Int
        let target: String
    }

    init(settings: Settings) { self.settings = settings }

    // MARK: Public (main thread) — snapshot settings, then dispatch.

    func startSoundtrack() {
        guard settings.playSoundtrack else { return }
        let cfg = snapshot(); let gen = bumpGeneration()
        queue.async { [weak self] in self?.engage(cfg, gen) }
    }

    /// Switch to the currently-selected slot while a session is already playing.
    func switchSoundtrack() {
        guard settings.playSoundtrack else { return }
        let cfg = snapshot(); let gen = bumpGeneration()
        queue.async { [weak self] in self?.engage(cfg, gen) }
    }

    func pauseForBreak() {
        guard settings.playSoundtrack else { return }
        _ = bumpGeneration()                 // cancel any in-flight engage()
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

    /// End of cycle / reset — pause + restore the pre-session volume; leave the player open.
    func stopSoundtrack() {
        _ = bumpGeneration()                 // cancel any in-flight engage()
        queue.async { [weak self] in guard let self else { return }
            if let v = self.savedVolume { _ = Shell.run("\(self.sp) playback volume \(v)") }
            _ = Shell.run("\(self.sp) playback pause")
            self.savedVolume = nil
        }
    }

    // MARK: Snapshot + generation

    private func snapshot() -> Config {
        Config(alwaysShuffle: settings.alwaysShuffle,
               volume: settings.spotifyVolume,
               workspace: settings.spotifyWorkspace,
               target: settings.activeSlotTarget)
    }
    private func bumpGeneration() -> Int {
        genLock.lock(); generation += 1; let g = generation; genLock.unlock(); return g
    }
    private func isCancelled(_ g: Int) -> Bool {
        genLock.lock(); let c = generation != g; genLock.unlock(); return c
    }

    // MARK: Sequence (serial queue)

    private func engage(_ cfg: Config, _ gen: Int) {
        ensurePlayerRunning(workspace: cfg.workspace, gen)
        guard !isCancelled(gen), waitForDevice(gen) else { return }
        _ = Shell.run("\(sp) connect --name \(device)")
        if savedVolume == nil { savedVolume = currentVolume() ?? 100 }
        if isCancelled(gen) { return }

        if isLiked(cfg.target) {
            startLiked(cfg, gen)
        } else if let ctx = parseContext(cfg.target) {
            startContext(ctx, cfg, gen)
        }
    }

    /// Liked Songs: `--random` starts on a random track directly. Volume is ducked
    /// before playback so an early cancel never leaves it un-ducked.
    private func startLiked(_ cfg: Config, _ gen: Int) {
        _ = Shell.run("\(sp) playback volume \(cfg.volume)")
        _ = Shell.run("\(sp) playback start liked --random")
        Thread.sleep(forTimeInterval: 0.9)
        if isCancelled(gen) { return }
        if !isPlaying() { _ = Shell.run("\(sp) playback play") }
        if cfg.alwaysShuffle { ensureShuffleOn() }
    }

    /// Contexts always begin at track 1 and have no `--random`. When shuffling, start
    /// MUTED, enable shuffle, skip a few tracks to a random position, then unmute — a
    /// varied first track with no audible blips. Commands are paced ~0.7s apart
    /// (spotify_player drops them if fired faster). The final unmute always runs, so a
    /// mid-sequence cancel never strands the device at volume 0.
    private func startContext(_ ctx: (type: String, id: String), _ cfg: Config, _ gen: Int) {
        guard cfg.alwaysShuffle else {
            _ = Shell.run("\(sp) playback start context --id \(ctx.id) \(ctx.type)")
            Thread.sleep(forTimeInterval: 0.9)
            if !isPlaying() { _ = Shell.run("\(sp) playback play") }
            _ = Shell.run("\(sp) playback volume \(cfg.volume)")
            return
        }
        _ = Shell.run("\(sp) playback volume 0")
        Thread.sleep(forTimeInterval: 0.4)
        _ = Shell.run("\(sp) playback start context --id \(ctx.id) \(ctx.type)")
        Thread.sleep(forTimeInterval: 1.2)
        ensureShuffleOn()
        Thread.sleep(forTimeInterval: 0.6)
        for _ in 0..<Int.random(in: 2...5) {
            if isCancelled(gen) { break }
            _ = Shell.run("\(sp) playback next")
            Thread.sleep(forTimeInterval: 0.7)
        }
        if !isPlaying() { _ = Shell.run("\(sp) playback play") }
        _ = Shell.run("\(sp) playback volume \(cfg.volume)")   // always unmute
    }

    private func ensureShuffleOn() {
        if shuffleState() == false { _ = Shell.run("\(sp) playback shuffle") }
    }

    // MARK: Launch + AeroSpace placement

    private func ensurePlayerRunning(workspace: Int, _ gen: Int) {
        let running = !Shell.run("/usr/bin/pgrep -x spotify_player")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !running else { return }
        let before = terminalWindowIDs()
        _ = Shell.run(#"osascript -e 'tell application "Terminal" to do script "exec /opt/homebrew/bin/spotify_player"'"#)
        guard workspace > 0 else { return }           // 0 = leave the window in place
        for _ in 0..<20 {
            if isCancelled(gen) { return }
            if let id = terminalWindowIDs().subtracting(before).first {
                _ = Shell.run("\(aerospace) move-node-to-workspace --window-id \(id) -- \(workspace)")
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// AeroSpace window-ids of every Terminal window (across monitors).
    private func terminalWindowIDs() -> Set<String> {
        let out = Shell.run("\(aerospace) list-windows --monitor all --app-bundle-id com.apple.Terminal --format '%{window-id}'")
        return Set(out.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    private func waitForDevice(_ gen: Int) -> Bool {
        for _ in 0..<60 {
            if isCancelled(gen) { return false }
            if Shell.run("\(sp) get key devices").contains("\"name\":\"\(device)\"") { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
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
            return nil   // spotify: URI of an unsupported type (track/episode/…) — reject
        }
        if r.contains("open.spotify.com") {
            let comps = r.components(separatedBy: "/")
            if let idx = comps.firstIndex(where: { kinds.contains($0) }), idx + 1 < comps.count {
                var id = comps[idx + 1]
                if let q = id.firstIndex(of: "?") { id = String(id[..<q]) }
                return (comps[idx], id)
            }
            return nil   // spotify URL of an unsupported type — reject
        }
        return ("playlist", r)   // bare id → assume a playlist
    }
}
