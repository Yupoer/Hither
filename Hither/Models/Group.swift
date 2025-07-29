//
//  Group.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import CoreLocation

enum MemberRole: String, Codable, CaseIterable {
    case leader = "leader"
    case follower = "follower"
}

struct GroupMember: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let displayName: String
    var nickname: String?
    var avatarEmoji: String?
    let role: MemberRole
    let joinedAt: Date
    var location: GeoPoint?
    var lastLocationUpdate: Date?
    
    init(userId: String, displayName: String, role: MemberRole, nickname: String? = nil, avatarEmoji: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.displayName = displayName
        self.nickname = nickname
        self.avatarEmoji = avatarEmoji
        self.role = role
        self.joinedAt = Date()
        self.location = nil
        self.lastLocationUpdate = nil
    }
    
    init(id: String, userId: String, displayName: String, nickname: String? = nil, avatarEmoji: String? = nil, role: MemberRole, joinedAt: Date, location: GeoPoint? = nil, lastLocationUpdate: Date? = nil) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.nickname = nickname
        self.avatarEmoji = avatarEmoji
        self.role = role
        self.joinedAt = joinedAt
        self.location = location
        self.lastLocationUpdate = lastLocationUpdate
    }
}

struct GeoPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct HitherGroup: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let leaderId: String
    let createdAt: Date
    let inviteCode: String
    let inviteExpiresAt: Date
    var members: [GroupMember]
    var isActive: Bool
    
    init(name: String, leaderId: String, leaderName: String) {
        self.id = UUID().uuidString
        self.name = name
        self.leaderId = leaderId
        self.createdAt = Date()
        self.inviteCode = String.generateInviteCode()
        self.inviteExpiresAt = Date().addingTimeInterval(24 * 60 * 60) // 24 hours
        self.members = [GroupMember(userId: leaderId, displayName: leaderName, role: .leader)]
        self.isActive = true
    }
    
    init(id: String, name: String, leaderId: String, leaderName: String, createdAt: Date, inviteCode: String, inviteExpiresAt: Date, members: [GroupMember], isActive: Bool) {
        self.id = id
        self.name = name
        self.leaderId = leaderId
        self.createdAt = createdAt
        self.inviteCode = inviteCode
        self.inviteExpiresAt = inviteExpiresAt
        self.members = members
        self.isActive = isActive
    }
    
    var leader: GroupMember? {
        members.first { $0.role == .leader }
    }
    
    var followers: [GroupMember] {
        members.filter { $0.role == .follower }
    }
}

extension String {
    static func generateInviteCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}