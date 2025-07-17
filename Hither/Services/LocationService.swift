//
//  LocationService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import CoreLocation
import FirebaseFirestore

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private var groupId: String?
    private var userId: String?
    private var locationUpdateTimer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access is required for group tracking. Please enable it in Settings."
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    func startTracking(groupId: String, userId: String) {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        self.groupId = groupId
        self.userId = userId
        self.isTracking = true
        
        locationManager.startUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = authorizationStatus == .authorizedAlways
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Start periodic updates to Firestore
        startPeriodicLocationSync()
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        stopPeriodicLocationSync()
    }
    
    private func startPeriodicLocationSync() {
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.syncLocationToFirestore()
            }
        }
    }
    
    private func stopPeriodicLocationSync() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func syncLocationToFirestore() async {
        guard let groupId = groupId,
              let userId = userId,
              let location = currentLocation else { return }
        
        let geoPoint = GeoPoint(from: location.coordinate)
        
        do {
            // Update member location in the group document
            try await db.collection("groups").document(groupId).updateData([
                "members.\(userId).location": [
                    "latitude": geoPoint.latitude,
                    "longitude": geoPoint.longitude
                ],
                "members.\(userId).lastLocationUpdate": Timestamp(date: Date())
            ])
        } catch {
            errorMessage = "Failed to sync location: \(error.localizedDescription)"
        }
    }
    
    func calculateDistance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    func calculateBearing(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        
        let lat1 = currentLocation.coordinate.latitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let dLon = (coordinate.longitude - currentLocation.coordinate.longitude) * .pi / 180
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return bearing >= 0 ? bearing : bearing + 360
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Sync to Firestore when tracking and location changes significantly
        if isTracking {
            Task {
                await syncLocationToFirestore()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location update failed: \(error.localizedDescription)"
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            errorMessage = nil
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable it in Settings."
            stopTracking()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}