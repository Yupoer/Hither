# Hither - Group Movement Management App

**Stay Connected, Stay Safe**

Hither is a comprehensive iOS app designed for group movement management during activities like hiking, touring, and family outings. It provides real-time location tracking, directional guidance, and group communication features to help leaders manage groups safely and efficiently.

## Features Implemented

### 🔐 Group Management
- **Firebase Authentication** - Apple ID, Google, and email sign-in
- **Group Creation & Joining** - Time-limited invite codes and QR codes
- **Role-based Access** - Leader and Follower permissions
- **Real-time Member Sync** - Live member list updates

### 📍 Real-time Location Tracking
- **Live GPS Tracking** - Real-time location updates via Firestore
- **Interactive Map** - MapKit integration with member annotations
- **Battery Optimization** - Adaptive update frequencies based on battery level
- **Background Tracking** - Continuous location updates when app is backgrounded

### 🧭 Directional Awareness
- **Compass Mode** - Arrow pointing to group leader with distance display
- **Precision Finding** - UWB-based close-range guidance for supported devices
- **Direction Calculations** - Real-time bearing and distance calculations
- **Visual Indicators** - Cardinal directions and distance formatting

### 📢 Broadcast Commands
- **Quick Commands** - 8 preset commands (Gather, Depart, Rest, Be Careful, etc.)
- **Custom Messages** - Text and voice message broadcasting
- **Real-time Notifications** - Instant delivery to all group members
- **Command History** - Chronological timeline of all group communications

### 🗺️ Itinerary Management
- **Waypoint Creation** - 7 types: Meeting Point, Rest Stop, Lunch, Destination, etc.
- **Map-based Location Picker** - Precise waypoint placement
- **Real-time Sync** - Instant itinerary updates across all members
- **Progress Tracking** - Waypoint completion and distance calculations

### 🎨 Role-based UI/UX
- **Leader Interface** - Group management, command broadcasting, itinerary control
- **Follower Interface** - Direction finding, command receiving, itinerary following
- **Visual Role Indicators** - Crown icons for leaders, person icons for followers
- **Status Indicators** - Location freshness, connection status, battery level

### 📱 ActivityKit & Live Activities
- **Lock Screen Widgets** - Real-time group status on Lock Screen
- **Dynamic Island** - Distance to leader and group commands
- **Live Updates** - Group status, distance, and command notifications
- **Battery Efficient** - Optimized for minimal power consumption

### 🔔 Push Notifications
- **Smart Categories** - Different notification types for commands, itinerary, alerts
- **Interactive Actions** - Quick response buttons for common actions
- **Permission Handling** - Graceful permission request flows
- **Background Delivery** - Notifications work even when app is closed

### ⚡ Battery Optimization
- **Adaptive Intervals** - Location update frequency based on battery level
- **Precision Scaling** - Reduced GPS accuracy when battery is low
- **Low Battery Alerts** - Warnings when battery affects tracking
- **Charging Detection** - More frequent updates when device is charging

### 🛠️ Error Handling & Status
- **Connection Monitoring** - Real-time status of location, notifications, battery
- **Error Recovery** - Retry mechanisms and user-friendly error messages
- **Permission Flows** - Guided setup for location and notification permissions
- **Status Transparency** - Clear indicators for all system states

## Tech Stack

- **iOS:** SwiftUI, iOS 16.1+ (for ActivityKit)
- **Backend:** Firebase (Authentication, Firestore, Cloud Messaging)
- **Core Frameworks:**
  - CoreLocation: GPS positioning and calculations
  - MapKit: Map display and annotations
  - NearbyInteraction: UWB precision finding
  - ActivityKit: Live Activities and Dynamic Island
  - UserNotifications: Local and push notifications

## Project Structure

```
Hither/
├── Models/           # Data models (User, Group, Command, Itinerary)
├── Services/         # Business logic services
│   ├── AuthenticationService.swift
│   ├── GroupService.swift
│   ├── LocationService.swift
│   ├── DirectionService.swift
│   ├── CommandService.swift
│   ├── ItineraryService.swift
│   ├── LiveActivityService.swift
│   └── NotificationService.swift
├── Views/            # SwiftUI views organized by feature
│   ├── Authentication/
│   ├── Group/
│   ├── Map/
│   ├── Direction/
│   ├── Commands/
│   ├── Itinerary/
│   └── Components/
└── Assets.xcassets/  # App icons and assets
```

## Getting Started

1. **Prerequisites:**
   - Xcode 15.0+
   - iOS 16.1+ device or simulator
   - Firebase project with Firestore and Authentication enabled

2. **Setup:**
   - Replace `GoogleService-Info.plist` with your Firebase configuration
   - Configure Firebase Authentication providers (Apple, Google, Email)
   - Set up Firestore security rules for the app

3. **Build:**
   ```bash
   open Hither.xcodeproj
   # Build and run in Xcode
   ```

## Key User Scenarios

### Hiking Scenario
1. Leader creates group "Yangmingshan Grand Traverse"
2. Members join via invite code shared in messaging app
3. Leader monitors all member positions on map during hike
4. When members fall behind, leader sends "Rest for 5 minutes" command
5. Followers use compass mode to navigate back to group
6. Weather changes - leader updates itinerary to nearest shelter

### Theme Park Scenario
1. Family creates group at Universal Studios
2. Members split up to enjoy different attractions
3. Daughter uses precision finding to locate parents after ride
4. Father receives notification when daughter requests souvenir shopping stop
5. Live Activities show distance to family members on Lock Screen
6. Push notifications alert family when someone needs assistance

## Success Metrics (from PRD)

- **Target:** 10,000 Monthly Active Users (MAU)
- **Goal:** 5,000+ groups created within 6 months
- **Usage:** 80% of active groups use core features weekly
- **Rating:** 4.5+ stars on App Store
- **Retention:** 40% next-month retention rate

## Future Enhancements

- **Android Version** - Cross-platform group support
- **Offline Maps** - Pre-downloaded maps for offline use
- **Geo-fencing** - Safe zone alerts and notifications
- **Apple Watch** - Wearable companion app
- **Advanced Analytics** - Trip summaries and insights

---

**Built with Claude Code** 🤖

*Generated with comprehensive feature implementation based on detailed PRD specifications.*