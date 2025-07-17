//
//  AddWaypointSheet.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import MapKit
import CoreLocation

struct AddWaypointSheet: View {
    @ObservedObject var itineraryService: ItineraryService
    let groupId: String
    let userId: String
    let userName: String
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationService = LocationService()
    
    @State private var waypointName = ""
    @State private var waypointDescription = ""
    @State private var selectedType = WaypointType.checkpoint
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingLocationPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Waypoint Details")) {
                    TextField("Waypoint Name", text: $waypointName)
                    
                    TextField("Description (Optional)", text: $waypointDescription, axis: .vertical)
                        .lineLimit(2...4)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(WaypointType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(getTypeColor(type))
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section(header: Text("Location")) {
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            
                            if selectedLocation != nil {
                                Text("Location Selected")
                                    .foregroundColor(.blue)
                            } else {
                                Text("Choose Location")
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        useCurrentLocation()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.green)
                            
                            Text("Use Current Location")
                                .foregroundColor(.green)
                        }
                    }
                    .disabled(locationService.currentLocation == nil)
                }
                
                if let location = selectedLocation {
                    Section(header: Text("Preview")) {
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )), annotationItems: [AddWaypointMapAnnotationItem(coordinate: location)]) { item in
                            MapAnnotation(coordinate: item.coordinate) {
                                Image(systemName: selectedType.icon)
                                    .foregroundColor(getTypeColor(selectedType))
                                    .font(.title)
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    addWaypoint()
                }
                .disabled(!canAddWaypoint)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            setupLocation()
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(selectedLocation: $selectedLocation, region: $region)
        }
    }
    
    private var canAddWaypoint: Bool {
        !waypointName.isEmpty && selectedLocation != nil
    }
    
    private func setupLocation() {
        locationService.requestLocationPermission()
        
        if let currentLocation = locationService.currentLocation {
            region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func useCurrentLocation() {
        guard let currentLocation = locationService.currentLocation else { return }
        selectedLocation = currentLocation.coordinate
        
        region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    private func addWaypoint() {
        guard let location = selectedLocation else { return }
        
        Task {
            await itineraryService.addWaypoint(
                name: waypointName,
                description: waypointDescription.isEmpty ? nil : waypointDescription,
                type: selectedType,
                location: location,
                groupId: groupId,
                createdBy: userId
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func getTypeColor(_ type: WaypointType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        default: return .blue
        }
    }
}

struct LocationPickerSheet: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var region: MKCoordinateRegion
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempLocation: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: tempLocation != nil ? [AddWaypointMapAnnotationItem(coordinate: tempLocation!)] : []) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                }
            }
            .onTapGesture { location in
                // Convert tap location to coordinate
                // Note: This is a simplified implementation
                // In a real app, you'd need to properly convert the tap location
                tempLocation = region.center
            }
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            tempLocation = region.center
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            )
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    selectedLocation = tempLocation ?? region.center
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(tempLocation == nil)
            )
        }
        .onAppear {
            tempLocation = selectedLocation
        }
    }
}

struct WaypointDetailSheet: View {
    let waypoint: Waypoint
    @ObservedObject var itineraryService: ItineraryService
    let groupId: String
    let userId: String
    let userName: String
    let isLeader: Bool
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Waypoint info
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: waypoint.type.icon)
                            .foregroundColor(getTypeColor())
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(waypoint.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(waypoint.type.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if waypoint.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title)
                        }
                    }
                    
                    if let description = waypoint.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Map
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: waypoint.location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [AddWaypointMapAnnotationItem(coordinate: waypoint.location.coordinate)]) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        Image(systemName: waypoint.type.icon)
                            .foregroundColor(getTypeColor())
                            .font(.title)
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                
                // Actions
                if isLeader {
                    VStack(spacing: 12) {
                        if waypoint.isActive && !waypoint.isCompleted {
                            if waypoint.isInProgress {
                                // Stop Going button
                                Button(action: {
                                    stopGoing()
                                }) {
                                    HStack {
                                        Image(systemName: "stop.circle")
                                        Text("Stop Going")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                // Mark Complete button
                                Button(action: {
                                    markCompleted()
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                        Text("Mark as Completed")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            } else {
                                // Going button
                                Button(action: {
                                    startGoing()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.circle")
                                        Text("Going")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Waypoint")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Waypoint Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("Delete Waypoint", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteWaypoint()
                }
            } message: {
                Text("Are you sure you want to delete this waypoint? This action cannot be undone.")
            }
        }
    }
    
    private func getTypeColor() -> Color {
        switch waypoint.type.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        default: return .blue
        }
    }
    
    private func startGoing() {
        Task {
            await itineraryService.startWaypointProgress(
                waypointId: waypoint.id,
                groupId: groupId,
                updatedBy: userId
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func stopGoing() {
        Task {
            await itineraryService.stopWaypointProgress(
                waypointId: waypoint.id,
                groupId: groupId,
                updatedBy: userId
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func markCompleted() {
        Task {
            await itineraryService.markWaypointCompleted(
                waypointId: waypoint.id,
                groupId: groupId,
                updatedBy: userId
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func deleteWaypoint() {
        Task {
            await itineraryService.removeWaypoint(
                waypointId: waypoint.id,
                groupId: groupId,
                updatedBy: userId
            )
            
            // Wait a moment for Firestore to update
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct AddWaypointMapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}