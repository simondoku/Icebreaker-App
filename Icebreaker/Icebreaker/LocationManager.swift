import SwiftUI
import CoreLocation
import Firebase
import FirebaseAuth

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    // Make Firebase service optional and lazy to avoid early initialization
    private var firebaseUserService: FirebaseUserService? {
        // Only create if Firebase is configured
        guard FirebaseApp.app() != nil else { return nil }
        return FirebaseUserService.shared
    }
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var isVisible: Bool = false
    @Published var visibilityRange: Double = 20.0
    @Published var locationError: LocationError?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // Update every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = .permissionDenied
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = .servicesDisabled
            return
        }
        
        locationManager.startUpdatingLocation()
        isLocationEnabled = true
        locationError = nil
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLocationEnabled = false
        
        // Update visibility in Firebase
        Task {
            await updateFirebaseVisibility(false)
        }
    }
    
    func toggleVisibility() {
        isVisible.toggle()
        
        Task {
            await updateFirebaseVisibility(isVisible)
        }
        
        if isVisible && authorizationStatus == .authorizedWhenInUse {
            startLocationUpdates()
        } else if !isVisible {
            stopLocationUpdates()
        }
    }
    
    func updateVisibilityRange(_ range: Double) {
        visibilityRange = range
        // Trigger location update to refresh nearby users
        if let location = location, isVisible {
            Task {
                await updateUserLocationInFirebase(location)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Only update if location has changed significantly
        if let lastLocation = location {
            let distance = newLocation.distance(from: lastLocation)
            if distance < 10.0 { return } // Less than 10 meters, don't update
        }
        
        location = newLocation
        locationError = nil
        
        if isVisible {
            Task {
                await updateUserLocationInFirebase(newLocation)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                if self.isVisible {
                    self.startLocationUpdates()
                }
            case .denied, .restricted:
                self.locationError = .permissionDenied
                self.isLocationEnabled = false
                self.isVisible = false
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = .permissionDenied
                case .locationUnknown:
                    self.locationError = .locationUnavailable
                case .network:
                    self.locationError = .networkError
                default:
                    self.locationError = .unknownError(error.localizedDescription)
                }
            } else {
                self.locationError = .unknownError(error.localizedDescription)
            }
            print("Location error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Firebase Integration
    private func updateUserLocationInFirebase(_ location: CLLocation) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                self.locationError = .notAuthenticated
            }
            return
        }
        
        do {
            try await firebaseUserService?.updateUserLocation(location, userId: userId)
        } catch {
            await MainActor.run {
                self.locationError = .firebaseError(error)
            }
            print("Failed to update location in Firebase: \(error)")
        }
    }
    
    private func updateFirebaseVisibility(_ isVisible: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                self.locationError = .notAuthenticated
            }
            return
        }
        
        do {
            try await firebaseUserService?.setUserVisibility(isVisible, userId: userId)
        } catch {
            await MainActor.run {
                self.locationError = .firebaseError(error)
            }
            print("Failed to update visibility in Firebase: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    func distanceString(from meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            let km = meters / 1000
            if km < 10 {
                return String(format: "%.1fkm", km)
            } else {
                return "\(Int(km))km"
            }
        }
    }
    
    func isLocationPermissionGranted() -> Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func canStartLocationServices() -> Bool {
        return CLLocationManager.locationServicesEnabled() && isLocationPermissionGranted()
    }
}

// MARK: - Location Errors
enum LocationError: Error, LocalizedError {
    case permissionDenied
    case servicesDisabled
    case locationUnavailable
    case networkError
    case notAuthenticated
    case firebaseError(Error)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .servicesDisabled:
            return "Location services are disabled"
        case .locationUnavailable:
            return "Location is currently unavailable"
        case .networkError:
            return "Network error while getting location"
        case .notAuthenticated:
            return "User not authenticated"
        case .firebaseError(let error):
            return "Firebase error: \(error.localizedDescription)"
        case .unknownError(let message):
            return "Unknown location error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please enable location permission in Settings"
        case .servicesDisabled:
            return "Please enable location services in Settings"
        case .locationUnavailable, .networkError:
            return "Please try again in a moment"
        case .notAuthenticated:
            return "Please sign in to use location features"
        case .firebaseError:
            return "Check your internet connection and try again"
        case .unknownError:
            return "Please restart the app and try again"
        }
    }
}
