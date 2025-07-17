//
//  GroupSetupView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI

struct GroupSetupView: View {
    @StateObject private var groupService = GroupService()
    @EnvironmentObject private var authService: AuthenticationService
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var showingJoinGroup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Create or Join Group")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Start your group adventure")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create New Group")
                            .font(.headline)
                        
                        TextField("Group Name (e.g., Hiking Adventure)", text: $groupName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            Task {
                                guard let user = authService.currentUser else { return }
                                await groupService.createGroup(
                                    name: groupName,
                                    leaderId: user.id,
                                    leaderName: user.displayName
                                )
                            }
                        }) {
                            Text("Create Group")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(groupService.isLoading || groupName.isEmpty)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join Existing Group")
                            .font(.headline)
                        
                        TextField("Invite Code", text: $inviteCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                        
                        Button(action: {
                            Task {
                                guard let user = authService.currentUser else { return }
                                await groupService.joinGroup(
                                    inviteCode: inviteCode.uppercased(),
                                    userId: user.id,
                                    userName: user.displayName
                                )
                            }
                        }) {
                            Text("Join Group")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(groupService.isLoading || inviteCode.isEmpty)
                    }
                }
                
                if groupService.isLoading {
                    ProgressView()
                        .padding()
                }
                
                if let errorMessage = groupService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Group Setup")
            .navigationBarItems(trailing: Button("Sign Out") {
                authService.signOut()
            })
        }
        .fullScreenCover(item: .constant(groupService.currentGroup)) { _ in
            MainTabView()
                .environmentObject(authService)
                .environmentObject(groupService)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var groupService: GroupService
    
    var body: some View {
        TabView {
            MapView()
                .environmentObject(authService)
                .environmentObject(groupService)
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
            
            DirectionView()
                .tabItem {
                    Image(systemName: "location.north")
                    Text("Direction")
                }
            
            GroupDetailsView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Group")
                }
        }
    }
}


struct DirectionView: View {
    var body: some View {
        Text("Direction View - Coming Soon")
            .navigationTitle("Direction")
    }
}

struct GroupDetailsView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    
    var body: some View {
        NavigationView {
            VStack {
                if let group = groupService.currentGroup {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group: \(group.name)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Invite Code: \(group.inviteCode)")
                                .font(.headline)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Members (\(group.members.count))")
                                .font(.headline)
                            
                            ForEach(group.members) { member in
                                HStack {
                                    Image(systemName: member.role == .leader ? "crown.fill" : "person.fill")
                                        .foregroundColor(member.role == .leader ? .yellow : .blue)
                                    
                                    Text(member.displayName)
                                    
                                    Spacer()
                                    
                                    Text(member.role.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(member.role == .leader ? Color.yellow.opacity(0.2) : Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                guard let user = authService.currentUser else { return }
                                await groupService.leaveGroup(userId: user.id)
                            }
                        }) {
                            Text("Leave Group")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                } else {
                    Text("No group found")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Group")
        }
    }
}