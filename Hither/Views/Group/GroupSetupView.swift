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
    @State private var showingOnboarding = false
    
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
            .navigationBarItems(
                leading: Button("Help") {
                    showingOnboarding = true
                },
                trailing: Button("Sign Out") {
                    authService.signOut()
                }
            )
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView(isPresented: $showingOnboarding)
            }
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
            
            ItineraryView()
                .environmentObject(authService)
                .environmentObject(groupService)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Itinerary")
                }
            
            CommandsView()
                .environmentObject(authService)
                .environmentObject(groupService)
                .tabItem {
                    Image(systemName: "megaphone")
                    Text("Commands")
                }
            
            GroupDetailsView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Group")
                }
        }
    }
}



struct GroupDetailsView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @State private var showingInviteSheet = false
    @State private var showingLeaveAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let group = groupService.currentGroup,
                       let user = authService.currentUser {
                        
                        // Group header
                        GroupHeaderView(group: group, currentUser: user)
                        
                        // Invite section (Leader only)
                        if group.leader?.userId == user.id {
                            leaderInviteSection(group: group)
                        }
                        
                        // Members section
                        membersSection(group: group, currentUser: user)
                        
                        // Quick actions
                        if group.leader?.userId == user.id {
                            leaderQuickActions()
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Leave group button
                        Button(action: {
                            showingLeaveAlert = true
                        }) {
                            Text("Leave Group")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        Text("No group found")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Group")
            .sheet(isPresented: $showingInviteSheet) {
                if let group = groupService.currentGroup {
                    InviteSheet(group: group, groupService: groupService)
                }
            }
            .alert("Leave Group", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task {
                        guard let user = authService.currentUser else { return }
                        await groupService.leaveGroup(userId: user.id)
                    }
                }
            } message: {
                Text("Are you sure you want to leave this group? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private func leaderInviteSection(group: HitherGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Members")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite Code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(group.inviteCode)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button("Share") {
                    showingInviteSheet = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func membersSection(group: HitherGroup, currentUser: HitherUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members (\(group.members.count))")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(group.members) { member in
                    MemberRowView(member: member, isCurrentUser: member.userId == currentUser.id)
                }
            }
        }
    }
    
    @ViewBuilder
    private func leaderQuickActions() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    icon: "qrcode",
                    title: "Share QR Code",
                    color: .green
                ) {
                    showingInviteSheet = true
                }
                
                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "New Invite Code",
                    color: .orange
                ) {
                    Task {
                        await groupService.generateNewInviteCode()
                    }
                }
                
                QuickActionButton(
                    icon: "megaphone",
                    title: "Broadcast",
                    color: .purple
                ) {
                    // Switch to Commands tab
                }
                
                Spacer()
            }
        }
    }
}

struct MemberRowView: View {
    let member: GroupMember
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            RoleIndicatorView(role: member.role, size: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .italic()
                    }
                }
                
                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastUpdate = member.lastLocationUpdate {
                    let timeAgo = Date().timeIntervalSince(lastUpdate)
                    if timeAgo < 60 {
                        StatusIndicatorView(isActive: true, title: "Location Live")
                    } else if timeAgo < 300 {
                        StatusIndicatorView(isActive: false, title: "Last seen \(Int(timeAgo/60))m ago")
                    } else {
                        StatusIndicatorView(isActive: false, title: "Location stale")
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrentUser ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}

struct InviteSheet: View {
    let group: HitherGroup
    @ObservedObject var groupService: GroupService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Invite to \(group.name)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Share this code with others to join your group")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    Text(group.inviteCode)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    
                    // QR Code placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("QR Code")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                VStack(spacing: 12) {
                    Button("Share Invite Code") {
                        showingShareSheet = true
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Generate New Code") {
                        Task {
                            await groupService.generateNewInviteCode()
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Invite Members")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(
                    activityItems: [shareText]
                )
            }
        }
    }
    
    private var shareText: String {
        "Join my group '\(group.name)' on Hither! Use invite code: \(group.inviteCode)"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}