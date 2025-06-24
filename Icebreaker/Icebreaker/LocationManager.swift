import SwiftUI
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    
    // ADD THESE MISSING PROPERTIES:
    @Published var isVisible: Bool = false
    @Published var visibilityRange: Double = 20.0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
        isLocationEnabled = true
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLocationEnabled = false
    }
    
    // ADD THIS MISSING METHOD:
    func toggleVisibility() {
        isVisible.toggle()
        if isVisible {
            startLocationUpdates()
        } else {
            stopLocationUpdates()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        if isVisible {
            updateUserLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            isLocationEnabled = true
            startLocationUpdates()
        } else {
            isLocationEnabled = false
        }
    }
    
    private func updateUserLocation() {
        guard let location = location else { return }
        print("Updating location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
}
