//
//  GroupSetupView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import FirebaseFirestore
import AudioToolbox
import VisionKit
import CoreImage
import UIKit

struct GroupSetupView: View {
    @StateObject private var groupService = GroupService()
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var locationService = LocationService()
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var showingJoinGroup = false
    @State private var showingOnboarding = false
    @State private var showingAllGroups = false
    @State private var showingEditNameSheet = false
    @State private var showingQRScanner = false
    @State private var createButtonPressed = false
    @State private var joinButtonPressed = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("create_or_join_group".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("start_group_adventure".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("create_new_group".localized)
                            .font(.headline)
                        
                        TextField("group_name_placeholder".localized, text: $groupName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            // Immediate feedback
                            createButtonPressed = true
                            
                            // Provide haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            Task {
                                guard let user = authService.currentUser else { return }
                                await groupService.createGroup(
                                    name: groupName,
                                    leaderId: user.id,
                                    leaderName: user.displayName
                                )
                                
                                // Reset button state
                                await MainActor.run {
                                    createButtonPressed = false
                                }
                            }
                        }) {
                            Text("create_group".localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(createButtonPressed ? Color.blue.opacity(0.7) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .scaleEffect(createButtonPressed ? 0.95 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: createButtonPressed)
                        }
                        .disabled(groupService.isLoading || groupName.isEmpty)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("join_existing_group".localized)
                            .font(.headline)
                        
                        TextField("invite_code".localized, text: $inviteCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                // Immediate feedback
                                joinButtonPressed = true
                                
                                // Provide haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                Task {
                                    guard let user = authService.currentUser else { return }
                                    await groupService.joinGroup(
                                        inviteCode: inviteCode.uppercased(),
                                        userId: user.id,
                                        userName: user.displayName
                                    )
                                    
                                    // Reset button state
                                    await MainActor.run {
                                        joinButtonPressed = false
                                    }
                                }
                            }) {
                                Text("join_group".localized)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(joinButtonPressed ? Color.green.opacity(0.7) : Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .scaleEffect(joinButtonPressed ? 0.95 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: joinButtonPressed)
                            }
                            .disabled(groupService.isLoading || inviteCode.isEmpty)
                            
                            Button(action: {
                                showingQRScanner = true
                            }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                if groupService.isLoading {
                    SheepLoadingView(message: "setting_up_group".localized)
                        .padding()
                }
                
                if let errorMessage = groupService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                // Show existing groups section
                if !groupService.allUserGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("your_groups_count".localized.replacingOccurrences(of: "%d", with: "\(groupService.allUserGroups.count)"))
                            .font(.headline)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(groupService.allUserGroups) { group in
                                Button(action: {
                                    // Join the selected group
                                    groupService.switchToGroup(group)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("\(group.members.count) members • \(group.leader?.displayName ?? "Unknown") leader")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Button("manage_all_groups".localized) {
                            showingAllGroups = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                }
                .padding()
            }
            .onTapGesture {
                // Dismiss keyboard when tapping blank space
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle("group_setup".localized)
            .navigationBarItems(
                leading: Button("help".localized) {
                    showingOnboarding = true
                },
                trailing: HStack(spacing: 16) {
                    LanguagePicker(languageService: languageService)
                    Button("sign_out".localized) {
                        authService.signOut()
                    }
                }
            )
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView(isPresented: $showingOnboarding)
            }
            .sheet(isPresented: $showingAllGroups) {
                AllGroupsView(groupService: groupService, authService: authService)
            }
            .sheet(isPresented: $showingEditNameSheet) {
                EditNameSheet(groupService: groupService, authService: authService)
            }
            .sheet(isPresented: $showingQRScanner) {
                NativeQRScannerView(
                    groupService: groupService,
                    authService: authService,
                    isPresented: $showingQRScanner
                )
            }
            .onAppear {
                setupGroupLoading()
                // Preload location services for better map performance
                locationService.preloadLocationServices()
            }
            .onChange(of: authService.currentUser) { user in
                if user != nil {
                    setupGroupLoading()
                }
            }
            .onChange(of: groupService.currentGroup) { group in
                if group == nil {
                    // Clear input fields when returning from group page
                    groupName = ""
                    inviteCode = ""
                }
            }
            .onDisappear {
                groupService.stopListeningToUserGroups()
            }
        }
        .fullScreenCover(item: .constant(groupService.currentGroup)) { _ in
            MainTabView()
                .environmentObject(authService)
                .environmentObject(groupService)
        }
    }
    
    private func setupGroupLoading() {
        // Clear input fields when returning to setup
        groupName = ""
        inviteCode = ""
        
        if let user = authService.currentUser {
            Task {
                print("🔄 Loading user groups for: \(user.displayName)")
                await groupService.loadUserGroups(userId: user.id)
                groupService.startListeningToUserGroups(userId: user.id)
                
                // Check for pending invite code after login
                if let pendingCode = UserDefaults.standard.string(forKey: "pendingInviteCode") {
                    print("🔗 Processing pending invite code: \(pendingCode)")
                    await groupService.joinGroup(
                        inviteCode: pendingCode,
                        userId: user.id,
                        userName: user.displayName
                    )
                    
                    // Clear the pending data
                    UserDefaults.standard.removeObject(forKey: "pendingInviteCode")
                    UserDefaults.standard.removeObject(forKey: "pendingGroupName")
                }
            }
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
                    Text("map".localized)
                }
            
            DirectionView()
                .tabItem {
                    Image(systemName: "location.north")
                    Text("direction".localized)
                }
            
            ItineraryView()
                .environmentObject(authService)
                .environmentObject(groupService)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("itinerary".localized)
                }
            
            CommandsView()
                .environmentObject(authService)
                .environmentObject(groupService)
                .tabItem {
                    Image(systemName: "megaphone")
                    Text("commands".localized)
                }
            
            GroupDetailsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("settings".localized)
                }
        }
    }
}



