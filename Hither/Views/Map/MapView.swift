//
//  MapView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var locationService = LocationService()
    @StateObject private var itineraryService = ItineraryService()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var mapType: MKMapType = .standard
    @State private var isFollowingUser = false
    @State private var routeOverlay: MKPolyline?
    @State private var currentRoute: MKRoute?
    @State private var previewWaypointIndex = 0
    @State private var routeCache: [String: MKRoute] = [:]
    @State private var routeDebounceTimer: Timer?
    @State private var currentRouteTask: Task<Void, Never>?
    
    private var previewableWaypoints: [Waypoint] {
        guard let itinerary = itineraryService.currentItinerary else { return [] }
        var waypoints: [Waypoint] = []
        
        // Add current waypoint if exists
        if let currentWaypoint = itinerary.currentWaypoint {
            waypoints.append(currentWaypoint)
        }
        
        // Add upcoming waypoints
        waypoints.append(contentsOf: itinerary.upcomingWaypoints)
        
        return waypoints
    }
    
    private var displayedWaypoint: Waypoint? {
        guard !previewableWaypoints.isEmpty, previewWaypointIndex < previewableWaypoints.count else { return nil }
        return previewableWaypoints[previewWaypointIndex]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                RouteMapView(
                    region: $region,
                    mapType: mapType,
                    annotations: allAnnotations,
                    currentRoute: currentRoute,
                    userLocation: locationService.currentLocation,
                    onRegionChange: { newRegion in
                        // Always stop following when user manually moves the map
                        isFollowingUser = false
                        region = newRegion
                    }
                )
                .onAppear {
                    setupLocationTracking()
                    setupItineraryTracking()
                }
                .onChange(of: locationService.currentLocation) { location in
                    if let location = location, isFollowingUser {
                        updateRegionToCurrentLocation(location)
                    }
                    updateRouteIfNeeded()
                }
                .onChange(of: itineraryService.currentItinerary?.currentWaypoint) { waypoint in
                    updateRouteIfNeeded()
                    // Reset preview index when waypoint changes
                    previewWaypointIndex = 0
                }
                .onChange(of: previewWaypointIndex) { _ in
                    updateRouteIfNeeded()
                    fitRouteToScreen()
                }
                .onChange(of: itineraryService.currentItinerary?.waypoints) { _ in
                    updateRouteIfNeeded()
                }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 8) {
                            // Satellite/Map Type Button
                            Button(action: {
                                cycleMapType()
                            }) {
                                Image(systemName: mapTypeIcon)
                                    .foregroundColor(mapTypeColor)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            
                            // Center on User Button
                            Button(action: {
                                centerOnUser()
                            }) {
                                Image(systemName: isFollowingUser ? "location.fill" : "location")
                                    .foregroundColor(isFollowingUser ? .blue : .gray)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            
                            // Navigate to Destination Button
                            if let waypoint = displayedWaypoint {
                                Button(action: {
                                    navigateToDestination()
                                }) {
                                    Image(systemName: "location.north.circle")
                                        .foregroundColor(.green)
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                            }
                            
                        }
                    }
                    .padding()
                    .padding(.top, 60) // Move buttons lower to avoid compass overlay
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Destination distance card with swipe navigation
                        if let waypoint = displayedWaypoint {
                            DestinationDistanceCard(
                                waypoint: waypoint, 
                                locationService: locationService,
                                isCurrentDestination: previewWaypointIndex == 0,
                                currentIndex: previewWaypointIndex,
                                totalCount: previewableWaypoints.count,
                                previewableWaypoints: previewableWaypoints
                            )
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        let threshold: CGFloat = 50
                                        if value.translation.width > threshold {
                                            // Swipe right - go to previous waypoint
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                previewWaypointIndex = max(0, previewWaypointIndex - 1)
                                            }
                                        } else if value.translation.width < -threshold {
                                            // Swipe left - go to next waypoint
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                previewWaypointIndex = min(previewableWaypoints.count - 1, previewWaypointIndex + 1)
                                            }
                                        }
                                    }
                            )
                        }
                        
                        // Group status card with integrated status indicators
                        if let group = groupService.currentGroup {
                            GroupStatusCard(group: group, locationService: locationService)
                        }
                    }
                    .padding()
                    .padding(.bottom, 30) // Move cards higher to avoid Apple Maps logo
                }
            }
            .navigationTitle("group_map".localized)
            .navigationBarTitleDisplayMode(.inline)
            .alert("location_permission".localized, isPresented: .constant(locationService.errorMessage != nil)) {
                Button("settings".localized) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("cancel".localized, role: .cancel) {
                    locationService.errorMessage = nil
                }
            } message: {
                Text(locationService.errorMessage ?? "")
            }
        }
    }
    
    private var memberAnnotations: [MemberAnnotation] {
        guard let group = groupService.currentGroup else { return [] }
        
        return group.members.compactMap { member in
            guard let location = member.location else { return nil }
            return MemberAnnotation(member: member, coordinate: location.coordinate)
        }
    }
    
    private var allAnnotations: [MapViewAnnotationItem] {
        var annotations: [MapViewAnnotationItem] = []
        var usedCoordinates: Set<String> = []
        
        // Helper function to create coordinate key
        func coordinateKey(_ coord: CLLocationCoordinate2D) -> String {
            return "\(String(format: "%.6f", coord.latitude)),\(String(format: "%.6f", coord.longitude))"
        }
        
        // Add member annotations (highest priority)
        for memberAnnotation in memberAnnotations {
            let key = coordinateKey(memberAnnotation.coordinate)
            if !usedCoordinates.contains(key) {
                annotations.append(MapViewAnnotationItem(
                    coordinate: memberAnnotation.coordinate,
                    member: memberAnnotation.member,
                    waypoint: nil,
                    isMember: true,
                    isRouteEndpoint: false
                ))
                usedCoordinates.insert(key)
            }
        }
        
        // Add current waypoint annotation (medium priority, but skip if overlaps with member)
        if let currentWaypoint = itineraryService.currentItinerary?.currentWaypoint {
            let key = coordinateKey(currentWaypoint.location.coordinate)
            if !usedCoordinates.contains(key) {
                annotations.append(MapViewAnnotationItem(
                    coordinate: currentWaypoint.location.coordinate,
                    member: nil,
                    waypoint: currentWaypoint,
                    isMember: false,
                    isRouteEndpoint: false
                ))
                usedCoordinates.insert(key)
            }
        }
        
        // Add route endpoint annotations (always show, even if overlapping)
        if let route = currentRoute {
            // Start point - always add
            if previewWaypointIndex == 0, let userLocation = locationService.currentLocation {
                annotations.append(MapViewAnnotationItem(
                    coordinate: userLocation.coordinate,
                    member: nil,
                    waypoint: nil,
                    isMember: false,
                    isRouteEndpoint: true,
                    routeEndpointType: .start
                ))
            } else if previewWaypointIndex > 0 {
                let previousWaypoint = previewableWaypoints[previewWaypointIndex - 1]
                annotations.append(MapViewAnnotationItem(
                    coordinate: previousWaypoint.location.coordinate,
                    member: nil,
                    waypoint: previousWaypoint,
                    isMember: false,
                    isRouteEndpoint: true,
                    routeEndpointType: .start
                ))
            }
            
            // End point - always add
            if !previewableWaypoints.isEmpty, previewWaypointIndex < previewableWaypoints.count {
                let endWaypoint = previewableWaypoints[previewWaypointIndex]
                annotations.append(MapViewAnnotationItem(
                    coordinate: endWaypoint.location.coordinate,
                    member: nil,
                    waypoint: endWaypoint,
                    isMember: false,
                    isRouteEndpoint: true,
                    routeEndpointType: .end
                ))
            }
        }
        
        return annotations
    }
    
    private var mapStyle: MapStyle {
        switch mapType {
        case .standard:
            return .standard
        case .satellite:
            return .imagery
        case .hybrid:
            return .hybrid
        default:
            return .standard
        }
    }
    
    private var mapTypeIcon: String {
        switch mapType {
        case .standard:
            return "map"
        case .satellite:
            return "globe.americas"
        case .hybrid:
            return "globe.americas.fill"
        default:
            return "map"
        }
    }
    
    private var mapTypeColor: Color {
        switch mapType {
        case .standard:
            return .blue
        case .satellite:
            return .green
        case .hybrid:
            return .purple
        default:
            return .blue
        }
    }
    
    private func setupLocationTracking() {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return }
        
        locationService.requestLocationPermission()
        locationService.startTracking(groupId: group.id, userId: user.id)
    }
    
    private func updateRegionToCurrentLocation(_ location: CLLocation) {
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    private func centerOnUser() {
        isFollowingUser = true
        if let location = locationService.currentLocation {
            updateRegionToCurrentLocation(location)
        }
    }
    
    private func navigateToDestination() {
        guard let waypoint = displayedWaypoint else { return }
        isFollowingUser = false
        
        region = MKCoordinateRegion(
            center: waypoint.location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    private func fitMapToContent() {
        isFollowingUser = false
        
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add user location if available
        if let userLocation = locationService.currentLocation {
            coordinates.append(userLocation.coordinate)
        }
        
        // Add current waypoint if available
        if let currentWaypoint = itineraryService.currentItinerary?.currentWaypoint {
            coordinates.append(currentWaypoint.location.coordinate)
        }
        
        // Add group member locations
        if let group = groupService.currentGroup {
            for member in group.members {
                if let location = member.location {
                    coordinates.append(location.coordinate)
                }
            }
        }
        
        // If we have coordinates, fit to them
        if !coordinates.isEmpty {
            let minLat = coordinates.map(\.latitude).min() ?? 0
            let maxLat = coordinates.map(\.latitude).max() ?? 0
            let minLon = coordinates.map(\.longitude).min() ?? 0
            let maxLon = coordinates.map(\.longitude).max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let latDelta = max(0.01, min(170.0, (maxLat - minLat) * 1.5)) // Cap at 170 degrees max
            let lonDelta = max(0.01, min(170.0, (maxLon - minLon) * 1.5)) // Cap at 170 degrees max
            
            // Validate coordinates are within valid ranges
            guard isValidCoordinate(center.latitude, center.longitude),
                  latDelta <= 180.0,
                  lonDelta <= 180.0 else {
                print("❌ Invalid map region calculated - falling back to user location")
                centerOnUser()
                return
            }
            
            region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        } else {
            // Fallback to user location if no other coordinates
            centerOnUser()
        }
    }
    
    private func isValidCoordinate(_ latitude: Double, _ longitude: Double) -> Bool {
        return latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0
    }
    
    private func setupItineraryTracking() {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return }
        
        // Connect location service to itinerary service for automatic Live Activity management
        itineraryService.setLocationService(locationService)
        
        let isLeader = group.leader?.userId == user.id
        itineraryService.startListeningToItinerary(
            groupId: group.id,
            userId: user.id,
            groupName: group.name,
            userRole: isLeader ? "leader" : "follower",
            leaderName: group.leader?.displayName ?? "",
            memberCount: group.members.count
        )
    }
    
    private func updateRouteIfNeeded() {
        guard let userLocation = locationService.currentLocation else {
            currentRoute = nil
            return
        }
        
        // Cancel previous timer and task
        routeDebounceTimer?.invalidate()
        currentRouteTask?.cancel()
        
        // Debounce route calculation
        routeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            self.currentRouteTask = Task {
                await self.calculateProgressiveRoute(from: userLocation.coordinate)
            }
        }
    }
    
    private func calculateProgressiveRoute(from userLocation: CLLocationCoordinate2D) async {
        guard let itinerary = itineraryService.currentItinerary else {
            await MainActor.run {
                self.currentRoute = nil
            }
            return
        }
        
        // Check if we have waypoints to preview
        guard !previewableWaypoints.isEmpty, previewWaypointIndex < previewableWaypoints.count else {
            await MainActor.run {
                self.currentRoute = nil
            }
            return
        }
        
        let currentPreviewWaypoint = previewableWaypoints[previewWaypointIndex]
        
        if previewWaypointIndex == 0 {
            // Viewing current destination: show route from user to current waypoint
            await calculateSingleRoute(from: userLocation, to: currentPreviewWaypoint.location.coordinate)
        } else {
            // Viewing upcoming destination: show route from previous waypoint to current preview
            let previousWaypoint = previewableWaypoints[previewWaypointIndex - 1]
            await calculateSingleRoute(from: previousWaypoint.location.coordinate, to: currentPreviewWaypoint.location.coordinate)
        }
    }
    
    private func routeCacheKey(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> String {
        return "\(String(format: "%.4f", start.latitude)),\(String(format: "%.4f", start.longitude))-\(String(format: "%.4f", end.latitude)),\(String(format: "%.4f", end.longitude))"
    }
    
    private func calculateSingleRoute(from startCoordinate: CLLocationCoordinate2D, to endCoordinate: CLLocationCoordinate2D) async {
        let cacheKey = routeCacheKey(from: startCoordinate, to: endCoordinate)
        
        // Check cache first
        if let cachedRoute = routeCache[cacheKey] {
            await MainActor.run {
                self.currentRoute = cachedRoute
            }
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoordinate))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                await MainActor.run {
                    // Cache the route
                    self.routeCache[cacheKey] = route
                    
                    // Limit cache size to prevent memory issues
                    if self.routeCache.count > 20 {
                        // Remove oldest entries (simple approach)
                        let keysToRemove = Array(self.routeCache.keys.prefix(5))
                        for key in keysToRemove {
                            self.routeCache.removeValue(forKey: key)
                        }
                    }
                    
                    self.currentRoute = route
                }
            }
        } catch {
            print("Error calculating route: \(error)")
        }
    }
    
    private func fitRouteToScreen() {
        guard !previewableWaypoints.isEmpty,
              previewWaypointIndex < previewableWaypoints.count else { return }
        
        let currentWaypoint = previewableWaypoints[previewWaypointIndex]
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add destination coordinate
        coordinates.append(currentWaypoint.location.coordinate)
        
        // Add start coordinate based on preview index
        if previewWaypointIndex == 0 {
            // Current destination - start from user location
            if let userLocation = locationService.currentLocation {
                coordinates.append(userLocation.coordinate)
            }
        } else if previewWaypointIndex > 0 {
            // Future destination - start from previous waypoint
            let previousWaypoint = previewableWaypoints[previewWaypointIndex - 1]
            coordinates.append(previousWaypoint.location.coordinate)
        }
        
        // Only adjust if we have both start and end points
        guard coordinates.count >= 2 else { return }
        
        isFollowingUser = false
        
        // Calculate bounds with padding
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Add padding to show route clearly (minimum 0.01 degrees)
        let latDelta = max(0.01, (maxLat - minLat) * 1.8)
        let lonDelta = max(0.01, (maxLon - minLon) * 1.8)
        
        // Validate and apply region
        guard isValidCoordinate(center.latitude, center.longitude),
              latDelta <= 180.0,
              lonDelta <= 180.0 else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.8)) {
            region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
    }
    
    private func cycleMapType() {
        switch mapType {
        case .standard:
            mapType = .satellite
        case .satellite:
            mapType = .hybrid
        case .hybrid:
            mapType = .standard
        default:
            mapType = .standard
        }
    }
    
}

