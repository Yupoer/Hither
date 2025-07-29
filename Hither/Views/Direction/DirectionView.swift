//
//  DirectionView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import CoreLocation

struct DirectionView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var locationService = LocationService()
    @StateObject private var directionService: DirectionService
    @State private var isPrecisionFindingActive = false
    
    init() {
        let locationService = LocationService()
        self._locationService = StateObject(wrappedValue: locationService)
        self._directionService = StateObject(wrappedValue: DirectionService(locationService: locationService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let group = groupService.currentGroup,
                   let leader = group.leader,
                   let user = authService.currentUser,
                   user.id != leader.userId {
                    
                    // Follower view - show direction to leader
                    followerDirectionView(leader: leader)
                    
                } else if let group = groupService.currentGroup,
                          let user = authService.currentUser,
                          group.leader?.userId == user.id {
                    
                    // Leader view - show all followers
                    leaderDirectionView(group: group)
                    
                } else {
                    // No group or no leader
                    Text("join_group_to_see_directions".localized)
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            .padding()
            .navigationTitle("direction".localized)
            .onAppear {
                setupLocationTracking()
                updateLeaderLocation()
            }
            .onChange(of: groupService.currentGroup) { _ in
                updateLeaderLocation()
            }
        }
    }
    
    @ViewBuilder
    private func followerDirectionView(leader: GroupMember) -> some View {
        VStack(spacing: 30) {
            // Main compass arrow
            VStack(spacing: 16) {
                ZStack {
                    // Compass circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 200, height: 200)
                    
                    // Cardinal directions
                    ForEach(0..<4) { index in
                        Text(["N", "E", "S", "W"][index])
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .offset(y: -90)
                            .rotationEffect(.degrees(Double(index) * 90))
                    }
                    
                    // Direction arrow
                    Image(systemName: "arrow.up")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                        .rotationEffect(directionService.getDirectionArrowRotation())
                        .animation(.easeInOut(duration: 0.5), value: directionService.bearingToLeader)
                }
                
                // Distance display
                VStack(spacing: 8) {
                    Text(directionService.getDistanceString())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(String(format: "to_leader".localized, leader.displayName))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(directionService.getDirectionDescription())
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // Precision Finding section
            if directionService.isNearbyInteractionAvailable {
                VStack(spacing: 12) {
                    Text("precision_finding".localized)
                        .font(.headline)
                    
                    Text("precision_finding_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        togglePrecisionFinding()
                    }) {
                        HStack {
                            Image(systemName: isPrecisionFindingActive ? "dot.radiowaves.left.and.right" : "dot.radiowaves.forward")
                            Text(isPrecisionFindingActive ? "stop_precision_finding".localized : "start_precision_finding".localized)
                        }
                        .padding()
                        .background(isPrecisionFindingActive ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Status information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(locationService.isTracking ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(locationService.isTracking ? "location_active".localized : "location_inactive".localized)
                        .font(.caption)
                        .foregroundColor(locationService.isTracking ? .green : .red)
                    
                    Spacer()
                    
                    if !directionService.nearbyObjects.isEmpty {
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            
                            Text("precision_mode".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if let errorMessage = directionService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
    }
    
    @ViewBuilder
    private func leaderDirectionView(group: HitherGroup) -> some View {
        VStack(spacing: 20) {
            Text("team_overview".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("leader_monitor_message".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 12) {
                ForEach(group.followers) { follower in
                    FollowerStatusCard(
                        follower: follower,
                        locationService: locationService,
                        directionService: directionService
                    )
                }
            }
            
            if group.followers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("no_followers_yet".localized)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("share_invite_code_message".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
    
    private func setupLocationTracking() {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return }
        
        locationService.requestLocationPermission()
        locationService.startTracking(groupId: group.id, userId: user.id)
    }
    
    private func updateLeaderLocation() {
        guard let group = groupService.currentGroup,
              let leader = group.leader,
              let leaderLocation = leader.location else { return }
        
        directionService.setTargetLeader(location: leaderLocation.coordinate)
    }
    
    private func togglePrecisionFinding() {
        if isPrecisionFindingActive {
            directionService.stopNearbyInteraction()
            isPrecisionFindingActive = false
        } else {
            // In a real implementation, you'd exchange discovery tokens between devices
            // For now, we'll just simulate starting precision finding
            isPrecisionFindingActive = true
            
            // Request discovery token from leader (this would be done via Firestore)
            // directionService.startNearbyInteraction(with: leaderDiscoveryToken)
        }
    }
}

struct FollowerStatusCard: View {
    let follower: GroupMember
    let locationService: LocationService
    let directionService: DirectionService
    
    var body: some View {
        HStack(spacing: 12) {
            // Member icon
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(follower.displayName)
                    .font(.headline)
                
                if let location = follower.location,
                   let distance = locationService.calculateDistance(to: location.coordinate) {
                    Text(String(format: "meters_away".localized, Int(distance)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("location_unknown".localized)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(getStatusColor())
                    .frame(width: 12, height: 12)
                
                Text(getStatusText())
                    .font(.caption2)
                    .foregroundColor(getStatusColor())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func getStatusColor() -> Color {
        guard let lastUpdate = follower.lastLocationUpdate else { return .red }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        
        if timeSinceUpdate < 60 { // Less than 1 minute
            return .green
        } else if timeSinceUpdate < 300 { // Less than 5 minutes
            return .yellow
        } else {
            return .red
        }
    }
    
    private func getStatusText() -> String {
        guard let lastUpdate = follower.lastLocationUpdate else { return "no_data".localized }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        
        if timeSinceUpdate < 60 {
            return "live_status".localized
        } else if timeSinceUpdate < 300 {
            return String(format: "minutes_ago".localized, Int(timeSinceUpdate / 60))
        } else {
            return "stale_status".localized
        }
    }
}