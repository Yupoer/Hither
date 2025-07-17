//
//  Command.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation

enum CommandType: String, CaseIterable, Codable {
    case gather = "gather"
    case depart = "depart"
    case rest = "rest"
    case beCareful = "be_careful"
    case goLeft = "go_left"
    case goRight = "go_right"
    case stop = "stop"
    case hurryUp = "hurry_up"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .gather: return "Gather"
        case .depart: return "Depart"
        case .rest: return "Rest"
        case .beCareful: return "Be Careful"
        case .goLeft: return "Go Left"
        case .goRight: return "Go Right"
        case .stop: return "Stop"
        case .hurryUp: return "Hurry Up"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .gather: return "person.2.circle"
        case .depart: return "arrow.forward.circle"
        case .rest: return "pause.circle"
        case .beCareful: return "exclamationmark.triangle"
        case .goLeft: return "arrow.left.circle"
        case .goRight: return "arrow.right.circle"
        case .stop: return "stop.circle"
        case .hurryUp: return "forward.circle"
        case .custom: return "text.bubble"
        }
    }
    
    var defaultMessage: String {
        switch self {
        case .gather: return "Everyone gather here"
        case .depart: return "Let's move out"
        case .rest: return "Take a 5-minute break"
        case .beCareful: return "Be careful ahead"
        case .goLeft: return "Take the left path"
        case .goRight: return "Take the right path"
        case .stop: return "Stop where you are"
        case .hurryUp: return "Please catch up"
        case .custom: return ""
        }
    }
}

struct GroupCommand: Identifiable, Codable {
    let id: String
    let groupId: String
    let senderId: String
    let senderName: String
    let type: CommandType
    let message: String
    let timestamp: Date
    let location: GeoPoint?
    
    init(groupId: String, senderId: String, senderName: String, type: CommandType, message: String? = nil, location: GeoPoint? = nil) {
        self.id = UUID().uuidString
        self.groupId = groupId
        self.senderId = senderId
        self.senderName = senderName
        self.type = type
        self.message = message ?? type.defaultMessage
        self.timestamp = Date()
        self.location = location
    }
}

struct CommandNotification: Codable {
    let commandId: String
    let groupId: String
    let groupName: String
    let senderName: String
    let message: String
    let type: CommandType
    let timestamp: Date
}