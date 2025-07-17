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
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var mapType: MKMapType = .standard
    @State private var isFollowingUser = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, 
                    interactionModes: .all,
                    showsUserLocation: true,
                    annotationItems: memberAnnotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        MemberAnnotationView(member: annotation.member)
                    }
                }
                .mapStyle(mapStyle)
                .onAppear {
                    setupLocationTracking()
                }
                .onChange(of: locationService.currentLocation) { location in
                    if let location = location, isFollowingUser {
                        updateRegionToCurrentLocation(location)
                    }
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