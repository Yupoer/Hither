//
//  HitherApp.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import FirebaseCore

@main
struct HitherApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var notificationService = NotificationService()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(notificationService)
                .onAppear {
                    setupNotifications()
                }
        }
    }
    
    private func setupNotifications() {
        Task {
            await notificationService.requestPermission()
            notificationService.setupNotificationCategories()
        }
    }
}
