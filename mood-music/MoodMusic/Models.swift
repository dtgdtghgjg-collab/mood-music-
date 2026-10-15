import Foundation
import CoreLocation

struct Track: Codable, Identifiable, Hashable {
    var id = UUID()
    var fileName: String
    var title: String
}

enum Trigger: String, Codable, CaseIterable, Identifiable {
    case location, state
    var id: String { rawValue }
    var label: String { self == .location ? "По локации" : "По состоянию (скоро)" }
}

enum Transition: String, Codable, CaseIterable, Identifiable {
    case immediate, afterTrack, fade
    var id: String { rawValue }
    var label: String {
        switch self {
        case .immediate: return "Сразу"
        case .afterTrack: return "После конца трека"
        case .fade: return "Плавное затухание"
        }
    }
}

struct Playlist: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var tracks: [Track] = []
    var trigger: Trigger = .location
    var shuffle = false
}

struct Zone: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var latitude = 0.0
    var longitude = 0.0
    var hasCenter = false
    var radius = 150.0
    var playlistID: UUID?
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SavedState: Codable {
    var playlists: [Playlist]
    var zones: [Zone]
    var transition: Transition
}
