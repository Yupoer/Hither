//
//  MapView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var locationService = LocationService()
    @StateObject private var itineraryService = ItineraryService()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var mapType: MKMapType = .standard
    @State private var isFollowingUser = true
    @State private var routeOverlay: MKPolyline?
    @State private var currentRoute: MKRoute?
    
    var body: some View {
        NavigationView {
            ZStack {
                RouteMapView(
                    region: $region,
                    mapType: mapType,
                    annotations: allAnnotations,
                    currentRoute: currentRoute,
                    userLocation: locationService.currentLocation
                )
                .onAppear {
                    setupLocationTracking()
                    setupItineraryTracking()
                }
                .onChange(of: locationService.currentLocation) { location in
                    if let location = location, isFollowingUser {
                        updateRegionToCurrentLocation(location)
                    }
                    updateRouteIfNeeded()
                }
                .onChange(of: itineraryService.currentItinerary?.currentWaypoint) { waypoint in
                    updateRouteIfNeeded()
                }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                cycleMapType()
                            }) {
                                Image(systemName: "map")
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            
                            Button(action: {
                                centerOnUser()
                            }) {
                                Image(systemName: isFollowingUser ? "location.fill" : "location")
                                    .foregroundColor(isFollowingUser ? .blue : .gray)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Connection status
                        ConnectionStatusView(locationService: locationService)
                        
                        // Group status card
                        if let group = groupService.currentGroup {
                            GroupStatusCard(group: group, locationService: locationService)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Group Map")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Location Permission", isPresented: .constant(locationService.errorMessage != nil)) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) {
                    locationService.errorMessage = nil
                }
            } message: {
                Text(locationService.errorMessage ?? "")
            }
        }
    }
    
    private var memberAnnotations: [MemberAnnotation] {
        guard let group = groupService.currentGroup else { return [] }
        
        return group.members.compactMap { member in
            guard let location = member.location else { return nil }
            return MemberAnnotation(member: member, coordinate: location.coordinate)
        }
    }
    
    private var allAnnotations: [MapViewAnnotationItem] {
        var annotations: [MapViewAnnotationItem] = []
        
        // Add member annotations
        for memberAnnotation in memberAnnotations {
            annotations.append(MapViewAnnotationItem(
                coordinate: memberAnnotation.coordinate,
                member: memberAnnotation.member,
                waypoint: nil,
                isMember: true
            ))
        }
        
        // Add current waypoint annotation
        if let currentWaypoint = itineraryService.currentItinerary?.currentWaypoint {
            annotations.append(MapViewAnnotationItem(
                coordinate: currentWaypoint.location.coordinate,
                member: nil,
                waypoint: currentWaypoint,
                isMember: false
            ))
        }
        
        return annotations
    }
    
    private var mapStyle: MapStyle {
        switch mapType {
        case .standard:
            return .standard
        case .satellite:
            return .imagery
        case .hybrid:
            return .hybrid
        default:
            return .standard
        }
    }
    
    private func setupLocationTracking() {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return }
        
        locationService.requestLocationPermission()
        locationService.startTracking(groupId: group.id, userId: user.id)
    }
    
    private func updateRegionToCurrentLocation(_ location: CLLocation) {
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    private func centerOnUser() {
        isFollowingUser = true
        if let location = locationService.currentLocation {
            updateRegionToCurrentLocation(location)
        }
    }
    
    private func setupItineraryTracking() {
        guard let group = groupService.currentGroup else { return }
        itineraryService.startListeningToItinerary(groupId: group.id)
    }
    
    private func updateRouteIfNeeded() {
        guard let userLocation = locationService.currentLocation,
              let currentWaypoint = itineraryService.currentItinerary?.currentWaypoint else {
            currentRoute = nil
            return
        }
        
        Task {
            await calculateRoute(
                from: userLocation.coordinate,
                to: currentWaypoint.location.coordinate
            )
        }
    }
    
    private func calculateRoute(from startCoordinate: CLLocationCoordinate2D, to endCoordinate: CLLocationCoordinate2D) async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoordinate))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            await MainActor.run {
                self.currentRoute = response.routes.first
            }
        } catch {
            print("Error calculating route: \(error)")
        }
    }
    
    private func cycleMapType() {
        switch mapType {
        case .standard:
            mapType = .satellite
        case .satellite:
            mapType = .hybrid
        case .hybrid:
            mapType = .standard
        default:
            mapType = .standard
        }
    }
}

struct MemberAnnotation: Identifiable {
    let id = UUID()
    let member: GroupMember
    let coordinate: CLLocationCoordinate2D
}

struct MapViewAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let member: GroupMember?
    let waypoint: Waypoint?
    let isMember: Bool
}

struct MemberAnnotationView: View {
    let member: GroupMember
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(member.role == .leader ? Color.yellow : Color.blue)
                    .frame(width: 30, height: 30)
                
                Image(systemName: member.role == .leader ? "crown.fill" : "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
            }
            
            Text(member.displayName)
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.8))
                .cornerRadius(4)
        }
    }
}

struct WaypointAnnotationView: View {
    let waypoint: Waypoint
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(waypoint.isInProgress ? Color.green : Color.blue)
                    .frame(width: 35, height: 35)
                
                Image(systemName: waypoint.type.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
                
                if waypoint.isInProgress {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 45, height: 45)
                        .opacity(0.6)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: waypoint.isInProgress)
                }
            }
            
            Text(waypoint.name)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(waypoint.isInProgress ? Color.green.opacity(0.8) : Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }
}

struct GroupStatusCard: View {
    let group: HitherGroup
    let locationService: LocationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.name)
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(locationService.isTracking ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(locationService.isTracking ? "Tracking" : "Not Tracking")
                    .font(.caption)
                    .foregroundColor(locationService.isTracking ? .green : .red)
            }
            
            HStack {
                Text("Members: \(group.members.count)")
                    .font(.subheadline)
                
                Spacer()
                
                if let leader = group.leader,
                   let leaderLocation = leader.location,
                   let distance = locationService.calculateDistance(to: leaderLocation.coordinate) {
                    Text("Distance to leader: \(Int(distance))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}