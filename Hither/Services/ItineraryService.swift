//
//  ItineraryService.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import Foundation
import FirebaseFirestore
import CoreLocation

@MainActor
class ItineraryService: ObservableObject {
    @Published var currentItinerary: GroupItinerary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var itineraryListener: ListenerRegistration?
    
    deinit {
        itineraryListener?.remove()
    }
    
    func startListeningToItinerary(groupId: String) {
        itineraryListener?.remove()
        
        itineraryListener = db.collection("groups")
            .document(groupId)
            .collection("itinerary")
            .document("current")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.errorMessage = "Failed to sync itinerary: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let document = documentSnapshot else { return }
                    
                    if document.exists, let data = document.data() {
                        self?.parseItineraryFromData(data, groupId: groupId)
                    } else {
                        // Create new itinerary if none exists
                        self?.currentItinerary = GroupItinerary(groupId: groupId)
                    }
                }
            }
    }
    
    func stopListeningToItinerary() {
        itineraryListener?.remove()
        itineraryListener = nil
        currentItinerary = nil
    }
    
    func addWaypoint(
        name: String,
        description: String? = nil,
        type: WaypointType,
        location: CLLocationCoordinate2D,
        groupId: String,
        createdBy: String
    ) async {
        isLoading = true
        errorMessage = nil
        
        let geoPoint = GeoPoint(from: location)
        let order = (currentItinerary?.waypoints.count ?? 0)
        
        let waypoint = Waypoint(
            groupId: groupId,
            name: name,
            description: description,
            type: type,
            location: geoPoint,
            createdBy: createdBy,
            order: order
        )
        
        do {
            // Add waypoint to Firestore
            try await db.collection("groups")
                .document(groupId)
                .collection("itinerary")
                .document("current")
                .collection("waypoints")
                .document(waypoint.id)
                .setData([
                    "id": waypoint.id,
                    "groupId": waypoint.groupId,
                    "name": waypoint.name,
                    "description": waypoint.description ?? "",
                    "type": waypoint.type.rawValue,
                    "location": waypoint.location.toFirestoreData(),
                    "createdAt": Timestamp(date: waypoint.createdAt),
                    "updatedAt": Timestamp(date: waypoint.updatedAt),
                    "createdBy": waypoint.createdBy,
                    "isActive": waypoint.isActive,
                    "order": waypoint.order
                ])
            
            // Update itinerary document
            await updateItineraryDocument(groupId: groupId)
            
            // Send notification about itinerary update
            await notifyItineraryUpdate(
                groupId: groupId,
                action: .added,
                waypointName: waypoint.name,
                updatedBy: createdBy
            )
            
        } catch {
            errorMessage = "Failed to add waypoint: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateWaypoint(
        waypointId: String,
        name: String? = nil,
        description: String? = nil,
        location: CLLocationCoordinate2D? = nil,
        groupId: String,
        updatedBy: String
    ) async {
        guard var itinerary = currentItinerary,
              let waypointIndex = itinerary.waypoints.firstIndex(where: { $0.id == waypointId }) else {
            errorMessage = "Waypoint not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var waypoint = itinerary.waypoints[waypointIndex]
        
        if let name = name { waypoint.name = name }
        if let description = description { waypoint.description = description }
        if let location = location { waypoint.location = GeoPoint(from: location) }
        waypoint.updatedAt = Date()
        
        do {
            try await db.collection("groups")
                .document(groupId)
                .collection("itinerary")
                .document("current")
                .collection("waypoints")
                .document(waypointId)
                .updateData([
                    "name": waypoint.name,
                    "description": waypoint.description ?? "",
                    "location": waypoint.location.toFirestoreData(),
                    "updatedAt": Timestamp(date: waypoint.updatedAt)
                ])
            
            await updateItineraryDocument(groupId: groupId)
            
            await notifyItineraryUpdate(
                groupId: groupId,
                action: .updated,
                waypointName: waypoint.name,
                updatedBy: updatedBy
            )
            
        } catch {
            errorMessage = "Failed to update waypoint: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func removeWaypoint(waypointId: String, groupId: String, updatedBy: String) async {
        guard let itinerary = currentItinerary,
              let waypoint = itinerary.waypoints.first(where: { $0.id == waypointId }) else {
            errorMessage = "Waypoint not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await db.collection("groups")
                .document(groupId)
                .collection("itinerary")
                .document("current")
                .collection("waypoints")
                .document(waypointId)
                .delete()
            
            await updateItineraryDocument(groupId: groupId)
            
            await notifyItineraryUpdate(
                groupId: groupId,
                action: .removed,
                waypointName: waypoint.name,
                updatedBy: updatedBy
            )
            
        } catch {
            errorMessage = "Failed to remove waypoint: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func markWaypointCompleted(waypointId: String, groupId: String, updatedBy: String) async {
        guard let itinerary = currentItinerary,
              let waypoint = itinerary.waypoints.first(where: { $0.id == waypointId }) else {
            errorMessage = "Waypoint not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await db.collection("groups")
                .document(groupId)
                .collection("itinerary")
                .document("current")
                .collection("waypoints")
                .document(waypointId)
                .updateData([
                    "isActive": false,
                    "updatedAt": Timestamp(date: Date())
                ])
            
            await updateItineraryDocument(groupId: groupId)
            
            await notifyItineraryUpdate(
                groupId: groupId,
                action: .completed,
                waypointName: waypoint.name,
                updatedBy: updatedBy
            )
            
        } catch {
            errorMessage = "Failed to mark waypoint as completed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func reorderWaypoints(waypoints: [Waypoint], groupId: String, updatedBy: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let batch = db.batch()
            
            for (index, waypoint) in waypoints.enumerated() {
                let waypointRef = db.collection("groups")
                    .document(groupId)
                    .collection("itinerary")
                    .document("current")
                    .collection("waypoints")
                    .document(waypoint.id)
                
                batch.updateData([
                    "order": index,
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: waypointRef)
            }
            
            try await batch.commit()
            
            await updateItineraryDocument(groupId: groupId)
            
            await notifyItineraryUpdate(
                groupId: groupId,
                action: .reordered,
                waypointName: "waypoints",
                updatedBy: updatedBy
            )
            
        } catch {
            errorMessage = "Failed to reorder waypoints: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func updateItineraryDocument(groupId: String) async {
        do {
            try await db.collection("groups")
                .document(groupId)
                .collection("itinerary")
                .document("current")
                .setData([
                    "id": currentItinerary?.id ?? UUID().uuidString,
                    "groupId": groupId,
                    "updatedAt": Timestamp(date: Date())
                ], merge: true)
        } catch {
            print("Failed to update itinerary document: \(error)")
        }
    }
    
    private func notifyItineraryUpdate(
        groupId: String,
        action: WaypointUpdate.WaypointAction,
        waypointName: String,
        updatedBy: String
    ) async {
        // In a real implementation, this would trigger push notifications
        // For now, we'll just log the update
        print("Itinerary updated: \(action.rawValue) \(waypointName) by \(updatedBy)")
    }
    
    private func parseItineraryFromData(_ data: [String: Any], groupId: String) {
        // For simplicity, we'll fetch waypoints separately
        Task {
            await fetchWaypoints(groupId: groupId)
        }
    }
    
    private func fetchWaypoints(groupId: String) async {
        do {
            let snapshot = try await db.collection("groups")
                .document(groupId)
                .collection("itinerary")
                .document("current")
                .collection("waypoints")
                .order(by: "order")
                .getDocuments()
            
            let waypoints = snapshot.documents.compactMap { document -> Waypoint? in
                let data = document.data()
                
                guard let id = data["id"] as? String,
                      let name = data["name"] as? String,
                      let typeString = data["type"] as? String,
                      let type = WaypointType(rawValue: typeString),
                      let locationData = data["location"] as? [String: Any],
                      let lat = locationData["latitude"] as? Double,
                      let lng = locationData["longitude"] as? Double,
                      let createdAtTimestamp = data["createdAt"] as? Timestamp,
                      let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
                      let createdBy = data["createdBy"] as? String,
                      let isActive = data["isActive"] as? Bool,
                      let order = data["order"] as? Int else {
                    return nil
                }
                
                let description = data["description"] as? String
                let location = GeoPoint(latitude: lat, longitude: lng)
                
                var waypoint = Waypoint(
                    groupId: groupId,
                    name: name,
                    description: description,
                    type: type,
                    location: location,
                    createdBy: createdBy,
                    order: order
                )
                
                // Update with actual data
                return waypoint
            }
            
            var itinerary = GroupItinerary(groupId: groupId)
            itinerary.waypoints = waypoints
            currentItinerary = itinerary
            
        } catch {
            errorMessage = "Failed to fetch waypoints: \(error.localizedDescription)"
        }
    }
    
    func calculateDistanceToWaypoint(_ waypoint: Waypoint, from location: CLLocationCoordinate2D) -> CLLocationDistance {
        let waypointLocation = CLLocation(
            latitude: waypoint.location.latitude,
            longitude: waypoint.location.longitude
        )
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return currentLocation.distance(from: waypointLocation)
    }
}