struct MemberAnnotation: Identifiable {
    let id = UUID()
    let member: GroupMember
    let coordinate: CLLocationCoordinate2D
}

enum RouteEndpointType {
    case start
    case end
}

struct MapViewAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let member: GroupMember?
    let waypoint: Waypoint?
    let isMember: Bool
    let isRouteEndpoint: Bool
    let routeEndpointType: RouteEndpointType?
    
    init(coordinate: CLLocationCoordinate2D, member: GroupMember?, waypoint: Waypoint?, isMember: Bool, isRouteEndpoint: Bool = false, routeEndpointType: RouteEndpointType? = nil) {
        self.coordinate = coordinate
        self.member = member
        self.waypoint = waypoint
        self.isMember = isMember
        self.isRouteEndpoint = isRouteEndpoint
        self.routeEndpointType = routeEndpointType
    }
}

struct MemberAnnotationView: View {
    let member: GroupMember
    @State private var showIcon = false
    
    var body: some View {
        VStack(spacing: 2) {
            // Show emoji avatar if available
            if let emoji = member.avatarEmoji {
                Text(emoji)
                    .font(.title)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 2)
                    .scaleEffect(showIcon ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showIcon)
                    .onTapGesture {
                        // Show icon temporarily when tapped
                        showIcon = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showIcon = false
                        }
                    }
            }
            
