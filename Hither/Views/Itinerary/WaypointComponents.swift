//
//  WaypointComponents.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import CoreLocation

struct WaypointCard: View {
    let waypoint: Waypoint
    let locationService: LocationService
    let isLeader: Bool
    let onTap: () -> Void
    let onComplete: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Waypoint icon
                Image(systemName: waypoint.type.icon)
                    .foregroundColor(getTypeColor())
                    .font(.title2)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(waypoint.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let description = waypoint.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(waypoint.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let userLocation = locationService.currentLocation {
                        let distance = userLocation.distance(from: CLLocation(latitude: waypoint.location.latitude, longitude: waypoint.location.longitude))
                        Text(LocationService.formatDistance(distance))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    if waypoint.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if waypoint.isInProgress {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                if isLeader && waypoint.isActive && !waypoint.isCompleted && onComplete != nil {
                    Button(action: { onComplete?() }) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
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

struct NextWaypointCard: View {
    let waypoint: Waypoint
    let locationService: LocationService
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(waypoint.isInProgress ? "Current Destination" : "Next Destination")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 16) {
                Image(systemName: waypoint.type.icon)
                    .foregroundColor(getTypeColor())
                    .font(.largeTitle)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(waypoint.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let description = waypoint.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(waypoint.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let userLocation = locationService.currentLocation {
                        let distance = userLocation.distance(from: CLLocation(latitude: waypoint.location.latitude, longitude: waypoint.location.longitude))
                        
                        Text(LocationService.formatDistance(distance))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        // Simple direction indicator
                        Image(systemName: "arrow.up")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(getBearing(from: userLocation, to: CLLocation(latitude: waypoint.location.latitude, longitude: waypoint.location.longitude))))
                    }
                }
            }
        }
        .padding()
        .background(waypoint.isInProgress ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(waypoint.isInProgress ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
        )
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
    
    private func getBearing(from: CLLocation, to: CLLocation) -> Double {
        let lat1 = from.coordinate.latitude * .pi / 180
        let lat2 = to.coordinate.latitude * .pi / 180
        let deltaLon = (to.coordinate.longitude - from.coordinate.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}