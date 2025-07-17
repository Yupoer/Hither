import SwiftUI
import MapKit
import CoreLocation

struct ItineraryView: View {
    @EnvironmentObject private var groupService: GroupService
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var itineraryService = ItineraryService()
    @StateObject private var locationService = LocationService()
    @State private var showingAddWaypoint = false
    @State private var selectedWaypoint: Waypoint?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let group = groupService.currentGroup,
                   let user = authService.currentUser {

                    if group.leader?.userId == user.id {
                        leaderItineraryView(group: group, user: user)
                    } else {
                        followerItineraryView(group: group, user: user)
                    }
                } else {
                    Text("Join a group to view itinerary")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Itinerary")
            .navigationBarItems(trailing: isLeader ? AnyView(addWaypointButton) : AnyView(EmptyView()))
            .onAppear { setupItineraryService() }
            .sheet(isPresented: $showingAddWaypoint) {
                AddWaypointSheet(
                    itineraryService: itineraryService,
                    groupId: groupService.currentGroup?.id ?? "",
                    userId: authService.currentUser?.id ?? "",
                    userName: authService.currentUser?.displayName ?? ""
                )
            }
            .sheet(item: $selectedWaypoint) { waypoint in
                WaypointDetailSheet(
                    waypoint: waypoint,
                    itineraryService: itineraryService,
                    groupId: groupService.currentGroup?.id ?? "",
                    userId: authService.currentUser?.id ?? "",
                    userName: authService.currentUser?.displayName ?? "",
                    isLeader: isLeader
                )
            }
        }
    }

    private var isLeader: Bool {
        guard let group = groupService.currentGroup,
              let user = authService.currentUser else { return false }
        return group.leader?.userId == user.id
    }

    private var addWaypointButton: some View {
        Button(action: { showingAddWaypoint = true }) {
            Image(systemName: "plus")
        }
    }

    @ViewBuilder
    private func leaderItineraryView(group: HitherGroup, user: HitherUser) -> some View {
        VStack(spacing: 16) {
            itineraryHeader(title: "Manage Itinerary", subtitle: "Add waypoints and guide your group")
            itineraryContent()
        }
    }

    @ViewBuilder
    private func followerItineraryView(group: HitherGroup, user: HitherUser) -> some View {
        VStack(spacing: 16) {
            itineraryHeader(title: "Group Itinerary", subtitle: "Follow the planned route")
            if let currentWaypoint = itineraryService.currentItinerary?.currentWaypoint {
                NextWaypointCard(waypoint: currentWaypoint, locationService: locationService)
                    .padding(.horizontal)
            } else if let nextWaypoint = itineraryService.currentItinerary?.nextWaypoint {
                NextWaypointCard(waypoint: nextWaypoint, locationService: locationService)
                    .padding(.horizontal)
            }
            itineraryContent()
        }
    }

    private func itineraryHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    @ViewBuilder
    private func itineraryContent() -> some View {
        if let itinerary = itineraryService.currentItinerary {
            if itinerary.waypoints.isEmpty {
                emptyItineraryView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        waypointSection(title: "Upcoming", waypoints: itinerary.activeWaypoints, isCompleted: false)
                        waypointSection(title: "Completed", waypoints: itinerary.completedWaypoints, isCompleted: true)
                    }
                    .padding(.horizontal)
                }
            }
        } else {
            ProgressView("Loading itinerary...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        if itineraryService.isLoading {
            ProgressView().padding()
        }

        if let errorMessage = itineraryService.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .padding()
        }
    }

    private func emptyItineraryView() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No waypoints yet")
                .font(.headline)
                .foregroundColor(.secondary)
            if isLeader {
                Text("Tap + to add your first waypoint")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func waypointSection(title: String, waypoints: [Waypoint], isCompleted: Bool) -> some View {
        if !waypoints.isEmpty {
            Section {
                ForEach(waypoints) { waypoint in
                    WaypointCard(
                        waypoint: waypoint,
                        locationService: locationService,
                        isLeader: isLeader,
                        onTap: { selectedWaypoint = waypoint },
                        onComplete: isLeader && !waypoint.isCompleted ? {
                            Task {
                                guard let groupId = groupService.currentGroup?.id,
                                      let userId = authService.currentUser?.id else { return }
                                await itineraryService.markWaypointCompleted(
                                    waypointId: waypoint.id,
                                    groupId: groupId,
                                    updatedBy: userId
                                )
                            }
                        } : nil
                    )
                }
            } header: {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, isCompleted ? 8 : 0)
            }
        }
    }

    private func setupItineraryService() {
        guard let group = groupService.currentGroup else { return }
        itineraryService.startListeningToItinerary(groupId: group.id)

        if let user = authService.currentUser {
            locationService.startTracking(groupId: group.id, userId: user.id)
        }
    }
}
