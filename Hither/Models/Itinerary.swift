//
//  Itinerary.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import CoreLocation

enum WaypointType: String, CaseIterable, Codable {
    case meetingPoint = "meeting_point"
    case restStop = "rest_stop"
    case lunch = "lunch"
    case destination = "destination"
    case checkpoint = "checkpoint"
    case emergency = "emergency"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .meetingPoint: return "Meeting Point"
        case .restStop: return "Rest Stop"
        case .lunch: return "Lunch Spot"
        case .destination: return "Destination"
        case .checkpoint: return "Checkpoint"
        case .emergency: return "Emergency"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .meetingPoint: return "person.2.circle"
        case .restStop: return "pause.circle"
        case .lunch: return "fork.knife.circle"
        case .destination: return "flag.circle"
        case .checkpoint: return "checkmark.circle"
        case .emergency: return "cross.circle"
        case .custom: return "mappin.circle"
        }
    }
    
    var color: String {
        switch self {
        case .meetingPoint: return "blue"
        case .restStop: return "orange"
        case .lunch: return "green"
        case .destination: return "red"
        case .checkpoint: return "purple"
        case .emergency: return "red"
        case .custom: return "gray"
        }
    }
}

struct Waypoint: Identifiable, Codable {
    let id: String
    let groupId: String
    var name: String
    var description: String?
    let type: WaypointType
    var location: GeoPoint
    let createdAt: Date
    var updatedAt: Date
    let createdBy: String
    var isActive: Bool
    var order: Int
    
    init(
        groupId: String,
        name: String,
        description: String? = nil,
        type: WaypointType,
        location: GeoPoint,
        createdBy: String,
        order: Int = 0
    ) {
        self.id = UUID().uuidString
        self.groupId = groupId
        self.name = name
        self.description = description
        self.type = type
        self.location = location
        self.createdAt = Date()
        self.updatedAt = Date()
        self.createdBy = createdBy
        self.isActive = true
        self.order = order
    }
}

struct GroupItinerary: Identifiable, Codable {
    let id: String
    let groupId: String
    var waypoints: [Waypoint]
    let createdAt: Date
    var updatedAt: Date
    
    init(groupId: String) {
        self.id = UUID().uuidString
        self.groupId = groupId
        self.waypoints = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var activeWaypoints: [Waypoint] {
        waypoints.filter { $0.isActive }.sorted { $0.order < $1.order }
    }
    
    var nextWaypoint: Waypoint? {
        activeWaypoints.first
    }
    
    var completedWaypoints: [Waypoint] {
        waypoints.filter { !$0.isActive }.sorted { $0.order < $1.order }
    }
}

struct WaypointUpdate: Codable {
    let waypointId: String
    let groupId: String
    let action: WaypointAction
    let updatedBy: String
    let timestamp: Date
    
    enum WaypointAction: String, Codable {
        case added = "added"
        case updated = "updated"
        case removed = "removed"
        case completed = "completed"
        case reordered = "reordered"
    }
}