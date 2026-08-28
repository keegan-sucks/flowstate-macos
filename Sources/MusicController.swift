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
        let cfg = snapshot()
        let gen = bumpGeneration()
        queue.async { [weak self] in guard let self else { return }
            _ = Shell.run("\(self.sp) playback play")
            Thread.sleep(forTimeInterval: 0.8)
            if self.isCancelled(gen) { return }
            // Spotify deactivates the librespot device during a break, so a bare `play`
            // often has no track to resume — reconnect and restart the soundtrack.
            if self.playbackTrack() == nil {
                self.engage(cfg, gen)
            }
        }
    }

    /// Skip the current soundtrack song (not the Pomodoro phase).
    func nextTrack() {
        guard settings.playSoundtrack else { return }
        queue.async { [weak self] in guard let self else { return }
            _ = Shell.run("\(self.sp) playback next")
        }
    }

    /// Like (save) the currently playing track.
    func likeCurrentSong() {
        queue.async { [weak self] in guard let self else { return }
            _ = Shell.run("\(self.sp) like")
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
        guard ensurePlayer(workspace: cfg.workspace, gen) else { return }
        _ = Shell.run("\(sp) connect --name \(device)")
        Thread.sleep(forTimeInterval: 0.6)   // let the device activate before playback commands
        if savedVolume == nil { savedVolume = currentVolume() ?? 100 }
        if isCancelled(gen) { return }

        if isLiked(cfg.target) {
            startLiked(cfg, gen)
        } else if let ctx = parseContext(cfg.target) {
            startContext(ctx, cfg, gen)
        }
        if !isCancelled(gen) { ensureRepeatContext() }   // repeat the whole playlist / liked
    }

    /// Liked Songs: `--random` starts on a random track directly. Volume is ducked
    /// before playback so an early cancel never leaves it un-ducked.
    private func startLiked(_ cfg: Config, _ gen: Int) {
        _ = Shell.run("\(sp) playback volume \(cfg.volume)")
        _ = Shell.run("\(sp) playback start liked --random")
        Thread.sleep(forTimeInterval: 1.0)
        if isCancelled(gen) { return }
        // Verify it took: Liked playback has no context, so a lingering context.uri means
        // the previous playlist is still playing (device wasn't ready) — retry once.
        if contextURI() != nil {
            _ = Shell.run("\(sp) playback start liked --random")
            Thread.sleep(forTimeInterval: 1.0)
        }
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
            _ = Shell.run("\(sp) playback volume \(cfg.volume)")   // duck before playing
            startContextVerified(ctx)
            if !isPlaying() { _ = Shell.run("\(sp) playback play") }
            return
        }
        _ = Shell.run("\(sp) playback volume 0")
        Thread.sleep(forTimeInterval: 0.4)
        startContextVerified(ctx)
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

    /// Start a context, verifying it took — retry once if the previous context lingers.
    private func startContextVerified(_ ctx: (type: String, id: String)) {
        _ = Shell.run("\(sp) playback start context --id \(ctx.id) \(ctx.type)")
        Thread.sleep(forTimeInterval: 1.0)
        if !(contextURI()?.contains(ctx.id) ?? false) {
            _ = Shell.run("\(sp) playback start context --id \(ctx.id) \(ctx.type)")
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    private func ensureShuffleOn() {
        // Read-toggle-verify (a single toggle right after a context change often no-ops).
        for _ in 0..<3 {
            if shuffleState() == true { return }
            _ = Shell.run("\(sp) playback shuffle")
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Ensure repeat is "context" (repeat the whole playlist / liked collection).
    /// Starting playback (liked/context) reliably resets repeat to "off", and the
    /// repeat_state read lags too much to trust right after a start — so just cycle
    /// off → track → context (2 steps) blindly. A single settled verify then fixes a
    /// rare dropped cycle; a stale "off" read is ignored to avoid overshooting.
    private func ensureRepeatContext() {
        _ = Shell.run("\(sp) playback repeat")           // off → track
        Thread.sleep(forTimeInterval: 0.7)
        _ = Shell.run("\(sp) playback repeat")           // track → context
        Thread.sleep(forTimeInterval: 1.2)               // settle for an accurate read
        if repeatState() == "track" {                    // a cycle was dropped
            _ = Shell.run("\(sp) playback repeat")
        }
    }

    // MARK: Launch + AeroSpace placement

    /// Ensure the spotify_player Connect device is available. Reuse a running instance,
    /// otherwise launch its terminal — retrying once if the process never comes up
    /// (Terminal's first cold-start `do script`, or the one-time "control Terminal"
    /// Automation prompt, can make the first attempt a no-op that opens an empty window).
    private func ensurePlayer(workspace: Int, _ gen: Int) -> Bool {
        for _ in 1...2 {
            if isCancelled(gen) { return false }
            // Reuse a running instance — including one from a slow prior launch — so the
            // retry never spawns a duplicate.
            if spotifyRunning() { return waitForDevice(gen, ticks: 60) }
            let before = terminalWindowIDs()
            launchPlayerTerminal()
            for _ in 0..<16 {                          // ~5s for the process to appear
                if isCancelled(gen) { return false }
                if spotifyRunning() { break }
                Thread.sleep(forTimeInterval: 0.3)
            }
            if spotifyRunning() {
                placeNewPlayerWindow(notIn: before, workspace: workspace, gen)
                return waitForDevice(gen, ticks: 40)
            }
            // No process → the launch no-op'd; loop retries (re-checks spotifyRunning first).
        }
        return false
    }

    private func spotifyRunning() -> Bool {
        !Shell.run("/usr/bin/pgrep -x spotify_player")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Open spotify_player in Terminal, matching how the user launches it by hand:
    /// on a cold start reuse Terminal's own startup window (so there's no extra empty
    /// window), and force the window to the user's startup profile (their theme).
    private func launchPlayerTerminal() {
        _ = Shell.run(#"osascript -e 'set wasRunning to (application "Terminal" is running)' -e 'tell application "Terminal"' -e 'if wasRunning then' -e 'do script "exec /opt/homebrew/bin/spotify_player"' -e 'else' -e 'do script "exec /opt/homebrew/bin/spotify_player" in window 1' -e 'end if' -e 'delay 0.2' -e 'set current settings of front window to startup settings' -e 'end tell'"#)
    }

    /// Move the newly-opened player Terminal window to the workspace (by window-id,
    /// which doesn't steal focus). Picks the new window whose title mentions
    /// spotify_player so an unrelated Terminal opened mid-launch is never yanked.
    private func placeNewPlayerWindow(notIn before: Set<String>, workspace: Int, _ gen: Int) {
        guard workspace > 0 else { return }            // 0 = leave the window in place
        for _ in 0..<20 {
            if isCancelled(gen) { return }
            let fresh = terminalWindows().filter { !before.contains($0.id) }
            let match = fresh.first { $0.title.contains("spotify_player") }
            // Unambiguous fallback: exactly one new window (title not yet resolved).
            if let id = match?.id ?? (fresh.count == 1 ? fresh.first?.id : nil) {
                _ = Shell.run("\(aerospace) move-node-to-workspace --window-id \(id) -- \(workspace)")
                // A window moved to a non-focused workspace floats, and stays settling for
                // several seconds — a `layout tiling` that runs too early just no-ops. Retry
                // in the BACKGROUND (so the music start isn't blocked) until it sticks; once
                // tiled it stays, and repeat `layout tiling` calls are idempotent no-ops.
                let aero = aerospace
                DispatchQueue.global(qos: .utility).async {
                    for _ in 0..<16 {
                        _ = Shell.run("\(aero) layout --window-id \(id) tiling")
                        Thread.sleep(forTimeInterval: 0.6)
                    }
                }
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// (window-id, title) of every Terminal window (across monitors).
    private func terminalWindows() -> [(id: String, title: String)] {
        let out = Shell.run("\(aerospace) list-windows --monitor all --app-bundle-id com.apple.Terminal --format '%{window-id}|%{window-title}'")
        return out.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { return nil }
            let id = parts[0].trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? nil : (id, parts[1])
        }
    }

    /// AeroSpace window-ids of every Terminal window (across monitors).
    private func terminalWindowIDs() -> Set<String> {
        Set(terminalWindows().map { $0.id })
    }

    private func waitForDevice(_ gen: Int, ticks: Int) -> Bool {
        for _ in 0..<ticks {
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
    private func repeatState() -> String? { playbackJSON()?["repeat_state"] as? String }
    private func contextURI() -> String? { (playbackJSON()?["context"] as? [String: Any])?["uri"] as? String }
    private func playbackTrack() -> String? {
        (playbackJSON()?["item"] as? [String: Any])?["name"] as? String
    }
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
