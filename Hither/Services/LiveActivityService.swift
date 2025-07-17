//
//  LiveActivityService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
@MainActor
class LiveActivityService: ObservableObject {
    @Published var currentActivity: Activity<GroupTrackingAttributes>?
    @Published var isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
    @Published var errorMessage: String?
    
    private var groupId: String?
    private var userId: String?
    
    func startLiveActivity(
        groupName: String,
        groupId: String,
        userId: String,
        userRole: MemberRole,
        leaderName: String?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = "Live Activities are not enabled"
            return
        }
        
        self.groupId = groupId
        self.userId = userId
        
        let attributes = GroupTrackingAttributes(
            groupName: groupName,
            groupId: groupId,
            userRole: userRole
        )
        
        let initialState = GroupTrackingAttributes.ContentState(
            leaderName: leaderName ?? "Leader",
            memberCount: 1,
            distanceToLeader: nil,
            lastCommand: nil,
            nextWaypoint: nil,
            isTracking: false
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            currentActivity = activity
            
            // Monitor for push token
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.reduce("") { $0 + String(format: "%02x", $1) }
                print("Live Activity push token: \(tokenString)")
                // In a real app, you'd send this token to your server
            }
            
        } catch {
            errorMessage = "Failed to start Live Activity: \(error.localizedDescription)"
        }
    }
    
    func updateLiveActivity(
        leaderName: String? = nil,
        memberCount: Int? = nil,
        distanceToLeader: Double? = nil,
        lastCommand: String? = nil,
        nextWaypoint: String? = nil,
        isTracking: Bool? = nil
    ) async {
        guard let activity = currentActivity else { return }
        
        let currentState = activity.content.state
        
        let newState = GroupTrackingAttributes.ContentState(
            leaderName: leaderName ?? currentState.leaderName,
            memberCount: memberCount ?? currentState.memberCount,
            distanceToLeader: distanceToLeader ?? currentState.distanceToLeader,
            lastCommand: lastCommand ?? currentState.lastCommand,
            nextWaypoint: nextWaypoint ?? currentState.nextWaypoint,
            isTracking: isTracking ?? currentState.isTracking
        )
        
        do {
            await activity.update(.init(state: newState, staleDate: nil))
        } catch {
            errorMessage = "Failed to update Live Activity: \(error.localizedDescription)"
        }
    }
    
    func endLiveActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = GroupTrackingAttributes.ContentState(
            leaderName: activity.content.state.leaderName,
            memberCount: activity.content.state.memberCount,
            distanceToLeader: nil,
            lastCommand: "Group session ended",
            nextWaypoint: nil,
            isTracking: false
        )
        
        do {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
        } catch {
            errorMessage = "Failed to end Live Activity: \(error.localizedDescription)"
        }
    }
    
    func requestPermission() async {
        // ActivityKit doesn't require explicit permission request
        // but we can check if activities are enabled
        isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
        
        if !isSupported {
            errorMessage = "Live Activities are disabled in Settings"
        }
    }
}

// MARK: - Activity Attributes

struct GroupTrackingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let leaderName: String
        let memberCount: Int
        let distanceToLeader: Double?
        let lastCommand: String?
        let nextWaypoint: String?
        let isTracking: Bool
    }
    
    let groupName: String
    let groupId: String
    let userRole: MemberRole
}

// MARK: - Widget Configuration

@available(iOS 16.1, *)
struct GroupTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GroupTrackingAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.userRole == .leader ? "crown.fill" : "person.fill")
                            .foregroundColor(context.attributes.userRole == .leader ? .yellow : .blue)
                        Text(context.attributes.groupName)
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        Circle()
                            .fill(context.state.isTracking ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(context.state.isTracking ? "Live" : "Offline")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        if let distance = context.state.distanceToLeader {
                            Text("Distance to leader: \(Int(distance))m")
                                .font(.caption2)
                        }
                        
                        if let command = context.state.lastCommand {
                            Text("Latest: \(command)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let waypoint = context.state.nextWaypoint {
                            Text("Next: \(waypoint)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.userRole == .leader ? "crown.fill" : "person.fill")
                    .foregroundColor(context.attributes.userRole == .leader ? .yellow : .blue)
            } compactTrailing: {
                if let distance = context.state.distanceToLeader {
                    Text("\(Int(distance))m")
                        .font(.caption2)
                        .fontWeight(.semibold)
                } else {
                    Circle()
                        .fill(context.state.isTracking ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
            } minimal: {
                Image(systemName: context.attributes.userRole == .leader ? "crown.fill" : "person.fill")
                    .foregroundColor(context.attributes.userRole == .leader ? .yellow : .blue)
            }
        }
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<GroupTrackingAttributes>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: context.attributes.userRole == .leader ? "crown.fill" : "person.fill")
                        .foregroundColor(context.attributes.userRole == .leader ? .yellow : .blue)
                    
                    Text(context.attributes.groupName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("\(context.state.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let command = context.state.lastCommand {
                    Text("📢 \(command)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Circle()
                        .fill(context.state.isTracking ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(context.state.isTracking ? "Tracking" : "Offline")
                        .font(.caption)
                        .foregroundColor(context.state.isTracking ? .green : .red)
                }
                
                if let distance = context.state.distanceToLeader,
                   context.attributes.userRole == .follower {
                    Text("\(Int(distance))m to leader")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                if let waypoint = context.state.nextWaypoint {
                    Text("→ \(waypoint)")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
    }
}