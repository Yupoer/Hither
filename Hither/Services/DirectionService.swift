//
//  DirectionService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import CoreLocation
import NearbyInteraction

@MainActor
class DirectionService: NSObject, ObservableObject {
    @Published var distanceToLeader: Double?
    @Published var bearingToLeader: Double?
    @Published var isNearbyInteractionAvailable = false
    @Published var nearbyObjects: [NINearbyObject] = []
    @Published var errorMessage: String?
    
    private var niSession: NISession?
    private let locationService: LocationService
    private var targetLeaderLocation: CLLocationCoordinate2D?
    
    init(locationService: LocationService) {
        self.locationService = locationService
        super.init()
        
        setupNearbyInteraction()
        setupLocationObserver()
    }
    
    deinit {
        niSession?.invalidate()
    }
    
    private func setupNearbyInteraction() {
        guard NISession.isSupported else {
            isNearbyInteractionAvailable = false
            return
        }
        
        niSession = NISession()
        niSession?.delegate = self
        isNearbyInteractionAvailable = true
    }
    
    private func setupLocationObserver() {
        // Observe location changes to update direction calculations
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.updateDirectionCalculations()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func setTargetLeader(location: CLLocationCoordinate2D) {
        targetLeaderLocation = location
        updateDirectionCalculations()
    }
    
    private func updateDirectionCalculations() {
        guard let leaderLocation = targetLeaderLocation,
              let currentLocation = locationService.currentLocation else {
            distanceToLeader = nil
            bearingToLeader = nil
            return
        }
        
        // Calculate distance
        distanceToLeader = locationService.calculateDistance(to: leaderLocation)
        
        // Calculate bearing
        bearingToLeader = locationService.calculateBearing(to: leaderLocation)
    }
    
    func startNearbyInteraction(with discoveryToken: Data) {
        guard let niSession = niSession,
              NISession.isSupported else {
            errorMessage = "Nearby Interaction not supported on this device"
            return
        }
        
        do {
            let token = try NIDiscoveryToken(data: discoveryToken)
            let configuration = NINearbyPeerConfiguration(peerToken: token)
            niSession.run(configuration)
        } catch {
            errorMessage = "Failed to start Nearby Interaction: \(error.localizedDescription)"
        }
    }
    
    func stopNearbyInteraction() {
        niSession?.pause()
        nearbyObjects.removeAll()
    }
    
    var currentDiscoveryToken: Data? {
        return niSession?.discoveryToken?.data
    }
    
    // Helper functions for direction display
    func getDirectionArrowRotation() -> Angle {
        guard let bearing = bearingToLeader else { return .zero }
        return .degrees(bearing)
    }
    
    func getDistanceString() -> String {
        guard let distance = distanceToLeader else { return "Unknown" }
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    func getDirectionDescription() -> String {
        guard let bearing = bearingToLeader else { return "Unknown direction" }
        
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5) / 45) % 8
        return directions[index]
    }
}

extension DirectionService: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        self.nearbyObjects = nearbyObjects
        
        // Update distance and direction from nearby interaction if available
        if let nearbyObject = nearbyObjects.first {
            if let distance = nearbyObject.distance {
                distanceToLeader = Double(distance)
            }
            
            if let direction = nearbyObject.direction {
                // Convert simd_float3 direction to bearing angle
                let bearing = atan2(Double(direction.x), Double(direction.z)) * 180 / .pi
                bearingToLeader = bearing >= 0 ? bearing : bearing + 360
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        self.nearbyObjects.removeAll { removedObject in
            nearbyObjects.contains { $0.discoveryToken == removedObject.discoveryToken }
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        // Handle session suspension
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        // Handle session resumption
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        errorMessage = "Nearby Interaction session error: \(error.localizedDescription)"
        nearbyObjects.removeAll()
    }
}

// Add import for Combine
import Combine