struct GroupDetailsView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var languageService: LanguageService
    @State private var showingInviteSheet = false
    @State private var showingLeaveAlert = false
    @State private var showingEditNameSheet = false
    
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
                        
                        // Quick actions for both leaders and followers
                        quickActionsSection(group: group, currentUser: user)
                        
                        Spacer(minLength: 20)
                        
                        // Group Setup button
                        Button(action: {
                            groupService.navigateToSetup()
                        }) {
                            Text("group_setup".localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        // Leave group button
                        Button(action: {
                            showingLeaveAlert = true
                        }) {
                            Text("leave_group".localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        Text("no_group_found".localized)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("settings".localized)
            .navigationBarItems(trailing: LanguagePicker(languageService: languageService))
            .refreshable {
                await refreshGroupData()
            }
            .sheet(isPresented: $showingInviteSheet) {
                if let group = groupService.currentGroup {
                    InviteSheet(group: group, groupService: groupService)
                }
            }
            .alert("leave_group".localized, isPresented: $showingLeaveAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("leave".localized, role: .destructive) {
                    Task {
                        guard let user = authService.currentUser else { return }
                        await groupService.leaveGroup(userId: user.id)
                    }
                }
            } message: {
                Text("leave_group_confirmation".localized)
            }
            .sheet(isPresented: $showingEditNameSheet) {
                EditNameSheet(groupService: groupService, authService: authService)
            }
        }
    }
    
    @ViewBuilder
    private func leaderInviteSection(group: HitherGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("invite_members".localized)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("invite_code".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(group.inviteCode)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button("share".localized) {
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
            Text("members_count".localized.replacingOccurrences(of: "%d", with: "\(group.members.count)"))
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(sortedMembers(group.members, currentUserId: currentUser.id)) { member in
                    MemberRowView(
                        member: member, 
                        isCurrentUser: member.userId == currentUser.id,
                        groupService: groupService,
                        authService: authService
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func quickActionsSection(group: HitherGroup, currentUser: HitherUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("quick_actions".localized)
                .font(.headline)
            
            let quickActions = createQuickActionButtons(group: group, currentUser: currentUser)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<quickActions.count, id: \.self) { index in
                    quickActions[index]
                }
            }
        }
    }
    
    private func createQuickActionButtons(group: HitherGroup, currentUser: HitherUser) -> [QuickActionButton] {
        var buttons: [QuickActionButton] = []
        let isLeader = group.leader?.userId == currentUser.id
        
        // Leader-only buttons
        if isLeader {
            buttons.append(QuickActionButton(
                icon: "arrow.clockwise",
                title: "new_invite_code".localized,
                color: .orange
            ) {
                Task {
                    await groupService.generateNewInviteCode()
                }
            })
        }
        
        
        
        // Live Activity controls - available for both roles
        if #available(iOS 16.1, *) {
            buttons.append(QuickActionButton(
                icon: "bell.badge",
                title: "Start Live Activity",
                color: .blue
            ) {
                Task {
                    let liveActivityService = LiveActivityService()
                    
                    await liveActivityService.startNavigationLiveActivity(
                        groupName: group.name,
                        groupId: group.id,
                        userId: currentUser.id,
                        userRole: isLeader ? "leader" : "follower",
                        leaderName: group.leader?.displayName ?? "Unknown",
                        memberCount: group.members.count,
                        groupStatus: "waiting",
                        message: "Ready for navigation"
                    )
                }
            })
            
        }
        
        // Debug buttons - leader only
        if isLeader {
            
            buttons.append(QuickActionButton(
                icon: "stethoscope",
                title: "Diagnose Data",
                color: .purple
            ) {
                Task {
                    await groupService.diagnoseGroupData(groupId: group.id)
                }
            })
        }
        
        return buttons
    }
    
    private func refreshGroupData() async {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return }
        
        print("🔄 Refreshing group data...")
        
        // Refresh the current group data
        await groupService.refreshCurrentGroup()
        
        // Also refresh user's group list
        await groupService.loadUserGroups(userId: user.id)
    }
    
    private func sortedMembers(_ members: [GroupMember], currentUserId: String) -> [GroupMember] {
        return members.sorted { member1, member2 in
            // Current user always comes first
            if member1.userId == currentUserId && member2.userId != currentUserId {
                return true
            }
            if member2.userId == currentUserId && member1.userId != currentUserId {
                return false
            }
            
            // If neither or both are current user, sort by display name
            let name1 = member1.nickname ?? member1.displayName
            let name2 = member2.nickname ?? member2.displayName
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
}

struct MemberRowView: View {
    let member: GroupMember
    let isCurrentUser: Bool
    @ObservedObject var groupService: GroupService
    @ObservedObject var authService: AuthenticationService
    @State private var showingEditNameSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Show emoji avatar if available, otherwise show role indicator
            if let emoji = member.avatarEmoji {
                Text(emoji)
                    .font(.title2)
                    .frame(width: 32, height: 32)
            } else {
                RoleIndicatorView(role: member.role, size: 32)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.nickname ?? member.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isCurrentUser {
                        Text("you_indicator".localized)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .italic()
                        
                        // Rename circle button next to my name
                        Button(action: {
                            showingEditNameSheet = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastUpdate = member.lastLocationUpdate {
                    let timeAgo = Date().timeIntervalSince(lastUpdate)
                    if timeAgo < 60 {
                        StatusIndicatorView(isActive: true, title: "location_live".localized)
                    } else if timeAgo < 300 {
                        StatusIndicatorView(isActive: false, title: String(format: "last_seen_minutes_ago".localized, Int(timeAgo/60)))
                    } else {
                        StatusIndicatorView(isActive: false, title: "location_stale".localized)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrentUser ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .sheet(isPresented: $showingEditNameSheet) {
            EditNameSheet(groupService: groupService, authService: authService)
        }
    }
}

struct InviteSheet: View {
    let group: HitherGroup
    @ObservedObject var groupService: GroupService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    @State private var qrCodeImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text(String(format: "invite_to_group".localized, group.name))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("share_code_message".localized)
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
                    
                    // QR Code display
                    if let qrCodeImage = qrCodeImage {
                        Image(uiImage: qrCodeImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .background(Color.white)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .overlay(
                                SheepLoadingView(message: "Generating QR Code...")
                            )
                    }
                }
                
                VStack(spacing: 12) {
                    Button("Share Invite Link") {
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
                            generateQRCode()
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
                    activityItems: [shareURL, shareText]
                )
            }
            .onAppear {
                generateQRCode()
            }
        }
    }
    
    private var shareURL: URL {
        // Create deep link URL for the app
        let encodedName = group.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? group.name
        let urlString = "hither://join?code=\(group.inviteCode)&name=\(encodedName)"
        
        print("🔍 ShareURL Generation:")
        print("  - Group Name: '\(group.name)'")
        print("  - Encoded Name: '\(encodedName)'")
        print("  - Invite Code: '\(group.inviteCode)'")
        print("  - URL String: '\(urlString)'")
        
        if let primaryURL = URL(string: urlString) {
            print("  - Primary URL created successfully: \(primaryURL.absoluteString)")
            return primaryURL
        } else {
            print("  - ⚠️ Primary URL creation failed, using fallback")
            let fallbackString = "https://hither.app/join?code=\(group.inviteCode)"
            print("  - Fallback URL String: '\(fallbackString)'")
            return URL(string: fallbackString)!
        }
    }
    
    private var shareText: String {
        "Join my group '\(group.name)' on Hither! Use invite code: \(group.inviteCode) or click this link: \(shareURL.absoluteString)"
    }
    
    private func generateQRCode() {
        let urlString = shareURL.absoluteString
        print("🔍 QR Code Generation Process:")
        print("  - URL String: \(urlString)")
        print("  - URL String Length: \(urlString.count)")
        
        guard let qrCodeData = urlString.data(using: .utf8) else {
            print("❌ Failed to create QR code data from URL string")
            return
        }
        
        print("  - Data Size: \(qrCodeData.count) bytes")
        print("  - Data String: \(String(data: qrCodeData, encoding: .utf8) ?? "Unable to convert back")")
        
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
            print("❌ Failed to create QR filter - CIQRCodeGenerator not available")
            return
        }
        
        print("  - QR Filter created successfully")
        
        qrFilter.setValue(qrCodeData, forKey: "inputMessage")
        qrFilter.setValue("H", forKey: "inputCorrectionLevel")
        
        print("  - QR Filter configured with data and correction level H")
        
        guard let qrCodeCIImage = qrFilter.outputImage else {
            print("❌ Failed to generate QR code image from filter")
            print("  - Filter parameters: \(qrFilter.attributes)")
            return
        }
        
        print("  - QR Code CIImage generated successfully")
        print("  - Original extent: \(qrCodeCIImage.extent)")
        
        // Scale up the QR code
        let targetSize: CGFloat = 200
        let scaleX = targetSize / qrCodeCIImage.extent.size.width
        let scaleY = targetSize / qrCodeCIImage.extent.size.height
        
        print("  - Scale factors: X=\(scaleX), Y=\(scaleY)")
        
        let scaledQRImage = qrCodeCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        print("  - Scaled extent: \(scaledQRImage.extent)")
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledQRImage, from: scaledQRImage.extent) else {
            print("❌ Failed to create CG image from scaled QR image")
            return
        }
        
        print("  - CGImage created successfully")
        
        let finalImage = UIImage(cgImage: cgImage)
        print("  - Final UIImage size: \(finalImage.size)")
        
        DispatchQueue.main.async {
            self.qrCodeImage = finalImage
            print("✅ QR Code generated and assigned successfully")
        }
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

struct AllGroupsView: View {
    @ObservedObject var groupService: GroupService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingLeaveAlert = false
    @State private var groupToLeave: HitherGroup?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(groupService.allUserGroups) { group in
                        GroupCard(
                            group: group,
                            currentUser: authService.currentUser!,
                            isCurrentGroup: groupService.currentGroup?.id == group.id,
                            onJoin: {
                                groupService.switchToGroup(group)
                                presentationMode.wrappedValue.dismiss()
                            },
                            onLeave: {
                                groupToLeave = group
                                showingLeaveAlert = true
                            }
                        )
                    }
                    
                    if groupService.allUserGroups.isEmpty {
                        Text("not_in_any_groups".localized)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("all_groups".localized)
            .navigationBarItems(
                trailing: Button("done".localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("leave_group_alert".localized, isPresented: $showingLeaveAlert) {
                Button("cancel".localized, role: .cancel) {
                    groupToLeave = nil
                }
                Button("leave".localized, role: .destructive) {
                    if let group = groupToLeave,
                       let user = authService.currentUser {
                        Task {
                            await groupService.leaveSpecificGroup(groupId: group.id, userId: user.id)
                        }
                    }
                    groupToLeave = nil
                }
            } message: {
                if let group = groupToLeave {
                    Text(String(format: "leave_specific_group_confirmation".localized, group.name))
                }
            }
        }
    }
}

struct GroupCard: View {
    let group: HitherGroup
    let currentUser: HitherUser
    let isCurrentGroup: Bool
    let onJoin: () -> Void
    let onLeave: () -> Void
    
    var userRole: MemberRole? {
        group.members.first { $0.userId == currentUser.id }?.role
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                    
                    Text(String(format: "members_count_simple".localized, group.members.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let role = userRole {
                    RoleIndicatorView(role: role, size: 24)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "leader_prefix".localized, group.leader?.displayName ?? "Unknown"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "created_date".localized, formattedDate(group.createdAt)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !isCurrentGroup {
                        Button("switch_to".localized) {
                            onJoin()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    } else {
                        Text("current_group_indicator".localized)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    }
                    
                    Button("leave".localized) {
                        onLeave()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct EditNameSheet: View {
    @ObservedObject var groupService: GroupService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.presentationMode) var presentationMode
    @State private var newDisplayName = ""
    @State private var selectedEmoji: String?
    @State private var showingEmojiPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("edit_nickname_title".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("update_nickname_subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("nickname_label".localized)
                            .font(.headline)
                        
                        TextField("enter_nickname_placeholder".localized, text: $newDisplayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("avatar_emoji_label".localized)
                            .font(.headline)
                        
                        HStack {
                            Button(action: {
                                showingEmojiPicker = true
                            }) {
                                HStack {
                                    if let emoji = selectedEmoji {
                                        Text(emoji)
                                            .font(.title)
                                    } else {
                                        Image(systemName: "person.circle")
                                            .font(.title)
                                            .foregroundColor(.gray)
                                    }
                                    Text(selectedEmoji != nil ? "change_avatar".localized : "select_avatar".localized)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            if selectedEmoji != nil {
                                Button("remove_avatar".localized) {
                                    selectedEmoji = nil
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                .onAppear {
                    // Load current member's data
                    if let group = groupService.currentGroup,
                       let user = authService.currentUser,
                       let member = group.members.first(where: { $0.userId == user.id }) {
                        newDisplayName = member.nickname ?? member.displayName
                        selectedEmoji = member.avatarEmoji
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    Task {
                        await updateDisplayName()
                    }
                }) {
                    if isLoading {
                        SheepProgressView(tint: .white)
                    } else {
                        Text("update_nickname_button".localized)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(newDisplayName.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(newDisplayName.isEmpty || isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("edit_nickname_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("cancel".localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiAvatarPicker(currentEmoji: selectedEmoji) { emoji in
                    selectedEmoji = emoji
                }
            }
        }
    }
    
    private func updateDisplayName() async {
        guard let user = authService.currentUser,
              let group = groupService.currentGroup else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update Firebase using the correct subcollection structure
            // Update the specific user's data in the users subcollection
            var updateData: [String: Any] = [
                "nickname": newDisplayName,
                "displayName": newDisplayName  // Also update displayName for consistency
            ]
            
            // Add or remove avatar emoji
            if let emoji = selectedEmoji {
                updateData["avatarEmoji"] = emoji
            } else {
                updateData["avatarEmoji"] = FieldValue.delete()
            }
            
            // Update the user document in the users subcollection
            try await Firestore.firestore()
                .collection("groups")
                .document(group.id)
                .collection("users")
                .document(user.id)
                .updateData(updateData)
            
            print("✅ Successfully updated nickname to: \(newDisplayName) and avatar emoji to: \(selectedEmoji ?? "none") for user: \(user.id) in users subcollection")
            
            // Refresh group data to ensure UI updates immediately
            await groupService.refreshCurrentGroup()
            
            presentationMode.wrappedValue.dismiss()
            
        } catch {
            errorMessage = "Failed to update nickname: \(error.localizedDescription)"
            print("❌ Failed to update nickname: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

// Using native camera app for QR code scanning
struct NativeQRScannerView: View {
    @ObservedObject var groupService: GroupService
    @ObservedObject var authService: AuthenticationService
    @Binding var isPresented: Bool
    @State private var scannedCode: String?
    @State private var showingJoinAlert = false
    @State private var errorMessage: String?
    @State private var showingNativeScannerTip = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if showingNativeScannerTip {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("scan_qr_with_camera".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("camera_instructions".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("instructions_header".localized)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("step_1".localized)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("open_camera_app".localized)
                                    .font(.subheadline)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("step_2".localized)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("point_camera_at_qr".localized)
                                    .font(.subheadline)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("step_3".localized)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("tap_notification".localized)
                                    .font(.subheadline)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("step_4".localized)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("select_open_in_hither".localized)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Button("Open Camera App") {
                            openCameraApp()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    isPresented = false
                }
            )
            .alert("Join Group", isPresented: $showingJoinAlert) {
                Button("Join") {
                    if let code = scannedCode,
                       let user = authService.currentUser {
                        Task {
                            await groupService.joinGroup(
                                inviteCode: code,
                                userId: user.id,
                                userName: user.displayName
                            )
                            isPresented = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    scannedCode = nil
                }
            } message: {
                Text("join_group_question".localized)
            }
        }
    }
    
    private func openCameraApp() {
        print("🔍 Opening Camera App...")
        
        // Try to open the camera app
        if let cameraURL = URL(string: "camera://") {
            if UIApplication.shared.canOpenURL(cameraURL) {
                UIApplication.shared.open(cameraURL) { success in
                    print("📷 Camera app opened: \(success)")
                    if success {
                        // Close the scanner sheet as user is now using camera app
                        DispatchQueue.main.async {
                            isPresented = false
                        }
                    }
                }
            } else {
                print("❌ Cannot open camera app with URL scheme")
                // Fallback: just close the sheet and let user manually open camera
                isPresented = false
            }
        } else {
            print("❌ Invalid camera URL")
            // Fallback: just close the sheet
            isPresented = false
        }
    }
}

// Removed custom camera implementation as we're now using native camera app