import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var firstSync = true
    var onEnter: ((UUID) -> Void)?
    @Published var status: CLAuthorizationStatus = .notDetermined

    var statusText: String {
        switch status {
        case .authorizedAlways: return "Доступ: всегда (ок)"
        case .authorizedWhenInUse: return "Доступ: только при использовании (нужно «Всегда»)"
        case .denied, .restricted: return "Доступ запрещён (включи в Настройках iPhone)"
        default: return "Доступ ещё не запрошен"
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func monitor(_ zones: [Zone]) {
        for r in manager.monitoredRegions { manager.stopMonitoring(for: r) }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let check = firstSync
        firstSync = false
        for z in zones.filter({ $0.hasCenter }).prefix(20) {
            let r = CLCircularRegion(
                center: z.coordinate,
                radius: min(z.radius, manager.maximumRegionMonitoringDistance),
                identifier: z.id.uuidString)
            r.notifyOnEntry = true
            r.notifyOnExit = false
            manager.startMonitoring(for: r)
            if check { manager.requestState(for: r) }
        }
    }

    private func handle(_ region: CLRegion) {
        if let id = UUID(uuidString: region.identifier) { onEnter?(id) }
    }

    func locationManager(_ m: CLLocationManager, didEnterRegion region: CLRegion) { handle(region) }

    func locationManager(_ m: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if state == .inside { handle(region) }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        status = m.authorizationStatus
        if status == .authorizedWhenInUse { m.requestAlwaysAuthorization() }
    }
}
