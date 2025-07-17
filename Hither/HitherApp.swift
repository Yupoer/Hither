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
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