            Text(member.nickname ?? member.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.3), radius: 2)
        }
    }
}

struct WaypointAnnotationView: View {
    let waypoint: Waypoint
    
    var body: some View {
        VStack(spacing: 2) {
            // Small invisible spacer to move text below the coordinate point
            Spacer()
                .frame(height: 10)
            
            Text(waypoint.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.3), radius: 2)
        }
    }
}

struct RouteEndpointAnnotationView: View {
    let type: RouteEndpointType
    
    var body: some View {
        ZStack {
            Circle()
                .fill(type == .start ? Color.green : Color.red)
                .frame(width: 20, height: 20)
            
            Image(systemName: type == .start ? "play.fill" : "flag.fill")
                .foregroundColor(.white)
                .font(.system(size: 10, weight: .bold))
        }
        .shadow(color: .black.opacity(0.3), radius: 2)
    }
}

struct GroupStatusCard: View {
    let group: HitherGroup
    let locationService: LocationService
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var notificationService: NotificationService
    
    private var isLeader: Bool {
        guard let user = authService.currentUser else { return false }
        return group.leader?.userId == user.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group name and tracking status
            HStack {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Circle()
                    .fill(locationService.isTracking ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(locationService.isTracking ? "tracking".localized : "not_tracking".localized)
                    .font(.caption)
                    .foregroundColor(locationService.isTracking ? .green : .red)
            }
            
            // Status indicators row
            HStack(spacing: 12) {
                // Location status
                HStack(spacing: 4) {
                    Circle()
                        .fill(locationService.isTracking ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text("location".localized)
                        .font(.caption2)
                        .foregroundColor(locationService.isTracking ? .green : .red)
                }
                
                // Notification status
                HStack(spacing: 4) {
                    Circle()
                        .fill(notificationService.isEnabled ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    
                    Text("notifications".localized)
                        .font(.caption2)
                        .foregroundColor(notificationService.isEnabled ? .green : .orange)
                }
                
                Spacer()
            }
            
            // Members count and distance to leader (for followers only)
            HStack {
                Text(String(format: "members_simple".localized, group.members.count))
                    .font(.subheadline)
                
                Spacer()
                
                if !isLeader,
                   let leader = group.leader,
                   let leaderLocation = leader.location,
                   let distance = locationService.calculateDistance(to: leaderLocation.coordinate) {
                    Text(String(format: "distance_to_leader".localized, Int(distance)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 4)
    }
}

struct DestinationDistanceCard: View {
    let waypoint: Waypoint
    let locationService: LocationService
    let isCurrentDestination: Bool
    let currentIndex: Int
    let totalCount: Int
    let previewableWaypoints: [Waypoint]
    @EnvironmentObject private var notificationService: NotificationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: waypoint.type.icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(routeContextText)
                        .font(.caption)
                        .foregroundColor(isCurrentDestination ? .green : .blue)
                    
                    Text(waypoint.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if let distance = calculateDistanceToWaypoint() {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(distance))m")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("away".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("--")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text("no_location".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Navigation indicators and progress
            HStack {
                // Left arrow (only show if there are multiple waypoints)
                if totalCount > 1 {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                } else {
                    // Spacer to maintain layout when no arrows
                    Spacer()
                        .frame(width: 20)
                }
                
                Spacer()
                
                // Progress indicator if waypoint is in progress
                if waypoint.isInProgress {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("in_progress".localized)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Navigation dots centered (only show if there are multiple waypoints)
                if totalCount > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<totalCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                
                Spacer()
                
                // Right arrow (only show if there are multiple waypoints)
                if totalCount > 1 {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                } else {
                    // Spacer to maintain layout when no arrows
                    Spacer()
                        .frame(width: 20)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2)
    }
    
    private var routeContextText: String {
        if currentIndex == 0 {
            return "from_current_location".localized
        } else if currentIndex > 0 && currentIndex - 1 < previewableWaypoints.count {
            let previousWaypoint = previewableWaypoints[currentIndex - 1]
            return String(format: "from_waypoint".localized, previousWaypoint.name)
        } else {
            return isCurrentDestination ? "current_destination".localized : "upcoming_destination".localized
        }
    }
    
    private func calculateDistanceToWaypoint() -> Double? {
        guard let userLocation = locationService.currentLocation else { return nil }
        let waypointLocation = CLLocation(latitude: waypoint.location.latitude, longitude: waypoint.location.longitude)
        return userLocation.distance(from: waypointLocation)
    }
}