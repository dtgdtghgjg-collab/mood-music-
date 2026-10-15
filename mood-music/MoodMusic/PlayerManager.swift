import AVFoundation
import Combine

final class PlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playlist: Playlist?
    @Published var currentTrack: Track?
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private var queue: [Track] = []
    private var index = 0
    private var zoneID: UUID?
    private var pendingPlaylist: Playlist?
    private var pendingZone: UUID?
    private var fadeTimer: Timer?

    func start(_ pl: Playlist, zoneID: UUID? = nil) {
        guard !pl.tracks.isEmpty else { return }
        fadeTimer?.invalidate(); fadeTimer = nil
        pendingPlaylist = nil
        playlist = pl
        self.zoneID = zoneID
        queue = pl.shuffle ? pl.tracks.shuffled() : pl.tracks
        index = 0
        playCurrent()
    }

    private func playCurrent() {
        guard !queue.isEmpty else { return }
        let t = queue[index]
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default)
            try s.setActive(true)
            let p = try AVAudioPlayer(contentsOf: Store.url(for: t))
            p.delegate = self
            p.volume = 1
            p.prepareToPlay()
            p.play()
            player = p
            currentTrack = t
            isPlaying = true
        } catch {
            print("play error:", error)
            isPlaying = false
        }
    }

    func next() {
        guard !queue.isEmpty else { return }
        index = (index + 1) % queue.count
        playCurrent()
    }

    func toggle() {
        guard let p = player else { return }
        if p.isPlaying { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
    }

    func switchTo(_ pl: Playlist, zoneID: UUID?, mode: Transition) {
        if isPlaying, self.zoneID == zoneID, playlist?.id == pl.id { return }
        guard !pl.tracks.isEmpty else { return }
        if !isPlaying || player == nil { start(pl, zoneID: zoneID); return }
        switch mode {
        case .immediate:
            start(pl, zoneID: zoneID)
        case .afterTrack:
            pendingPlaylist = pl
            pendingZone = zoneID
        case .fade:
            fadeOut { [weak self] in self?.start(pl, zoneID: zoneID) }
        }
    }

    private func fadeOut(then done: @escaping () -> Void) {
        fadeTimer?.invalidate()
        guard let p = player else { done(); return }
        let steps = 20
        var n = 0
        let v0 = p.volume
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            n += 1
            p.volume = max(0, v0 * (1 - Float(n) / Float(steps)))
            if n >= steps {
                t.invalidate()
                self?.fadeTimer = nil
                done()
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let pl = pendingPlaylist {
            start(pl, zoneID: pendingZone)
        } else {
            next()
        }
    }
}
