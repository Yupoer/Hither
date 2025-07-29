//
//  CommandsView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import CoreLocation
import UserNotifications

struct CommandsView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var commandService = CommandService()
    @StateObject private var locationService = LocationService()
    @State private var customMessage = ""
    @State private var showingCustomMessageSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let group = groupService.currentGroup,
                   let user = authService.currentUser,
                   group.leader?.userId == user.id {
                    
                    // Leader interface
                    leaderCommandInterface(group: group, user: user)
                    
                } else {
                    // Follower interface
                    followerCommandInterface()
                }
                
                Divider()
                
                // Command history for both roles
                commandHistorySection()
            }
            .navigationTitle("commands".localized)
            .onAppear {
                setupCommandService()
                setupNotifications()
            }
            .sheet(isPresented: $showingCustomMessageSheet) {
                customMessageSheet()
            }
        }
    }
    
    @ViewBuilder
    private func leaderCommandInterface(group: HitherGroup, user: HitherUser) -> some View {
        VStack(spacing: 16) {
            Text("send_commands_to_group".localized)
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(CommandType.leaderCommands.filter { $0 != .custom }, id: \.self) { commandType in
                    CommandButton(
                        type: commandType,
                        action: {
                            Task {
                                await sendQuickCommand(
                                    type: commandType,
                                    group: group,
                                    user: user
                                )
                            }
                        }
                    )
                }
                
                // Custom message button
                Button(action: {
                    showingCustomMessageSheet = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: CommandType.custom.icon)
                            .font(.title2)
                        
                        Text(CommandType.custom.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            if commandService.isLoading {
                SheepLoadingView(message: "sending_command".localized)
                    .padding()
            }
            
            if let errorMessage = commandService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    @ViewBuilder
    private func followerCommandInterface() -> some View {
        VStack(spacing: 16) {
            Text("send_requests_to_leader".localized)
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(CommandType.followerRequests, id: \.self) { commandType in
                    CommandButton(
                        type: commandType,
                        action: {
                            Task {
                                guard let group = groupService.currentGroup,
                                      let user = authService.currentUser else { return }
                                await sendQuickCommand(
                                    type: commandType,
                                    group: group,
                                    user: user
                                )
                            }
                        }
                    )
                }
                
                // Custom request button
                Button(action: {
                    showingCustomMessageSheet = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: CommandType.custom.icon)
                            .font(.title2)
                        
                        Text("custom_request".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            if commandService.isLoading {
                SheepLoadingView(message: "sending_request".localized)
                    .padding()
            }
            
            if let errorMessage = commandService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    @ViewBuilder
    private func commandHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("recent_commands".localized)
                    .font(.headline)
                
                Spacer()
                
                if !commandService.recentCommands.isEmpty {
                    Text("\(commandService.recentCommands.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if commandService.recentCommands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("no_commands_yet".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(commandService.recentCommands) { command in
                            CommandHistoryCard(command: command)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    @ViewBuilder
    private func customMessageSheet() -> some View {
        let isLeader = groupService.currentGroup?.leader?.userId == authService.currentUser?.id
        
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isLeader ? "custom_command".localized : "custom_request".localized)
                        .font(.headline)
                    
                    Text(isLeader ? "send_custom_command_subtitle".localized : "send_custom_request_subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField(isLeader ? "enter_command_placeholder".localized : "enter_request_placeholder".localized, text: $customMessage, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                Spacer()
                
                Button(action: {
                    Task {
                        guard let group = groupService.currentGroup,
                              let user = authService.currentUser else { return }
                        
                        await commandService.sendCustomCommand(
                            message: customMessage,
                            groupId: group.id,
                            groupName: group.name,
                            senderId: user.id,
                            senderName: user.displayName,
                            currentLocation: getCurrentLocation()
                        )
                        
                        customMessage = ""
                        showingCustomMessageSheet = false
                    }
                }) {
                    Text(isLeader ? "send_command".localized : "send_request".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(customMessage.isEmpty ? Color.gray : (isLeader ? Color.blue : Color.orange))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(customMessage.isEmpty || commandService.isLoading)
            }
            .padding()
            .navigationTitle(isLeader ? "custom_command".localized : "custom_request".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("cancel".localized) {
                    showingCustomMessageSheet = false
                    customMessage = ""
                }
            )
        }
    }
    
    private func setupCommandService() {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return }
        commandService.startListeningToCommands(groupId: group.id)
        commandService.startListeningToNotifications(groupId: group.id, userId: user.id)
    }
    
    private func setupNotifications() {
        commandService.setupNotificationCategories()
        Task {
            await commandService.requestNotificationPermission()
            
            // Debug: Check notification permission status
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            print("🔔 Notification permission status: \(settings.authorizationStatus)")
            
            if settings.authorizationStatus != .authorized {
                print("⚠️ Notifications not authorized - followers may not receive command notifications")
            }
        }
    }
    
    private func sendQuickCommand(type: CommandType, group: HitherGroup, user: HitherUser) async {
        await commandService.sendQuickCommand(
            type: type,
            groupId: group.id,
            groupName: group.name,
            senderId: user.id,
            senderName: user.displayName,
            currentLocation: getCurrentLocation()
        )
    }
    
    private func getCurrentLocation() -> GeoPoint? {
        guard let location = locationService.currentLocation else { return nil }
        return GeoPoint(from: location.coordinate)
    }
}

struct CommandButton: View {
    let type: CommandType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(getBackgroundColor())
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private func getBackgroundColor() -> Color {
        switch type {
        // Leader commands
        case .gather: return .blue
        case .depart: return .green
        case .rest: return .orange
        case .beCareful: return .red
        case .goLeft, .goRight: return .purple
        case .stop: return .red
        case .hurryUp: return .yellow
        case .custom: return .gray
        
        // Follower requests - use orange/yellow tones
        case .needRestroom: return .orange
        case .needBreak: return .yellow
        case .needHelp: return .red
        case .foundSomething: return .green
        }
    }
}

struct CommandHistoryCard: View {
    let command: GroupCommand
    @State private var currentTime = Date()
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Image(systemName: command.type.icon)
                    .font(.title3)
                    .foregroundColor(getIconColor())
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(command.senderName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTimestamp(command.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(command.message)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if command.type != .custom {
                    Text(command.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(getIconColor().opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            currentTime = Date()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    private func getIconColor() -> Color {
        switch command.type {
        // Leader commands
        case .gather: return .blue
        case .depart: return .green
        case .rest: return .orange
        case .beCareful: return .red
        case .goLeft, .goRight: return .purple
        case .stop: return .red
        case .hurryUp: return .yellow
        case .custom: return .gray
        
        // Follower requests
        case .needRestroom: return .orange
        case .needBreak: return .yellow
        case .needHelp: return .red
        case .foundSomething: return .green
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(timestamp)
        
        if timeInterval < 60 {
            return "now".localized
        } else if timeInterval < 3600 {
            return String(format: "minutes_ago_simple".localized, Int(timeInterval / 60))
        } else if Calendar.current.isDate(timestamp, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: timestamp)
        }
    }
}