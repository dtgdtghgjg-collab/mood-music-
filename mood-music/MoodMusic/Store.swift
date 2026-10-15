import Foundation
import Combine

final class Store: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var zones: [Zone] = []
    @Published var transition: Transition = .immediate
    private var bag = Set<AnyCancellable>()

    static var docs: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var musicDir: URL { docs.appendingPathComponent("Music", isDirectory: true) }
    static func url(for track: Track) -> URL { musicDir.appendingPathComponent(track.fileName) }
    private var stateURL: URL { Store.docs.appendingPathComponent("state.json") }

    init() {
        try? FileManager.default.createDirectory(at: Store.musicDir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: stateURL),
           let s = try? JSONDecoder().decode(SavedState.self, from: data) {
            playlists = s.playlists
            zones = s.zones
            transition = s.transition
        }
        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.save() }
            .store(in: &bag)
    }

    func save() {
        let s = SavedState(playlists: playlists, zones: zones, transition: transition)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: stateURL, options: .atomic) }
    }

    func importTracks(_ urls: [URL], into playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let name = "\(UUID().uuidString)-\(url.lastPathComponent)"
            let dest = Store.musicDir.appendingPathComponent(name)
            do {
                try FileManager.default.copyItem(at: url, to: dest)
                playlists[i].tracks.append(Track(fileName: name, title: url.deletingPathExtension().lastPathComponent))
            } catch {
                print("import error:", error)
            }
        }
    }

    func deleteTracks(in playlistID: UUID, at offsets: IndexSet) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        for o in offsets { try? FileManager.default.removeItem(at: Store.url(for: playlists[i].tracks[o])) }
        playlists[i].tracks.remove(atOffsets: offsets)
    }
}
