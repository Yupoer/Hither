//
//  CommandService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import FirebaseFirestore
import UserNotifications

@MainActor
class CommandService: ObservableObject {
    @Published var recentCommands: [GroupCommand] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var commandsListener: ListenerRegistration?
    
    deinit {
        commandsListener?.remove()
    }
    
    func startListeningToCommands(groupId: String) {
        commandsListener?.remove()
        
        commandsListener = db.collection("groups")
            .document(groupId)
            .collection("commands")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = "Failed to sync commands: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self?.recentCommands = documents.compactMap { document in
                        self?.parseCommandFromDocument(document)
                    }
                }
            }
    }
    
    func stopListeningToCommands() {
        commandsListener?.remove()
        commandsListener = nil
        recentCommands.removeAll()
    }
    
    func sendQuickCommand(
        type: CommandType,
        groupId: String,
        senderId: String,
        senderName: String,
        currentLocation: GeoPoint? = nil
    ) async {
        await sendCommand(
            type: type,
            message: type.defaultMessage,
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            currentLocation: currentLocation
        )
    }
    
    func sendCustomCommand(
        message: String,
        groupId: String,
        senderId: String,
        senderName: String,
        currentLocation: GeoPoint? = nil
    ) async {
        await sendCommand(
            type: .custom,
            message: message,
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            currentLocation: currentLocation
        )
    }
    
    private func sendCommand(
        type: CommandType,
        message: String,
        groupId: String,
        senderId: String,
        senderName: String,
        currentLocation: GeoPoint?
    ) async {
        isLoading = true
        errorMessage = nil
        
        let command = GroupCommand(
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            type: type,
            message: message,
            location: currentLocation
        )
        
        do {
            // Save command to Firestore
            try await db.collection("groups")
                .document(groupId)
                .collection("commands")
                .document(command.id)
                .setData([
                    "id": command.id,
                    "groupId": command.groupId,
                    "senderId": command.senderId,
                    "senderName": command.senderName,
                    "type": command.type.rawValue,
                    "message": command.message,
                    "timestamp": Timestamp(date: command.timestamp),
                    "location": command.location?.toFirestoreData() ?? NSNull()
                ])
            
            // Send push notification to group members
            await sendPushNotificationToGroup(command: command)
            
        } catch {
            errorMessage = "Failed to send command: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func sendPushNotificationToGroup(command: GroupCommand) async {
        // In a real implementation, this would trigger a Cloud Function
        // that sends FCM notifications to all group members except the sender
        
        // For now, we'll trigger a local notification to simulate
        await scheduleLocalNotification(for: command)
    }
    
    private func scheduleLocalNotification(for command: GroupCommand) async {
        let content = UNMutableNotificationContent()
        content.title = "📢 Group Command"
        content.body = "\(command.senderName): \(command.message)"
        content.sound = .default
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "commandId": command.id,
            "groupId": command.groupId,
            "type": command.type.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: command.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule local notification: \(error)")
        }
    }
    
    private func parseCommandFromDocument(_ document: QueryDocumentSnapshot) -> GroupCommand? {
        let data = document.data()
        
        guard let id = data["id"] as? String,
              let groupId = data["groupId"] as? String,
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let typeString = data["type"] as? String,
              let type = CommandType(rawValue: typeString),
              let message = data["message"] as? String,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        var location: GeoPoint? = nil
        if let locationData = data["location"] as? [String: Any],
           let lat = locationData["latitude"] as? Double,
           let lng = locationData["longitude"] as? Double {
            location = GeoPoint(latitude: lat, longitude: lng)
        }
        
        return GroupCommand(
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            type: type,
            message: message,
            location: location
        )
    }
    
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            if !granted {
                errorMessage = "Notification permission denied. You may miss important group updates."
            }
        } catch {
            errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
        }
    }
}

extension GeoPoint {
    func toFirestoreData() -> [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude
        ]
    }
}