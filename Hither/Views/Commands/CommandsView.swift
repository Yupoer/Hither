//
//  CommandsView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import CoreLocation

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
            .navigationTitle("Commands")
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
            Text("Send Commands to Group")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(CommandType.allCases.filter { $0 != .custom }, id: \.self) { commandType in
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
                ProgressView("Sending command...")
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
            VStack(spacing: 8) {
                Image(systemName: "ear")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Listening for Commands")
                    .font(.headline)
                
                Text("You'll receive notifications when your leader sends commands")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .padding(.bottom)
    }
    
    @ViewBuilder
    private func commandHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Commands")
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
                    
                    Text("No commands yet")
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
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Message")
                        .font(.headline)
                    
                    Text("Send a custom message to all group members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("Enter your message...", text: $customMessage, axis: .vertical)
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
                            senderId: user.id,
                            senderName: user.displayName,
                            currentLocation: getCurrentLocation()
                        )
                        
                        customMessage = ""
                        showingCustomMessageSheet = false
                    }
                }) {
                    Text("Send Message")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(customMessage.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(customMessage.isEmpty || commandService.isLoading)
            }
            .padding()
            .navigationTitle("Custom Message")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingCustomMessageSheet = false
                    customMessage = ""
                }
            )
        }
    }
    
    private func setupCommandService() {
        guard let group = groupService.currentGroup else { return }
        commandService.startListeningToCommands(groupId: group.id)
    }
    
    private func setupNotifications() {
        Task {
            await commandService.requestNotificationPermission()
        }
    }
    
    private func sendQuickCommand(type: CommandType, group: HitherGroup, user: HitherUser) async {
        await commandService.sendQuickCommand(
            type: type,
            groupId: group.id,
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
        case .gather: return .blue
        case .depart: return .green
        case .rest: return .orange
        case .beCareful: return .red
        case .goLeft, .goRight: return .purple
        case .stop: return .red
        case .hurryUp: return .yellow
        case .custom: return .gray
        }
    }
}

struct CommandHistoryCard: View {
    let command: GroupCommand
    
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
    }
    
    private func getIconColor() -> Color {
        switch command.type {
        case .gather: return .blue
        case .depart: return .green
        case .rest: return .orange
        case .beCareful: return .red
        case .goLeft, .goRight: return .purple
        case .stop: return .red
        case .hurryUp: return .yellow
        case .custom: return .gray
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(timestamp)
        
        if timeInterval < 60 {
            return "Now"
        } else if timeInterval < 3600 {
            return "\(Int(timeInterval / 60))m ago"
        } else if Calendar.current.isDate(timestamp, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: timestamp)
        }
    }
}