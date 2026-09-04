import Foundation

/// Drives the official Spotify desktop app (via AppleScript) to play the focus
/// soundtrack. Each slot is an ordinary Spotify playlist/album/artist URI; Liked
/// Songs are supported by pointing a slot at a *mirror* playlist (see
/// `scripts/sync_liked_playlist.py`, or make one by hand in Spotify).
///
/// Lifecycle: session start → launch Spotify (in the background, without stealing
/// focus) + play the active slot, shuffled, ducked to the focus volume; focus↔break
/// → pause/resume; end → restore the pre-session volume + pause (the app is left
/// running). No librespot, no Connect device, so there is nothing to drop and no
/// "no playback found" — which is why there is no watchdog here.
///
/// Concurrency: public methods run on the main thread and snapshot the Settings they
/// need there (@Observable Settings must not be read off-main), then dispatch to a
/// serial queue. A generation counter lets a pause/stop/switch cancel an in-flight
/// start promptly, and every start restores an audible volume even if it bails early.
final class MusicController {
    private let settings: Settings
    private let queue = DispatchQueue(label: "com.keegan.flowstate.music")

    private var savedVolume: Int?          // queue-only: Spotify's volume before we ducked
    private let genLock = NSLock()
    private var generation = 0             // guarded by genLock

    /// Immutable snapshot of the Settings the background work needs.
    private struct Config {
        let alwaysShuffle: Bool
        let volume: Int
        let uri: String?          // resolved spotify: URI for the active slot (nil = nothing to play)
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
        _ = bumpGeneration()                 // cancel any in-flight start
        queue.async { [weak self] in self?.pause() }
    }

    func resumeFromBreak() {
        guard settings.playSoundtrack else { return }
        let cfg = snapshot(); let gen = bumpGeneration()
        queue.async { [weak self] in guard let self else { return }
            guard self.spotifyRunning() else { self.engage(cfg, gen); return }
            self.osa("play")                                   // resume where the break paused
            Thread.sleep(forTimeInterval: 0.3)
            if self.isCancelled(gen) { return }
            if self.playerState() != "playing" { self.engage(cfg, gen) }   // context lost → restart
        }
    }

    /// Skip the current soundtrack song (not the Pomodoro phase).
    func nextTrack() {
        guard settings.playSoundtrack else { return }
        queue.async { [weak self] in guard let self, self.spotifyRunning() else { return }
            self.osa("next track")
        }
    }

    /// End of cycle / reset — restore the pre-session volume + pause; leave Spotify open.
    func stopSoundtrack() {
        _ = bumpGeneration()
        queue.async { [weak self] in guard let self, self.spotifyRunning() else { return }
            if let v = self.savedVolume { self.setVolume(v) }
            self.osa("pause")
            self.savedVolume = nil
        }
    }

    // MARK: Snapshot + generation

    private func snapshot() -> Config {
        Config(alwaysShuffle: settings.alwaysShuffle,
               volume: settings.spotifyVolume,
               uri: trackURI(from: settings.activeSlotTarget))
    }
    private func bumpGeneration() -> Int {
        genLock.lock(); generation += 1; let g = generation; genLock.unlock(); return g
    }
    private func isCancelled(_ g: Int) -> Bool {
        genLock.lock(); let c = generation != g; genLock.unlock(); return c
    }

    // MARK: Sequence (serial queue)

    private func engage(_ cfg: Config, _ gen: Int) {
        guard let uri = cfg.uri else { return }           // nothing playable (blank, or "liked")
        guard ensureRunning(gen) else { return }
        if savedVolume == nil { savedVolume = currentVolume() }
        if isCancelled(gen) { return }
        play(uri: uri, cfg, gen)
    }

    /// Start `uri` shuffled and ducked. Muted during setup so the first (track-1)
    /// moment and the shuffle-skips are silent; the volume is always restored on exit
    /// (defer), so an early cancel never strands Spotify at volume 0.
    private func play(uri: String, _ cfg: Config, _ gen: Int) {
        var restored = false
        func unmute() { if !restored { setVolume(cfg.volume); restored = true } }
        defer { unmute() }

        setVolume(0)
        if isCancelled(gen) { return }

        // `play track` is the ONE Spotify command that pulls the app to the foreground
        // (volume / shuffle / next / play / pause don't). Capture whoever's in front,
        // start the context, then hand focus straight back so Spotify never steals the
        // user's place.
        let prevFront = frontmostBundleID()
        osa("play track \"\(uri)\"")                       // starts the context at track 1
        Thread.sleep(forTimeInterval: 0.35)
        if playerState() == "stopped" {                    // app still warming up → retry once
            osa("play track \"\(uri)\"")
            Thread.sleep(forTimeInterval: 0.5)
        }
        restoreFocus(prevFront)
        if isCancelled(gen) { return }

        if cfg.alwaysShuffle {
            osa("set shuffling to true")                   // context is live now → shuffle sticks
            Thread.sleep(forTimeInterval: 0.2)
            for _ in 0..<Int.random(in: 1...4) {           // jump to a varied track in shuffle order
                if isCancelled(gen) { return }
                osa("next track")
                Thread.sleep(forTimeInterval: 0.15)
            }
        }
        osa("set repeating to true")                       // loop so a focus block never falls silent
        if playerState() != "playing" { osa("play") }
        unmute()                                            // to focus volume (defer is the backstop)
    }

