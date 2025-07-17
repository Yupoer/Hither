//
//  HitherApp.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import Foundation
import FirebaseCore
import GoogleSignIn

@main
struct HitherApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var notificationService = NotificationService()
    
    init() {
        FirebaseApp.configure()
        
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist not found or CLIENT_ID missing")
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
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
