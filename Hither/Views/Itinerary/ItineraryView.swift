//
//  ItineraryView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import MapKit
import CoreLocation

struct ItineraryView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var itineraryService = ItineraryService()
    @StateObject private var locationService = LocationService()
    @State private var showingAddWaypoint = false
    @State private var selectedWaypoint: Waypoint?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let group = groupService.currentGroup,
                   let user = authService.currentUser {
                    
                    if group.leader?.userId == user.id {
                        // Leader interface
                        leaderItineraryView(group: group, user: user)
                    } else {
                        // Follower interface
                        followerItineraryView(group: group, user: user)
                    }
                } else {
                    Text("Join a group to view itinerary")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Itinerary")
            .navigationBarItems(
                trailing: isLeader ? AnyView(addWaypointButton) : AnyView(EmptyView())
            )
            .onAppear {
                setupItineraryService()
            }
            .sheet(isPresented: $showingAddWaypoint) {
                AddWaypointSheet(
                    itineraryService: itineraryService,
                    groupId: groupService.currentGroup?.id ?? "",
                    userId: authService.currentUser?.id ?? "",
                    userName: authService.currentUser?.displayName ?? ""
                )
            }
            .sheet(item: $selectedWaypoint) { waypoint in
                WaypointDetailSheet(
                    waypoint: waypoint,
                    itineraryService: itineraryService,
                    groupId: groupService.currentGroup?.id ?? "",
                    userId: authService.currentUser?.id ?? "",
                    userName: authService.currentUser?.displayName ?? "",
                    isLeader: isLeader
                )
            }
        }
    }
    
    private var isLeader: Bool {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return false }
        return group.leader?.userId == user.id
    }
    
    private var addWaypointButton: some View {
        Button(action: {
            showingAddWaypoint = true
        }) {
            Image(systemName: "plus")
        }
    }
    
    @ViewBuilder
    private func leaderItineraryView(group: HitherGroup, user: HitherUser) -> some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Manage Itinerary")
                    .font(.headline)
                
                Text("Add waypoints and guide your group")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Itinerary list
            itineraryListView()
        }
    }
    
    @ViewBuilder
    private func followerItineraryView(group: HitherGroup, user: HitherUser) -> some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Group Itinerary")
                    .font(.headline)
                
                Text("Follow the planned route")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Next waypoint card
            if let nextWaypoint = itineraryService.currentItinerary?.nextWaypoint {
                NextWaypointCard(
                    waypoint: nextWaypoint,
                    locationService: locationService
                )
                .padding(.horizontal)
            }
            
            // Itinerary list
            itineraryListView()
        }
    }
    
    @ViewBuilder
    private func itineraryListView() -> some View {
        if let itinerary = itineraryService.currentItinerary {
            if itinerary.waypoints.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No waypoints yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if isLeader {
                        Text("Tap + to add your first waypoint")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Active waypoints
                        if !itinerary.activeWaypoints.isEmpty {
                            Section {
                                ForEach(itinerary.activeWaypoints) { waypoint in
                                    WaypointCard(
                                        waypoint: waypoint,
                                        locationService: locationService,
                                        isLeader: isLeader,
                                        onTap: {
                                            selectedWaypoint = waypoint
                                        },
                                        onComplete: isLeader ? {
                                            Task {
                                                guard let groupId = groupService.currentGroup?.id,
                                                      let userId = authService.currentUser?.id else { return }
                                                
                                                await itineraryService.markWaypointCompleted(
                                                    waypointId: waypoint.id,
                                                    groupId: groupId,
                                                    updatedBy: userId
                                                )
                                            }
                                        } : nil
                                    )
                                }
                            } header: {
                                HStack {
                                    Text("Upcoming")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Completed waypoints
                        if !itinerary.completedWaypoints.isEmpty {
                            Section {
                                ForEach(itinerary.completedWaypoints) { waypoint in
                                    WaypointCard(
                                        waypoint: waypoint,
                                        locationService: locationService,
                                        isLeader: isLeader,
                                        onTap: {
                                            selectedWaypoint = waypoint
                                        },
                                        onComplete: isLeader ? {
                                            Task {
                                                await itineraryService.completeWaypoint(
                                                    groupId: group.id,
                                                    waypointId: waypoint.id
                                                )
                                            }
                                        } : nil
                                    )
                                }
                            } header: {
                                HStack {
                                    Text("Completed")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        } else {
            ProgressView("Loading itinerary...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
        if itineraryService.isLoading {
            ProgressView()
                .padding()
        }
        
        if let errorMessage = itineraryService.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .padding()
        }
    }
    
    private func setupItineraryService() {
        guard let group = groupService.currentGroup else { return }
        itineraryService.startListeningToItinerary(groupId: group.id)
        
        if let user = authService.currentUser {
            locationService.startTracking(groupId: group.id, userId: user.id)
        }
    }
}

struct NextWaypointCard: View {
    let waypoint: Waypoint
    let locationService: LocationService
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Next Destination")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            }
            
            HStack {
                Image(systemName: waypoint.type.icon)
                    .foregroundColor(getTypeColor())
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(waypoint.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = waypoint.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let currentLocation = locationService.currentLocation {
                        let distance = CLLocation(
                            latitude: waypoint.location.latitude,
                            longitude: waypoint.location.longitude
                        ).distance(from: currentLocation)
                        
                        Text("\(Int(distance))m away")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func getTypeColor() -> Color {
        switch waypoint.type.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        default: return .blue
        }
    }
}

struct WaypointCard: View {
    let waypoint: Waypoint
    let locationService: LocationService
    let isLeader: Bool
    let onTap: () -> Void
    let onComplete: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: waypoint.type.icon)
                        .foregroundColor(getTypeColor())
                        .font(.title2)
                    
                    if !waypoint.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(waypoint.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(waypoint.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(getTypeColor().opacity(0.2))
                        .cornerRadius(4)
                    
                    if let description = waypoint.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let currentLocation = locationService.currentLocation {
                        let distance = CLLocation(
                            latitude: waypoint.location.latitude,
                            longitude: waypoint.location.longitude
                        ).distance(from: currentLocation)
                        
                        Text("\(Int(distance))m away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isLeader && waypoint.isActive, let onComplete = onComplete {
                    Button(action: onComplete) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(waypoint.isActive ? Color.white : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(waypoint.isActive ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getTypeColor() -> Color {
        switch waypoint.type.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        default: return .blue
        }
    }
}