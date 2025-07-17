# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hither is an iOS app for group movement management during activities like hiking, touring, and family outings. It solves the problem of leaders losing track of group members and inefficient communication during group activities. The app provides real-time location tracking, directional guidance, and group communication features to help leaders manage groups safely and efficiently.

### Target Users
- Professional tour leaders/guides managing large groups
- Family trip organizers keeping elderly and children together
- Outdoor activity enthusiasts leading hiking/cycling groups
- School field trip/company outing coordinators

### Success Metrics (from PRD)
- 10,000 Monthly Active Users (MAU)
- 5,000+ groups created within 6 months
- 80% of active groups use core features weekly
- 4.5+ App Store rating
- 40% next-month retention rate

## Tech Stack

- **iOS:** SwiftUI app targeting iOS with Xcode project structure
- **Backend:** Firebase (Authentication, Firestore, Cloud Messaging)
- **Core Frameworks:**
  - CoreLocation: GPS positioning and distance calculations
  - MapKit: Map display and route visualization  
  - NearbyInteraction: UWB-based precision finding for close-range guidance
  - ActivityKit: Lock screen Live Activities for distance display
  - UserNotifications: Push notifications for commands and alerts

## Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild -project Hither.xcodeproj -scheme Hither build

# Run tests
xcodebuild -project Hither.xcodeproj -scheme Hither test

# Run UI tests
xcodebuild -project Hither.xcodeproj -scheme Hither -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Opening in Xcode
```bash
open Hither.xcodeproj
```

## Architecture

### MVP Core Features (from PRD)

#### 📍 Real-time Location Module
- **Map View (MapKit):** Real-time location display of all members with role-based icons (crown for Leader, dots for Followers)
- **Location Updates:** Background GPS tracking every 30-60 seconds, synced via Firestore with battery optimization when stationary
- Standard/satellite/hybrid map modes

#### 🧭 Directional Awareness Module  
- **Compass Mode:** Large arrow always pointing toward leader with distance display
- **Precision Finding (NearbyInteraction):** UWB-based precise guidance for <50m range on supported devices (similar to AirTag experience)

#### 📣 Broadcast Command Module
- **Quick Commands:** Preset buttons for "Gather," "Depart," "Rest," "Be careful," directional commands
- **Custom Messages:** Text/voice messages sent to entire group via FCM push notifications

#### ⛳ Itinerary Adjustment Module
- **Itinerary Points:** Leader sets key points (meeting spot, lunch, destination) marked on all maps
- **Real-time Adjustments:** Add/delete/move points with instant Firestore sync and push notifications

#### Group Management
- **Authentication:** Apple ID, Google, or email login via Firebase Auth
- **Group Creation:** Leader creates group, generates time-limited invitation links/QR codes
- **Member Roles:** Leader (crown icon) vs Followers (dot icons) with different UI capabilities

### Post-MVP Features (from PRD)
- **Follower Request System:** "Request a break," "Request to add stop," etc. with approval workflow
- **Leader Decision System:** Review interface with approve/decline for follower requests

### Key Design Patterns
- SwiftUI declarative UI with real-time Firestore listeners
- Background location updates with battery optimization based on movement  
- Role-based UI (Leader vs Follower interfaces with different capabilities)
- Real-time synchronization using Firestore observers
- Push notification integration for group communication

### Design Principles (from PRD)
- **Ease of Use First:** Intuitive for all ages, especially seniors
- **Information Clarity:** Most important info (direction, distance, commands) prominently displayed
- **Battery Optimization:** Minimize power drain during extended outdoor use
- **Status Transparency:** Clear connection status and location accuracy indicators

### Current State
- Basic SwiftUI project structure with Firebase dependencies configured
- Contains placeholder ContentView with "Hello, world!" - needs full implementation
- Firebase packages already added: FirebaseCore, FirebaseAuth, FirebaseFirestore
- GoogleService-Info.plist configured for Firebase integration

### Key User Scenarios (from PRD)
1. **Hiking:** Leader monitors member positions on trail, sends rest commands, handles weather changes
2. **Theme Park:** Family splits up, uses precision finding to reunite, manages stop requests with approval workflow

## Firebase Dependencies
The project uses Firebase Swift Package Manager dependencies:
- FirebaseCore
- FirebaseAuth  
- FirebaseFirestore

Location of Firebase config: `Hither/GoogleService-Info.plist`