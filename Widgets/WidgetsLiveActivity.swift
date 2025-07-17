//
//  WidgetsLiveActivity.swift
//  Widgets
//
//  Created by Dillion on 2025/7/17.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes

struct HitherGroupAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Progress and status
        let currentDistance: Double
        let totalDistance: Double
        let progressPercentage: Double
        
        // Group info
        let memberCount: Int
        let leaderName: String
        
        // Location info
        let currentLocationName: String?
        let destinationName: String
        
        // Status
        let isActive: Bool
        let lastCommand: String?
        let batteryLevel: Double?
        
        var distanceRemaining: Double {
            max(0, totalDistance - currentDistance)
        }
        
        var formattedCurrentDistance: String {
            if currentDistance < 1000 {
                return "\(Int(currentDistance))m"
            } else {
                return String(format: "%.1fkm", currentDistance / 1000)
            }
        }
        
        var formattedRemainingDistance: String {
            if distanceRemaining < 1000 {
                return "\(Int(distanceRemaining))m"
            } else {
                return String(format: "%.1fkm", distanceRemaining / 1000)
            }
        }
    }

    // Fixed properties about the activity
    let groupName: String
    let groupId: String
    let userRole: String // "leader" or "follower"
    let startLocationName: String
    let destinationName: String
}

// MARK: - Live Activity Widget

struct HitherGroupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HitherGroupAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI regions
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: context.attributes.userRole == "leader" ? "crown.fill" : "person.fill")
                                .foregroundColor(context.attributes.userRole == "leader" ? .yellow : .blue)
                                .font(.caption)
                            
                            Text(context.attributes.groupName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        Text("\(context.state.memberCount) members")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Active")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if let batteryLevel = context.state.batteryLevel {
                            HStack(spacing: 2) {
                                Image(systemName: getBatteryIcon(level: batteryLevel))
                                    .font(.caption2)
                                    .foregroundColor(getBatteryColor(level: batteryLevel))
                                Text("\(Int(batteryLevel * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(getBatteryColor(level: batteryLevel))
                            }
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        VStack(spacing: 4) {
                            HStack {
                                Text(context.attributes.startLocationName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(context.state.progressPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(context.state.destinationName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: context.state.progressPercentage / 100.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Traveled")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(context.state.formattedCurrentDistance)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Remaining")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(context.state.formattedRemainingDistance)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        if let command = context.state.lastCommand {
                            HStack {
                                Image(systemName: "megaphone.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                                
                                Text(command)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
            } compactLeading: {
                Image(systemName: context.attributes.userRole == "leader" ? "crown.fill" : "person.fill")
                    .foregroundColor(context.attributes.userRole == "leader" ? .yellow : .blue)
                    .font(.caption)
                
            } compactTrailing: {
                VStack(spacing: 1) {
                    Text("\(Int(context.state.progressPercentage))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                    
                    Text(context.state.formattedRemainingDistance)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
            } minimal: {
                Image(systemName: context.attributes.userRole == "leader" ? "crown.fill" : "person.fill")
                    .foregroundColor(context.attributes.userRole == "leader" ? .yellow : .blue)
            }
            .widgetURL(URL(string: "hither://group/\(context.attributes.groupId)"))
            .keylineTint(.blue)
        }
    }
    
    private func getBatteryIcon(level: Double) -> String {
        if level > 0.75 {
            return "battery.100"
        } else if level > 0.5 {
            return "battery.75"
        } else if level > 0.25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    private func getBatteryColor(level: Double) -> Color {
        if level > 0.3 {
            return .green
        } else if level > 0.15 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenActivityView: View {
    let context: ActivityViewContext<HitherGroupAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Group info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: context.attributes.userRole == "leader" ? "crown.fill" : "person.fill")
                        .foregroundColor(context.attributes.userRole == "leader" ? .yellow : .blue)
                        .font(.subheadline)
                    
                    Text(context.attributes.groupName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Text("\(context.state.memberCount) members • \(context.state.leaderName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let command = context.state.lastCommand {
                    HStack(spacing: 4) {
                        Image(systemName: "megaphone.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        
                        Text("📢 \(command)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Right side - Progress info
            VStack(alignment: .trailing, spacing: 4) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(context.state.progressPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Complete")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.formattedRemainingDistance)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(context.state.isActive ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(context.state.isActive ? "Live" : "Paused")
                        .font(.caption2)
                        .foregroundColor(context.state.isActive ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.05))
    }
}

// MARK: - Previews

extension HitherGroupAttributes {
    fileprivate static var preview: HitherGroupAttributes {
        HitherGroupAttributes(
            groupName: "Mountain Hike",
            groupId: "preview-group-id",
            userRole: "follower",
            startLocationName: "Trailhead",
            destinationName: "Summit"
        )
    }
    
    fileprivate static var leaderPreview: HitherGroupAttributes {
        HitherGroupAttributes(
            groupName: "City Tour",
            groupId: "leader-group-id",
            userRole: "leader",
            startLocationName: "Central Station",
            destinationName: "Museum"
        )
    }
}

extension HitherGroupAttributes.ContentState {
    fileprivate static var starting: HitherGroupAttributes.ContentState {
        HitherGroupAttributes.ContentState(
            currentDistance: 250,
            totalDistance: 5000,
            progressPercentage: 5,
            memberCount: 6,
            leaderName: "Alex",
            currentLocationName: "Trailhead Parking",
            destinationName: "Mountain Summit",
            isActive: true,
            lastCommand: "Let's go team!",
            batteryLevel: 0.85
        )
    }
    
    fileprivate static var midway: HitherGroupAttributes.ContentState {
        HitherGroupAttributes.ContentState(
            currentDistance: 2500,
            totalDistance: 5000,
            progressPercentage: 50,
            memberCount: 6,
            leaderName: "Alex",
            currentLocationName: "Rest Stop",
            destinationName: "Mountain Summit",
            isActive: true,
            lastCommand: "Take a 5-minute break",
            batteryLevel: 0.45
        )
    }
    
    fileprivate static var almostThere: HitherGroupAttributes.ContentState {
        HitherGroupAttributes.ContentState(
            currentDistance: 4200,
            totalDistance: 5000,
            progressPercentage: 84,
            memberCount: 5,
            leaderName: "Alex",
            currentLocationName: "Final Ascent",
            destinationName: "Mountain Summit",
            isActive: true,
            lastCommand: "Almost there!",
            batteryLevel: 0.25
        )
    }
}

#Preview("Notification", as: .content, using: HitherGroupAttributes.preview) {
   HitherGroupLiveActivity()
} contentStates: {
    HitherGroupAttributes.ContentState.starting
    HitherGroupAttributes.ContentState.midway
    HitherGroupAttributes.ContentState.almostThere
}

#Preview("Leader Notification", as: .content, using: HitherGroupAttributes.leaderPreview) {
   HitherGroupLiveActivity()
} contentStates: {
    HitherGroupAttributes.ContentState.starting
    HitherGroupAttributes.ContentState.midway
}
