//
//  ContentView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                GroupSetupView()
                    .environmentObject(authService)
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
