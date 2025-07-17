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
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var groupListener: ListenerRegistration?
    
    deinit {
        groupListener?.remove()
    }
    
    func createGroup(name: String, leaderId: String, leaderName: String) async {
        isLoading = true
        errorMessage = nil
        
        let group = HitherGroup(name: name, leaderId: leaderId, leaderName: leaderName)
        
        do {
            try await db.collection("groups").document(group.id).setData([
                "id": group.id,
                "name": group.name,
                "leaderId": group.leaderId,
                "createdAt": Timestamp(date: group.createdAt),
                "inviteCode": group.inviteCode,
                "inviteExpiresAt": Timestamp(date: group.inviteExpiresAt),
                "members": group.members.map { member in
                    [
                        "id": member.id,
                        "userId": member.userId,
                        "displayName": member.displayName,
                        "role": member.role.rawValue,
                        "joinedAt": Timestamp(date: member.joinedAt)
                    ]
                },
                "isActive": group.isActive
            ])
            
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
        
        do {
            let query = db.collection("groups")
                .whereField("inviteCode", isEqualTo: inviteCode)
                .whereField("isActive", isEqualTo: true)
            
            let snapshot = try await query.getDocuments()
            
            guard let document = snapshot.documents.first else {
                errorMessage = "Invalid invite code"
                isLoading = false
                return
            }
            
            let data = document.data()
            let inviteExpiresAt = (data["inviteExpiresAt"] as? Timestamp)?.dateValue() ?? Date()
            
            if inviteExpiresAt < Date() {
                errorMessage = "Invite code has expired"
                isLoading = false
                return
            }
            
            let newMember = GroupMember(userId: userId, displayName: userName, role: .follower)
            
            try await document.reference.updateData([
                "members": FieldValue.arrayUnion([[
                    "id": newMember.id,
                    "userId": newMember.userId,
                    "displayName": newMember.displayName,
                    "role": newMember.role.rawValue,
                    "joinedAt": Timestamp(date: newMember.joinedAt)
                ]])
            ])
            
            startListeningToGroup(groupId: document.documentID)
        } catch {
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
            
            try await db.collection("groups").document(group.id).updateData([
                "members": FieldValue.arrayRemove([[
                    "id": member.id,
                    "userId": member.userId,
                    "displayName": member.displayName,
                    "role": member.role.rawValue,
                    "joinedAt": Timestamp(date: member.joinedAt)
                ]])
            ])
            
            if member.role == .leader {
                try await db.collection("groups").document(group.id).updateData([
                    "isActive": false
                ])
            }
            
            stopListeningToGroup()
            currentGroup = nil
        } catch {
            errorMessage = "Failed to leave group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func startListeningToGroup(groupId: String) {
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
                    
                    self?.parseGroupFromData(data)
                }
            }
    }
    
    private func stopListeningToGroup() {
        groupListener?.remove()
        groupListener = nil
    }
    
    private func parseGroupFromData(_ data: [String: Any]) {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let leaderId = data["leaderId"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let inviteCode = data["inviteCode"] as? String,
              let inviteExpiresAtTimestamp = data["inviteExpiresAt"] as? Timestamp,
              let membersData = data["members"] as? [[String: Any]],
              let isActive = data["isActive"] as? Bool else {
            return
        }
        
        let members = membersData.compactMap { memberData -> GroupMember? in
            guard let memberId = memberData["id"] as? String,
                  let userId = memberData["userId"] as? String,
                  let displayName = memberData["displayName"] as? String,
                  let roleString = memberData["role"] as? String,
                  let role = MemberRole(rawValue: roleString),
                  let joinedAtTimestamp = memberData["joinedAt"] as? Timestamp else {
                return nil
            }
            
            var member = GroupMember(userId: userId, displayName: displayName, role: role)
            member = GroupMember(
                userId: userId,
                displayName: displayName,
                role: role
            )
            
            return member
        }
        
        var group = HitherGroup(name: name, leaderId: leaderId, leaderName: "")
        // Update with actual data
        currentGroup = group
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
}