    private func pause() { if spotifyRunning() { osa("pause") } }

    // MARK: Launch

    /// Ensure Spotify is running (launched in the background, without stealing focus)
    /// and scriptable. Reuses a running instance.
    private func ensureRunning(_ gen: Int) -> Bool {
        if spotifyRunning() { return true }
        _ = Shell.run("/usr/bin/open -gj -a Spotify")      // -g: don't foreground, -j: launch hidden
        for _ in 0..<40 {                                  // up to ~10s to come up
            if isCancelled(gen) { return false }
            Thread.sleep(forTimeInterval: 0.25)
            if spotifyRunning() {
                Thread.sleep(forTimeInterval: 0.3)         // brief settle until scriptable
                return true
            }
        }
        return spotifyRunning()
    }

    // MARK: AppleScript bridge

    /// Run one AppleScript statement against Spotify; returns trimmed stdout.
    /// Sending a command auto-launches Spotify if needed (callers ensure it first).
    @discardableResult
    private func osa(_ stmt: String) -> String {
        Shell.run("/usr/bin/osascript -e 'tell application \"Spotify\" to \(stmt)'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True if Spotify is running — this query does NOT launch it.
    private func spotifyRunning() -> Bool {
        Shell.run("/usr/bin/osascript -e 'application \"Spotify\" is running'")
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private func playerState() -> String { osa("player state") }          // playing / paused / stopped
    private func currentVolume() -> Int? { Int(osa("sound volume")) }
    private func setVolume(_ v: Int) { osa("set sound volume to \(max(0, min(100, v)))") }

    // MARK: Focus preservation (keep `play track` from stealing the foreground)

    /// Bundle id of the frontmost app, via `lsappinfo` — no AppleScript, so no extra
    /// automation-permission prompt. nil if it can't be determined.
    private func frontmostBundleID() -> String? {
        let asn = Shell.run("/usr/bin/lsappinfo front")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asn.isEmpty else { return nil }
        // e.g.  "CFBundleIdentifier"="com.apple.dt.Xcode"
        let out = Shell.run("/usr/bin/lsappinfo info -only bundleid \(asn)")
        guard let open = out.range(of: "=\"") else { return nil }
        let tail = out[open.upperBound...]
        guard let close = tail.firstIndex(of: "\"") else { return nil }
        let id = String(tail[..<close])
        return id.isEmpty ? nil : id
    }

    /// Return the foreground to `bundleID` (where it was before `play track`). Skips
    /// Spotify itself, and validates the id so it can't inject into the shell.
    private func restoreFocus(_ bundleID: String?) {
        guard let id = bundleID, id != "com.spotify.client",
              id.allSatisfy({ $0.isLetter || $0.isNumber || ".-".contains($0) })
        else { return }
        _ = Shell.run("/usr/bin/open -b \(id)")
    }

    // MARK: Target parsing → a playable spotify: URI

    /// Resolve a slot target to a `spotify:…` URI that `play track` accepts, or nil.
    /// Accepts `spotify:playlist:…`, an open.spotify.com URL, or a bare playlist id.
    /// "liked" has no native equivalent — point the slot at a mirror playlist instead.
    /// The result is restricted to Spotify-URI characters so a pasted target can't
    /// break out of the AppleScript/shell quoting.
    private func trackURI(from raw: String) -> String? {
        let r = raw.trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty else { return nil }
        let lower = r.lowercased()
        if lower == "liked" || lower == "likes" || lower.contains(":collection") { return nil }

        var uri: String?
        if r.hasPrefix("spotify:") {
            uri = r
        } else if r.contains("open.spotify.com") {
            let kinds = ["playlist", "album", "artist", "track"]
            let comps = r.components(separatedBy: "/")
            if let idx = comps.firstIndex(where: { kinds.contains($0) }), idx + 1 < comps.count {
                var id = comps[idx + 1]
                if let q = id.firstIndex(of: "?") { id = String(id[..<q]) }
                uri = "spotify:\(comps[idx]):\(id)"
            }
        } else {
            uri = "spotify:playlist:\(r)"                  // bare id → assume a playlist
        }

        // Real Spotify URIs are only letters, digits, colons (and -._ in some user URIs).
        guard let u = uri,
              u.allSatisfy({ $0.isLetter || $0.isNumber || ":-._".contains($0) })
        else { return nil }
        return u
    }
}
