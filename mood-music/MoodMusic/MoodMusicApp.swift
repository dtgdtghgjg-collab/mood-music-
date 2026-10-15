import SwiftUI
import Combine

final class AppModel {
    static let shared = AppModel()
    let store = Store()
    let player = PlayerManager()
    let location = LocationManager()
    private var bag = Set<AnyCancellable>()

    private init() {
        location.onEnter = { [weak self] id in self?.handleEnter(id) }
        store.$zones
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] zones in self?.location.monitor(zones) }
            .store(in: &bag)
        location.requestPermission()
    }

    private func handleEnter(_ zoneID: UUID) {
        guard let zone = store.zones.first(where: { $0.id == zoneID }),
              let pid = zone.playlistID,
              let pl = store.playlists.first(where: { $0.id == pid }),
              pl.trigger == .location else { return }
        player.switchTo(pl, zoneID: zoneID, mode: store.transition)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = AppModel.shared
        return true
    }
}

@main
struct MoodMusicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppModel.shared.store)
                .environmentObject(AppModel.shared.player)
                .environmentObject(AppModel.shared.location)
        }
    }
}
