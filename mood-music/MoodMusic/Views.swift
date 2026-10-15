import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        TabView {
            PlayerView().tabItem { Label("Плеер", systemImage: "play.circle") }
            PlaylistsView().tabItem { Label("Саундтреки", systemImage: "music.note.list") }
            ZonesView().tabItem { Label("Зоны", systemImage: "map") }
            SettingsView().tabItem { Label("Настройки", systemImage: "gear") }
        }
    }
}

struct PlayerView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(player.playlist?.name ?? "Ничего не играет").font(.headline)
                Text(player.currentTrack?.title ?? "—").foregroundStyle(.secondary)
                HStack(spacing: 40) {
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.circle.fill").font(.system(size: 44))
                    }
                }
                List(store.playlists) { pl in
                    Button(pl.name) { player.start(pl) }
                }
            }
            .padding(.top)
            .navigationTitle("Плеер")
        }
    }
}

struct PlaylistsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            List {
                ForEach($store.playlists) { $pl in
                    NavigationLink {
                        PlaylistDetailView(playlist: $pl)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(pl.name)
                            Text("\(pl.tracks.count) тр.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { store.playlists.remove(atOffsets: $0) }
            }
            .navigationTitle("Саундтреки")
            .toolbar {
                Button { store.playlists.append(Playlist(name: "Новый саундтрек")) } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject var store: Store
    @Binding var playlist: Playlist
    @State private var importing = false

    var body: some View {
        Form {
            TextField("Название", text: $playlist.name)
            Picker("Запуск", selection: $playlist.trigger) {
                ForEach(Trigger.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Вперемешку", isOn: $playlist.shuffle)
            Section("Треки") {
                ForEach(playlist.tracks) { Text($0.title) }
                    .onDelete { store.deleteTracks(in: playlist.id, at: $0) }
                Button("Добавить музыку из Файлов") { importing = true }
            }
        }
        .navigationTitle(playlist.name)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.importTracks(urls, into: playlist.id) }
        }
    }
}

struct ZonesView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            List {
                ForEach($store.zones) { $z in
                    NavigationLink {
                        ZoneEditorView(zone: $z)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(z.name)
                            Text(subtitle(z)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { store.zones.remove(atOffsets: $0) }
            }
            .navigationTitle("Зоны")
            .toolbar {
                Button { store.zones.append(Zone(name: "Новая зона")) } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func subtitle(_ z: Zone) -> String {
        if !z.hasCenter { return "Центр не задан" }
        let pl = store.playlists.first { $0.id == z.playlistID }?.name ?? "без саундтрека"
        return "\(Int(z.radius)) м · \(pl)"
    }
}

struct ZoneEditorView: View {
    @EnvironmentObject var store: Store
    @Binding var zone: Zone
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    if zone.hasCenter {
                        MapCircle(center: zone.coordinate, radius: zone.radius)
                            .foregroundStyle(.blue.opacity(0.25))
                        Marker(zone.name, coordinate: zone.coordinate)
                    }
                }
                .onTapGesture { point in
                    if let c = proxy.convert(point, from: .local) {
                        zone.latitude = c.latitude
                        zone.longitude = c.longitude
                        zone.hasCenter = true
                    }
                }
            }
            Form {
                TextField("Название", text: $zone.name)
                Picker("Саундтрек", selection: $zone.playlistID) {
                    Text("Нет").tag(UUID?.none)
                    ForEach(store.playlists) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                VStack(alignment: .leading) {
                    Text("Радиус: \(Int(zone.radius)) м")
                    Slider(value: $zone.radius, in: 50...1000, step: 10)
                }
            }
            .frame(height: 260)
        }
        .navigationTitle("Зона (тап по карте = центр)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var location: LocationManager

    var body: some View {
        NavigationStack {
            Form {
                Picker("При смене зоны", selection: $store.transition) {
                    ForEach(Transition.allCases) { Text($0.label).tag($0) }
                }
                Section("Геолокация") {
                    Text(location.statusText)
                    Text("Для работы в фоне нужен доступ «Всегда».").font(.caption)
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
