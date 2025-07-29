//
//  GroupService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import FirebaseFirestore

@MainActor
class GroupService: ObservableObject {
    @Published var currentGroup: HitherGroup?
    @Published var allUserGroups: [HitherGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var groupListener: ListenerRegistration?
    private var allGroupsListener: ListenerRegistration?
    
    init() {
        // Pre-warm Firebase connection for better performance
        initializeFirebaseConnection()
    }
    
    deinit {
        groupListener?.remove()
        allGroupsListener?.remove()
    }
    
    // MARK: - Performance Optimization
    private func executeBatchOperation<T>(_ operation: @escaping () async throws -> T) async -> T? {
        return try? await operation()
    }
    
    // Pre-warm Firebase connection
    private func initializeFirebaseConnection() {
        Task {
            // Ping Firestore to establish connection
            _ = try? await db.collection("groups").limit(to: 1).getDocuments()
        }
    }
    
    // MARK: - Firebase Structure Migration
    func migrateGroupToSubcollectionStructure(groupId: String) async {
        print("🔄 Starting migration of group \(groupId) to subcollection structure")
        
        do {
            let groupDoc = try await db.collection("groups").document(groupId).getDocument()
            guard let data = groupDoc.data() else {
                print("❌ Group document not found")
                return
            }
            
            // Check if members data exists in main document
            if let membersArray = data["members"] as? [[String: Any]] {
                print("📦 Found \(membersArray.count) members to migrate")
                
                // Migrate each member to subcollection
                for memberData in membersArray {
                    guard let userId = memberData["userId"] as? String,
                          let displayName = memberData["displayName"] as? String,
                          let roleString = memberData["role"] as? String else {
                        continue
                    }
                    
                    // Set nickname = displayName as default
                    let nickname = memberData["nickname"] as? String ?? displayName
                    let avatarEmoji = memberData["avatarEmoji"] as? String
                    let joinedAt = memberData["joinedAt"] as? Timestamp ?? Timestamp(date: Date())
                    
                    var userData: [String: Any] = [
                        "displayName": displayName,
                        "nickname": nickname,
                        "role": roleString,
                        "joinedAt": joinedAt
                    ]
                    
                    // Add optional fields
                    if let avatarEmoji = avatarEmoji {
                        userData["avatarEmoji"] = avatarEmoji
                    }
                    if let location = memberData["location"] as? [String: Any] {
                        userData["location"] = location
                    }
                    if let lastLocationUpdate = memberData["lastLocationUpdate"] as? Timestamp {
                        userData["lastLocationUpdate"] = lastLocationUpdate
                    }
                    
                    // Write to subcollection
                    try await db.collection("groups").document(groupId)
                        .collection("users").document(userId).setData(userData)
                    
                    print("✅ Migrated user \(displayName) to subcollection")
                }
                
                // Remove members array from main document
                try await db.collection("groups").document(groupId).updateData([
                    "members": FieldValue.delete()
                ])
                
                print("🗑️ Removed members array from main document")
                print("✅ Migration completed for group \(groupId)")
            } else {
                print("ℹ️ Group \(groupId) already uses subcollection structure")
            }
            
        } catch {
            print("❌ Migration failed for group \(groupId): \(error.localizedDescription)")
        }
    }
    
    func createGroup(name: String, leaderId: String, leaderName: String) async {
        isLoading = true
        errorMessage = nil
        
        let group = HitherGroup(name: name, leaderId: leaderId, leaderName: leaderName)
        
        do {
            // Create the group document with basic info only (no leaderId, no duplicate id)
            try await db.collection("groups").document(group.id).setData([
                "name": group.name,
                "createdAt": Timestamp(date: group.createdAt),
                "inviteCode": group.inviteCode,
                "inviteExpiresAt": Timestamp(date: group.inviteExpiresAt),
                "isActive": group.isActive
            ])
            
            // Add users to the subcollection with location data
            for member in group.members {
                try await db.collection("groups").document(group.id)
                    .collection("users").document(member.userId).setData([
                        "displayName": member.displayName,
                        "nickname": member.displayName, // Set nickname = displayName by default
                        "role": member.role.rawValue,
                        "joinedAt": Timestamp(date: member.joinedAt),
                        "lastLocationUpdate": Timestamp(date: Date()),
                        "location": [
                            "latitude": 0.0,
                            "longitude": 0.0
                        ]
                    ])
            }
            
            currentGroup = group
            startListeningToGroup(groupId: group.id)
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func joinGroup(inviteCode: String, userId: String, userName: String) async {
        isLoading = true
        errorMessage = nil
        
        print("🔍 Attempting to join group with invite code: \(inviteCode)")
        print("🔍 User ID: \(userId)")
        print("🔍 User Name: \(userName)")
        
        do {
            let query = db.collection("groups")
                .whereField("inviteCode", isEqualTo: inviteCode)
                .whereField("isActive", isEqualTo: true)
            
            let snapshot = try await query.getDocuments()
            
            print("🔍 Query returned \(snapshot.documents.count) documents")
            
            guard let document = snapshot.documents.first else {
                errorMessage = "Invalid invite code"
                print("❌ No matching group found for invite code: \(inviteCode)")
                isLoading = false
                return
            }
            
            let data = document.data()
            let inviteExpiresAt = (data["inviteExpiresAt"] as? Timestamp)?.dateValue() ?? Date()
            
            print("🔍 Found group: \(data["name"] as? String ?? "Unknown")")
            print("🔍 Invite expires at: \(inviteExpiresAt)")
            print("🔍 Current time: \(Date())")
            
            if inviteExpiresAt < Date() {
                errorMessage = "Invite code has expired"
                print("❌ Invite code has expired")
                isLoading = false
                return
            }
            
            // Check if user is already in the group's users subcollection
            let existingUserDoc = try await document.reference.collection("users").document(userId).getDocument()
            if existingUserDoc.exists {
                errorMessage = "You are already a member of this group"
                print("❌ User already in group")
                isLoading = false
                return
            }
            
            let newMember = GroupMember(userId: userId, displayName: userName, role: .follower)
            
            print("🔍 Creating new member: \(newMember.displayName)")
            
            // Add the new member to users subcollection
            try await document.reference.collection("users").document(userId).setData([
                "displayName": newMember.displayName,
                "nickname": newMember.displayName, // Set nickname = displayName by default
                "role": newMember.role.rawValue,
                "joinedAt": Timestamp(date: newMember.joinedAt),
                "lastLocationUpdate": Timestamp(date: Date()),
                "location": [
                    "latitude": 0.0,
                    "longitude": 0.0
                ]
            ])
            
            print("🔍 Added member to users subcollection: \(userId)")
            
            print("✅ Successfully added member to group")
            
            startListeningToGroup(groupId: document.documentID)
            
            // Start listening for command notifications for this user
            // Note: This should ideally be handled by a shared CommandService instance
            print("🔔 Starting notification listener for user: \(userId)")
        } catch {
            print("❌ Failed to join group: \(error.localizedDescription)")
            errorMessage = "Failed to join group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func leaveGroup(userId: String) async {
        guard let group = currentGroup else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let memberToRemove = group.members.first { $0.userId == userId }
            guard let member = memberToRemove else {
                errorMessage = "Member not found in group"
                isLoading = false
                return
            }
            
            print("🔍 Removing member: \(member.displayName) from group: \(group.name)")
            print("🔍 Current member count: \(group.members.count)")
            
            // Remove the member from the group
            try await db.collection("groups").document(group.id).updateData([
                "members": FieldValue.arrayRemove([[
                    "id": member.id,
                    "userId": member.userId,
                    "displayName": member.displayName,
                    "role": member.role.rawValue,
                    "joinedAt": Timestamp(date: member.joinedAt)
                ]])
            ])
            
            let remainingMembers = group.members.filter { $0.userId != userId }
            print("🔍 Remaining members count: \(remainingMembers.count)")
            
            if remainingMembers.isEmpty {
                // If this was the last member, delete the group
                print("🔍 Last member leaving, deleting group")
                try await db.collection("groups").document(group.id).delete()
                print("✅ Group deleted successfully")
            } else if member.role == .leader {
                // If the leader is leaving, promote the first follower to leader
                if let newLeader = remainingMembers.first {
                    print("🔍 Promoting \(newLeader.displayName) to leader")
                    
                    // Remove the old member record
                    try await db.collection("groups").document(group.id).updateData([
                        "members": FieldValue.arrayRemove([[
                            "id": newLeader.id,
                            "userId": newLeader.userId,
                            "displayName": newLeader.displayName,
                            "role": newLeader.role.rawValue,
                            "joinedAt": Timestamp(date: newLeader.joinedAt)
                        ]])
                    ])
                    
                    // Add the new leader record
                    try await db.collection("groups").document(group.id).updateData([
                        "leaderId": newLeader.userId,
                        "members": FieldValue.arrayUnion([[
                            "id": newLeader.id,
                            "userId": newLeader.userId,
                            "displayName": newLeader.displayName,
                            "role": MemberRole.leader.rawValue,
                            "joinedAt": Timestamp(date: newLeader.joinedAt)
                        ]])
                    ])
                    
                    print("✅ Successfully promoted \(newLeader.displayName) to leader")
                }
            }
            
            stopListeningToGroup()
            currentGroup = nil
        } catch {
            print("❌ Failed to leave group: \(error.localizedDescription)")
            errorMessage = "Failed to leave group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func startListeningToGroup(groupId: String) {
        // Run migration first to ensure subcollection structure
        Task {
            await migrateGroupToSubcollectionStructure(groupId: groupId)
        }
        
        groupListener = db.collection("groups").document(groupId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = "Failed to sync group: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let document = documentSnapshot,
                          document.exists,
                          let data = document.data() else {
                        self?.currentGroup = nil
                        return
                    }
                    
                    // Parse group data and load users from subcollection
                    await self?.parseGroupFromDataWithSubcollections(groupId: groupId, data: data)
                }
            }
    }
    
    private func stopListeningToGroup() {
        groupListener?.remove()
        groupListener = nil
    }
    
    private func parseGroupFromDataWithSubcollections(groupId: String, data: [String: Any]) async {
        print("🔍 parseGroupFromDataWithSubcollections called for groupId: \(groupId)")
        
        guard let name = data["name"] as? String else {
            print("❌ Missing or invalid 'name' field")
            return
        }
        
        guard let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            print("❌ Missing or invalid 'createdAt' field")
            return
        }
        
        guard let inviteCode = data["inviteCode"] as? String else {
            print("❌ Missing or invalid 'inviteCode' field")
            return
        }
        
        guard let inviteExpiresAtTimestamp = data["inviteExpiresAt"] as? Timestamp else {
            print("❌ Missing or invalid 'inviteExpiresAt' field")
            return
        }
        
        let isActive = data["isActive"] as? Bool ?? true
        
        // Load users from subcollection to determine leader
        do {
            let usersSnapshot = try await db.collection("groups").document(groupId)
                .collection("users").getDocuments()
            
            var members: [GroupMember] = []
            var leaderId: String? = nil
            
            for userDoc in usersSnapshot.documents {
                let userId = userDoc.documentID
                let userData = userDoc.data()
                
                guard let displayName = userData["displayName"] as? String,
                      let roleString = userData["role"] as? String,
                      let role = MemberRole(rawValue: roleString),
                      let joinedAtTimestamp = userData["joinedAt"] as? Timestamp else {
                    continue
                }
                
                if role == .leader {
                    leaderId = userId
                }
                
                var location: GeoPoint? = nil
                var lastLocationUpdate: Date? = nil
                
                if let locationData = userData["location"] as? [String: Any],
                   let lat = locationData["latitude"] as? Double,
                   let lng = locationData["longitude"] as? Double {
                    location = GeoPoint(latitude: lat, longitude: lng)
                }
                
                if let lastUpdateTimestamp = userData["lastLocationUpdate"] as? Timestamp {
                    lastLocationUpdate = lastUpdateTimestamp.dateValue()
                }
                
                // Parse nickname and avatarEmoji from Firebase data
                let nickname = userData["nickname"] as? String
                let avatarEmoji = userData["avatarEmoji"] as? String
                
                let member = GroupMember(
                    id: UUID().uuidString,
                    userId: userId,
                    displayName: displayName,
                    nickname: nickname,
                    avatarEmoji: avatarEmoji,
                    role: role,
                    joinedAt: joinedAtTimestamp.dateValue(),
                    location: location,
                    lastLocationUpdate: lastLocationUpdate
                )
                
                members.append(member)
            }
            
            guard let validLeaderId = leaderId else {
                print("❌ No leader found in users subcollection")
                return
            }
            
            print("✅ Parsing group with \(members.count) members from subcollection")
            
            // Summary of parsing results
            print("✅ Parsing complete:")
            print("  - Total unique members: \(members.count)")
            print("  - Leaders: \(members.filter { $0.role == .leader }.count)")
            print("  - Followers: \(members.filter { $0.role == .follower }.count)")
            print("  - Member details:")
            for member in members {
                print("    - \(member.displayName) (ID: \(member.userId), Role: \(member.role.rawValue))")
            }
            
            // Create a properly parsed group with all the data
            let leaderName = members.first(where: { $0.role == .leader })?.displayName ?? 
                            members.first(where: { $0.userId == validLeaderId })?.displayName ?? 
                            "Unknown Leader"
            
            print("🔍 Creating HitherGroup with leaderName: '\(leaderName)'")
            
            let parsedGroup = HitherGroup(
                id: groupId,
                name: name,
                leaderId: validLeaderId,
                leaderName: leaderName,
                createdAt: createdAtTimestamp.dateValue(),
                inviteCode: inviteCode,
                inviteExpiresAt: inviteExpiresAtTimestamp.dateValue(),
                members: members,
                isActive: isActive
            )
            
            currentGroup = parsedGroup
            print("✅ Successfully created and assigned HitherGroup")
            
        } catch {
            print("❌ Failed to parse group from subcollections: \(error)")
        }
    }
    
    private func parseGroupFromData(_ data: [String: Any]) {
        // Legacy method - now redirected to subcollection approach
        print("🔍 parseGroupFromData called - this method is deprecated")
        print("⚠️ Please use parseGroupFromDataWithSubcollections instead")
    }
    
    func generateNewInviteCode() async {
        guard let group = currentGroup else { return }
        
        isLoading = true
        errorMessage = nil
        
        let newInviteCode = String.generateInviteCode()
        let newExpirationDate = Date().addingTimeInterval(24 * 60 * 60)
        
        do {
            try await db.collection("groups").document(group.id).updateData([
                "inviteCode": newInviteCode,
                "inviteExpiresAt": Timestamp(date: newExpirationDate)
            ])
        } catch {
            errorMessage = "Failed to generate new invite code: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func cleanupGroupData(groupId: String) async {
        print("🧹 Starting cleanup for group: \(groupId)")
        
        do {
            let document = try await db.collection("groups").document(groupId).getDocument()
            guard let data = document.data(),
                  let leaderId = data["leaderId"] as? String,
                  let membersData = data["members"] as? [[String: Any]] else {
                print("❌ Failed to fetch group data for cleanup")
                return
            }
            
            // Clean up duplicate members and ensure leader exists
            var cleanedMembers: [[String: Any]] = []
            var seenUserIds: Set<String> = []
            var hasLeader = false
            
            for memberData in membersData {
                guard let userId = memberData["userId"] as? String else { continue }
                
                if seenUserIds.contains(userId) {
                    print("🧹 Removing duplicate member: \(userId)")
                    continue
                }
                
                seenUserIds.insert(userId)
                
                // Fix role if needed
                var cleanedMemberData = memberData
                let correctRole = (userId == leaderId) ? "leader" : "follower"
                if let currentRole = memberData["role"] as? String, currentRole != correctRole {
                    print("🧹 Fixing role for \(userId): \(currentRole) -> \(correctRole)")
                    cleanedMemberData["role"] = correctRole
                }
                
                if correctRole == "leader" {
                    hasLeader = true
                }
                
                cleanedMembers.append(cleanedMemberData)
            }
            
            // If leader is missing from members, log it but don't fail
            if !hasLeader {
                print("⚠️ Leader \(leaderId) not found in members list. This might be expected during member operations.")
            }
            
            // Update the group with cleaned data
            if cleanedMembers.count != membersData.count {
                print("🧹 Updating group with cleaned data: \(membersData.count) -> \(cleanedMembers.count) members")
                try await db.collection("groups").document(groupId).updateData([
                    "members": cleanedMembers
                ])
                print("✅ Group data cleanup completed")
            } else {
                print("✅ No cleanup needed")
            }
            
        } catch {
            print("❌ Failed to cleanup group data: \(error.localizedDescription)")
        }
    }
    
    func loadUserGroups(userId: String) async {
        print("🔍 Loading groups for userId: '\(userId)'")
        do {
            let query = db.collection("groups")
                .whereField("isActive", isEqualTo: true)
            
            let snapshot = try await query.getDocuments()
            print("🔍 Total active groups found: \(snapshot.documents.count)")
            
            var userGroups: [HitherGroup] = []
            
            for document in snapshot.documents {
                let data = document.data()
                let groupId = document.documentID
                let groupName = data["name"] as? String ?? "Unknown"
                
                print("🔍 Checking group '\(groupName)' (ID: \(groupId))")
                
                // Check if user exists in the users subcollection
                do {
                    let userDoc = try await db.collection("groups").document(groupId)
                        .collection("users").document(userId).getDocument()
                    
                    if userDoc.exists {
                        print("✅ Found user in group '\(groupName)'")
                        
                        if let group = await parseGroupWithSubcollections(groupId: groupId, groupData: data) {
                            userGroups.append(group)
                            print("✅ Added group '\(groupName)' to user groups")
                        } else {
                            print("❌ Failed to parse group '\(groupName)'")
                        }
                    } else {
                        print("❌ User '\(userId)' not found in group '\(groupName)'")
                    }
                } catch {
                    print("❌ Error checking user in group '\(groupName)': \(error)")
                }
            }
            
            allUserGroups = userGroups
            print("🔍 Final result: Found \(userGroups.count) groups for user '\(userId)'")
            
        } catch {
            print("❌ Failed to load user groups: \(error.localizedDescription)")
            errorMessage = "Failed to load groups: \(error.localizedDescription)"
        }
    }
    
    func startListeningToUserGroups(userId: String) {
        allGroupsListener = db.collection("groups")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = "Failed to sync groups: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    var userGroups: [HitherGroup] = []
                    
                    // Process groups asynchronously to check users subcollection
                    for document in documents {
                        let data = document.data()
                        let groupId = document.documentID
                        let groupName = data["name"] as? String ?? "Unknown Group"
                        
                        print("🔍 Listener checking group '\(groupName)' for user '\(userId)'")
                        
                        // Check if user exists in the users subcollection
                        do {
                            let userDoc = try await self?.db.collection("groups").document(groupId)
                                .collection("users").document(userId).getDocument()
                            
                            if userDoc?.exists == true {
                                print("✅ Found user in group '\(groupName)'")
                                
                                if let group = await self?.parseGroupWithSubcollections(groupId: groupId, groupData: data) {
                                    userGroups.append(group)
                                    print("✅   Added group '\(groupName)' to listener results")
                                } else {
                                    print("❌   Failed to parse group '\(groupName)'")
                                }
                            } else {
                                print("❌   User not found in group '\(groupName)'")
                            }
                        } catch {
                            print("❌   Error checking user in group '\(groupName)': \(error)")
                        }
                    }
                    
                    print("🔍 Listener final result: Found \(userGroups.count) groups for user '\(userId)'")
                    self?.allUserGroups = userGroups
                }
            }
    }
    
    func stopListeningToUserGroups() {
        allGroupsListener?.remove()
        allGroupsListener = nil
    }
    
    func switchToGroup(_ group: HitherGroup) {
        stopListeningToGroup()
        currentGroup = group
        startListeningToGroup(groupId: group.id)
        
        // Note: Notification listener should remain active when switching groups
        // since it's user-based, not group-based
        print("🔔 Switched to group: \(group.name) - notification listener should remain active")
    }
    
    func navigateToSetup() {
        print("🔄 Navigating to Group Setup (without leaving group)")
        // Temporarily clear currentGroup to show GroupSetupView
        // The user can rejoin their existing groups from the list
        stopListeningToGroup()
        currentGroup = nil
    }
    
    func updateMemberNickname(groupId: String, userId: String, nickname: String) async {
        do {
            let memberPath = "members.\(userId).nickname"
            
            try await db.collection("groups").document(groupId).updateData([
                memberPath: nickname
            ])
            
            print("✅ Successfully updated nickname to: \(nickname) for user: \(userId)")
            
        } catch {
            print("❌ Failed to update nickname: \(error.localizedDescription)")
            errorMessage = "Failed to update nickname: \(error.localizedDescription)"
        }
    }
    
    func refreshCurrentGroup() async {
        guard let group = currentGroup else { return }
        
        do {
            let document = try await db.collection("groups").document(group.id).getDocument()
            guard let data = document.data() else { return }
            
            // Store the current group temporarily in case parsing fails
            let previousGroup = currentGroup
            
            // Parse the updated group data using new subcollection approach
            if let updatedGroup = await parseGroupWithSubcollections(groupId: group.id, groupData: data) {
                currentGroup = updatedGroup
            } else {
                currentGroup = nil
            }
            
            // If parsing failed (currentGroup became nil), restore the previous group
            if currentGroup == nil {
                currentGroup = previousGroup
                print("⚠️ Group parsing failed during refresh, restored previous group data")
            } else {
                print("✅ Refreshed group data for: \(currentGroup?.name ?? "Unknown")")
            }
        } catch {
            print("❌ Failed to refresh group data: \(error.localizedDescription)")
        }
    }
    
    func leaveSpecificGroup(groupId: String, userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let document = try await db.collection("groups").document(groupId).getDocument()
            guard let data = document.data() else {
                errorMessage = "Group not found"
                isLoading = false
                return
            }
            
            guard let membersData = data["members"] as? [[String: Any]] else {
                errorMessage = "Invalid group data"
                isLoading = false
                return
            }
            
            guard let memberData = membersData.first(where: { $0["userId"] as? String == userId }) else {
                errorMessage = "You are not a member of this group"
                isLoading = false
                return
            }
            
            // Remove the member
            try await db.collection("groups").document(groupId).updateData([
                "members": FieldValue.arrayRemove([memberData])
            ])
            
            let remainingMembers = membersData.filter { $0["userId"] as? String != userId }
            
            if remainingMembers.isEmpty {
                // Delete the group if no members left
                try await db.collection("groups").document(groupId).delete()
                print("✅ Group deleted (no members remaining)")
            } else if memberData["role"] as? String == "leader" {
                // Promote first remaining member to leader
                if let newLeaderData = remainingMembers.first {
                    try await db.collection("groups").document(groupId).updateData([
                        "members": FieldValue.arrayRemove([newLeaderData])
                    ])
                    
                    var updatedLeaderData = newLeaderData
                    updatedLeaderData["role"] = "leader"
                    
                    try await db.collection("groups").document(groupId).updateData([
                        "leaderId": newLeaderData["userId"] as? String ?? "",
                        "members": FieldValue.arrayUnion([updatedLeaderData])
                    ])
                    
                    print("✅ Promoted member to leader")
                }
            }
            
            // If this was the current group, clear it
            if currentGroup?.id == groupId {
                stopListeningToGroup()
                currentGroup = nil
            }
            
            // Reload user groups
            await loadUserGroups(userId: userId)
            
        } catch {
            print("❌ Failed to leave group: \(error.localizedDescription)")
            errorMessage = "Failed to leave group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func validateAndRepairGroupData(_ data: [String: Any]) -> [String: Any] {
        var repairedData = data
        
        print("🔧 Starting data validation and repair...")
        
        // Validate and repair members field
        if let members = data["members"] {
            if let membersArray = members as? [[String: Any]] {
                // Check if members array has proper structure
                let validMembers = membersArray.compactMap { memberData -> [String: Any]? in
                    // Check if member has required fields
                    if memberData["id"] != nil && memberData["userId"] != nil && 
                       memberData["displayName"] != nil && memberData["role"] != nil {
                        return memberData
                    }
                    return nil
                }
                
                if validMembers.count == membersArray.count {
                    print("✅ Members field validation: Array format with \(membersArray.count) valid members")
                } else {
                    print("⚠️ Members field validation: Found \(validMembers.count) valid members out of \(membersArray.count)")
                    repairedData["members"] = validMembers
                }
            } else if let singleMember = members as? [String: Any] {
                // Check if single member has proper structure
                if singleMember["id"] != nil && singleMember["userId"] != nil && 
                   singleMember["displayName"] != nil && singleMember["role"] != nil {
                    repairedData["members"] = [singleMember]
                    print("✅ Members field validation: Converted valid single member to array")
                } else {
                    // Single member is invalid, check if it's the legacy format
                    print("⚠️ Members field validation: Single member missing required fields")
                    print("  - Member data: \(singleMember)")
                    repairedData["members"] = repairLegacyMemberData(singleMember, groupData: data)
                }
            } else {
                // Try to repair legacy format where members is a dictionary with userIds as keys
                print("⚠️ Members field validation: Attempting to repair legacy format")
                print("  - Members field type: \(type(of: members))")
                print("  - Members field value: \(members)")
                
                if let legacyMembers = members as? [String: Any] {
                    repairedData["members"] = repairLegacyMemberData(legacyMembers, groupData: data)
                } else {
                    repairedData["members"] = [[String: Any]]()
                    print("⚠️ Members field validation: Cannot repair, creating empty array")
                }
            }
        } else {
            // Missing members field, create empty array
            repairedData["members"] = [[String: Any]]()
            print("⚠️ Members field validation: Missing field, creating empty array")
        }
        
        // Validate other required fields
        if repairedData["isActive"] == nil {
            repairedData["isActive"] = true
            print("⚠️ isActive field validation: Missing field, defaulting to true")
        }
        
        // Ensure leaderId is set correctly
        if let membersArray = repairedData["members"] as? [[String: Any]], !membersArray.isEmpty {
            let hasLeader = membersArray.contains { member in
                member["role"] as? String == "leader"
            }
            
            if !hasLeader {
                // If no leader in members, check if leaderId is set correctly
                if let leaderId = repairedData["leaderId"] as? String {
                    // Find member with leaderId and ensure they are leader
                    var updatedMembers = membersArray
                    for (index, member) in updatedMembers.enumerated() {
                        if let userId = member["userId"] as? String, userId == leaderId {
                            updatedMembers[index]["role"] = "leader"
                            print("🔧 Fixed leader role for userId: \(userId)")
                            break
                        }
                    }
                    repairedData["members"] = updatedMembers
                } else {
                    // No leaderId set, use first member as leader
                    if let firstUserId = membersArray.first?["userId"] as? String {
                        repairedData["leaderId"] = firstUserId
                        var updatedMembers = membersArray
                        updatedMembers[0]["role"] = "leader"
                        repairedData["members"] = updatedMembers
                        print("🔧 Set first member as leader: \(firstUserId)")
                    }
                }
            }
        }
        
        print("✅ Data validation and repair completed")
        return repairedData
    }
    
    private func repairLegacyMemberData(_ legacyData: [String: Any], groupData: [String: Any]) -> [[String: Any]] {
        var repairedMembers: [[String: Any]] = []
        
        print("🔧 Attempting to repair legacy member data...")
        
        for (userId, memberInfo) in legacyData {
            print("  - Processing userId: \(userId)")
            
            // Create a proper member object
            var memberData: [String: Any] = [
                "id": UUID().uuidString,
                "userId": userId,
                "displayName": "Unknown User", // Default name
                "role": "follower", // Default role
                "joinedAt": Timestamp(date: Date())
            ]
            
            // If memberInfo is a dictionary, extract location data
            if let memberInfoDict = memberInfo as? [String: Any] {
                if let location = memberInfoDict["location"] as? [String: Any] {
                    memberData["location"] = location
                    print("    - Added location data")
                }
                
                if let lastLocationUpdate = memberInfoDict["lastLocationUpdate"] as? Timestamp {
                    memberData["lastLocationUpdate"] = lastLocationUpdate
                    print("    - Added last location update")
                }
                
                // Extract nickname field (this is the user's display name in the new structure)
                if let nickname = memberInfoDict["nickname"] as? String {
                    memberData["displayName"] = nickname
                    memberData["nickname"] = nickname
                    print("    - Found nickname: \(nickname)")
                } else if let displayName = memberInfoDict["displayName"] as? String {
                    // Legacy format fallback
                    memberData["displayName"] = displayName
                    memberData["nickname"] = displayName
                    print("    - Found legacy displayName: \(displayName)")
                }
                
                if let role = memberInfoDict["role"] as? String {
                    memberData["role"] = role
                    print("    - Found role: \(role)")
                }
            }
            
            // Check if this user is the leader
            if let leaderId = groupData["leaderId"] as? String, userId == leaderId {
                memberData["role"] = "leader"
                print("    - Set as leader based on leaderId: \(leaderId)")
            } else {
                // If no explicit leader found and this is the only/first member, make them leader
                if repairedMembers.isEmpty {
                    memberData["role"] = "leader"
                    print("    - Set as leader (first member in group)")
                }
            }
            
            repairedMembers.append(memberData)
            print("    - ✅ Repaired member: \(memberData["displayName"] ?? "Unknown")")
        }
        
        // Ensure at least one leader exists
        let hasLeader = repairedMembers.contains { member in
            member["role"] as? String == "leader"
        }
        
        if !hasLeader && !repairedMembers.isEmpty {
            // If no leader found, make the first member a leader
            repairedMembers[0]["role"] = "leader"
            print("🔧 No leader found, promoted first member to leader")
        }
        
        print("✅ Legacy member data repair completed: \(repairedMembers.count) members")
        print("🔧 Leaders in repaired data: \(repairedMembers.filter { $0["role"] as? String == "leader" }.count)")
        return repairedMembers
    }
    
    private func parseGroupFromDocument(_ data: [String: Any]) -> HitherGroup? {
        // This method is now deprecated - it cannot work with the new structure
        // because it doesn't have access to the users subcollection
        print("❌ parseGroupFromDocument called - this method is deprecated")
        print("⚠️ Cannot parse group without access to users subcollection")
        return nil
    }
    
    private func parseGroupWithSubcollections(groupId: String, groupData: [String: Any]) async -> HitherGroup? {
        guard let name = groupData["name"] as? String,
              let createdAtTimestamp = groupData["createdAt"] as? Timestamp,
              let inviteCode = groupData["inviteCode"] as? String,
              let inviteExpiresAtTimestamp = groupData["inviteExpiresAt"] as? Timestamp else {
            print("❌ parseGroupWithSubcollections failed to parse required fields")
            return nil
        }
        
        let isActive = groupData["isActive"] as? Bool ?? true
        
        // Load users from subcollection
        do {
            let usersSnapshot = try await db.collection("groups").document(groupId)
                .collection("users").getDocuments()
            
            var members: [GroupMember] = []
            var leaderId: String? = nil
            
            for userDoc in usersSnapshot.documents {
                let userId = userDoc.documentID
                let userData = userDoc.data()
                
                guard let displayName = userData["displayName"] as? String,
                      let roleString = userData["role"] as? String,
                      let role = MemberRole(rawValue: roleString),
                      let joinedAtTimestamp = userData["joinedAt"] as? Timestamp else {
                    continue
                }
                
                if role == .leader {
                    leaderId = userId
                }
                
                var location: GeoPoint? = nil
                var lastLocationUpdate: Date? = nil
                
                if let locationData = userData["location"] as? [String: Any],
                   let lat = locationData["latitude"] as? Double,
                   let lng = locationData["longitude"] as? Double {
                    location = GeoPoint(latitude: lat, longitude: lng)
                }
                
                if let lastUpdateTimestamp = userData["lastLocationUpdate"] as? Timestamp {
                    lastLocationUpdate = lastUpdateTimestamp.dateValue()
                }
                
                // Parse nickname and avatarEmoji from Firebase data
                let nickname = userData["nickname"] as? String
                let avatarEmoji = userData["avatarEmoji"] as? String
                
                let member = GroupMember(
                    id: UUID().uuidString,
                    userId: userId,
                    displayName: displayName,
                    nickname: nickname,
                    avatarEmoji: avatarEmoji,
                    role: role,
                    joinedAt: joinedAtTimestamp.dateValue(),
                    location: location,
                    lastLocationUpdate: lastLocationUpdate
                )
                
                members.append(member)
            }
            
            guard let validLeaderId = leaderId else {
                print("❌ No leader found in users subcollection for group: \(groupId)")
                return nil
            }
            
            let leaderName = members.first(where: { $0.role == .leader })?.displayName ?? "Unknown Leader"
            
            return HitherGroup(
                id: groupId,
                name: name,
                leaderId: validLeaderId,
                leaderName: leaderName,
                createdAt: createdAtTimestamp.dateValue(),
                inviteCode: inviteCode,
                inviteExpiresAt: inviteExpiresAtTimestamp.dateValue(),
                members: members,
                isActive: isActive
            )
            
        } catch {
            print("❌ Failed to load users subcollection for group \(groupId): \(error)")
            return nil
        }
    }
    
    private func updateFirebaseWithRepairedData(groupId: String, repairedGroup: HitherGroup) async {
        print("🔧 Updating Firebase with repaired group data...")
        
        do {
            let membersData = repairedGroup.members.map { member in
                var memberDict: [String: Any] = [
                    "id": member.id,
                    "userId": member.userId,
                    "displayName": member.displayName,
                    "nickname": member.nickname ?? member.displayName,
                    "role": member.role.rawValue,
                    "joinedAt": Timestamp(date: member.joinedAt)
                ]
                
                if let location = member.location {
                    memberDict["location"] = [
                        "latitude": location.latitude,
                        "longitude": location.longitude
                    ]
                }
                
                if let lastLocationUpdate = member.lastLocationUpdate {
                    memberDict["lastLocationUpdate"] = Timestamp(date: lastLocationUpdate)
                }
                
                return memberDict
            }
            
            try await db.collection("groups").document(groupId).updateData([
                "members": membersData
            ])
            
            print("✅ Successfully updated Firebase with repaired data")
        } catch {
            print("❌ Failed to update Firebase with repaired data: \(error.localizedDescription)")
        }
    }
    
    // Diagnostic function to check group data structure
    func diagnoseGroupData(groupId: String) async {
        print("🔍 Starting group data diagnosis for groupId: \(groupId)")
        
        do {
            let document = try await db.collection("groups").document(groupId).getDocument()
            guard let data = document.data() else {
                print("❌ Group document not found")
                return
            }
            
            print("🔍 Group document exists with keys: \(data.keys.sorted())")
            
            if let members = data["members"] {
                print("🔍 Members field type: \(type(of: members))")
                print("🔍 Members field content: \(members)")
                
                if let membersArray = members as? [[String: Any]] {
                    print("🔍 Members is array with \(membersArray.count) elements")
                    for (index, member) in membersArray.enumerated() {
                        print("🔍 Member \(index + 1) keys: \(member.keys.sorted())")
                    }
                } else if let membersDict = members as? [String: Any] {
                    print("🔍 Members is dictionary with keys: \(membersDict.keys.sorted())")
                    for (key, value) in membersDict {
                        print("🔍 Members[\(key)] type: \(type(of: value))")
                        print("🔍 Members[\(key)] content: \(value)")
                    }
                }
            } else {
                print("❌ Members field is missing")
            }
        } catch {
            print("❌ Failed to diagnose group data: \(error.localizedDescription)")
        }
    }
}