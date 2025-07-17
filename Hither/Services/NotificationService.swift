//
//  NotificationService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isEnabled = false
    @Published var errorMessage: String?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init() {
        checkAuthorizationStatus()
        notificationCenter.delegate = self
    }
    
    func requestPermission() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert]
            )
            
            authorizationStatus = granted ? .authorized : .denied
            isEnabled = granted
            
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            } else {
                errorMessage = "Notification permission denied. You may miss important group updates."
            }
        } catch {
            errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
        }
    }
    
    private func checkAuthorizationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            authorizationStatus = settings.authorizationStatus
            isEnabled = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleCommandNotification(
        command: GroupCommand,
        groupName: String
    ) async {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📢 Group Command"
        content.body = "\(command.senderName): \(command.message)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "GROUP_COMMAND"
        
        // Add custom data
        content.userInfo = [
            "commandId": command.id,
            "groupId": command.groupId,
            "groupName": groupName,
            "type": command.type.rawValue,
            "senderId": command.senderId
        ]
        
        let request = UNNotificationRequest(
            identifier: "command_\(command.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            errorMessage = "Failed to schedule command notification: \(error.localizedDescription)"
        }
    }
    
    func scheduleItineraryUpdateNotification(
        groupName: String,
        waypointName: String,
        action: String,
        updatedBy: String
    ) async {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🗺️ Itinerary Updated"
        
        let actionText = action == "added" ? "added" : action == "completed" ? "completed" : "updated"
        content.body = "\(updatedBy) \(actionText) waypoint: \(waypointName)"
        
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "ITINERARY_UPDATE"
        
        content.userInfo = [
            "groupName": groupName,
            "waypointName": waypointName,
            "action": action,
            "updatedBy": updatedBy
        ]
        
        let request = UNNotificationRequest(
            identifier: "itinerary_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            errorMessage = "Failed to schedule itinerary notification: \(error.localizedDescription)"
        }
    }
    
    func scheduleLocationAlertNotification(
        memberName: String,
        groupName: String,
        alertType: LocationAlertType
    ) async {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "LOCATION_ALERT"
        
        switch alertType {
        case .memberLost:
            content.title = "⚠️ Member Alert"
            content.body = "\(memberName) may be lost - no location update for 10+ minutes"
        case .memberTooFar:
            content.title = "📍 Distance Alert"
            content.body = "\(memberName) is more than 1km away from the group"
        case .groupScattered:
            content.title = "👥 Group Alert"
            content.body = "Group members are scattered - consider gathering"
        case .batteryLow:
            content.title = "🔋 Battery Alert"
            content.body = "Your battery is low - location tracking may be affected"
        }
        
        content.userInfo = [
            "memberName": memberName,
            "groupName": groupName,
            "alertType": alertType.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: "location_alert_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            errorMessage = "Failed to schedule location alert: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let commandCategory = UNNotificationCategory(
            identifier: "GROUP_COMMAND",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_COMMAND",
                    title: "View",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "ACKNOWLEDGE",
                    title: "Got it",
                    options: []
                )
            ],
            intentIdentifiers: []
        )
        
        let itineraryCategory = UNNotificationCategory(
            identifier: "ITINERARY_UPDATE",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_ITINERARY",
                    title: "View Itinerary",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: []
        )
        
        let locationCategory = UNNotificationCategory(
            identifier: "LOCATION_ALERT",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_MAP",
                    title: "View Map",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SEND_LOCATION",
                    title: "Share Location",
                    options: []
                )
            ],
            intentIdentifiers: []
        )
        
        notificationCenter.setNotificationCategories([
            commandCategory,
            itineraryCategory,
            locationCategory
        ])
    }
    
    // MARK: - Badge Management
    
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func updateBadge(count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    // MARK: - Cleanup
    
    func removeAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    func removeNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_COMMAND":
            // Navigate to commands view
            handleCommandNotificationTap(userInfo: userInfo)
        case "VIEW_ITINERARY":
            // Navigate to itinerary view
            handleItineraryNotificationTap(userInfo: userInfo)
        case "VIEW_MAP":
            // Navigate to map view
            handleLocationNotificationTap(userInfo: userInfo)
        case "ACKNOWLEDGE", "SEND_LOCATION":
            // Handle quick actions
            break
        case UNNotificationDefaultActionIdentifier:
            // Handle default tap
            handleDefaultNotificationTap(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleCommandNotificationTap(userInfo: [AnyHashable: Any]) {
        // In a real implementation, this would navigate to the commands tab
        print("Command notification tapped: \(userInfo)")
    }
    
    private func handleItineraryNotificationTap(userInfo: [AnyHashable: Any]) {
        // In a real implementation, this would navigate to the itinerary tab
        print("Itinerary notification tapped: \(userInfo)")
    }
    
    private func handleLocationNotificationTap(userInfo: [AnyHashable: Any]) {
        // In a real implementation, this would navigate to the map tab
        print("Location notification tapped: \(userInfo)")
    }
    
    private func handleDefaultNotificationTap(userInfo: [AnyHashable: Any]) {
        // In a real implementation, this would navigate to the appropriate tab
        print("Default notification tapped: \(userInfo)")
    }
}

// MARK: - Supporting Types

enum LocationAlertType: String, CaseIterable {
    case memberLost = "member_lost"
    case memberTooFar = "member_too_far"
    case groupScattered = "group_scattered"
    case batteryLow = "battery_low"
}