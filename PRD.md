# Hither App Product Requirements Document

**Version:** 1.0
**Document Status:** Draft

## 1. Introduction & Vision

### 1.1. Product Name
Hither

### 1.2. Problem Statement
During group travel, outdoor activities, or family outings, it is difficult for a leader to know the exact real-time location of all members, leading to the risk of individuals getting lost or falling behind. Traditional communication methods (like phone calls or instant messaging apps) are inefficient for conveying instructions such as gathering, taking a break, or changing plans, often causing information delays or omissions. Furthermore, when the itinerary needs to be changed unexpectedly, the lack of an effective tool to quickly synchronize information with all members compromises the overall experience and safety of the activity.

### 1.3. Vision
Hither aims to be the premier tool for group movement management. Through precise real-time positioning, clear and intuitive directional guidance, and powerful team communication and itinerary coordination features, we want to make every group outing safer, smoother, and more enjoyable. Whether for professional tour leaders, family trip organizers, or outdoor activity conveners, Hither will enable them to lead their teams with ease and enjoy a worry-free journey.

### 1.4. Target Audience
*   **Professional Tour Leaders/Guides:** Need to manage large tour groups, ensuring tourist safety and timely arrival at each destination.
*   **Family Trip Organizers:** Need to ensure elderly members and children do not get separated in complex environments like theme parks or foreign cities.
*   **Outdoor Activity Enthusiasts:** Conveners of activities like hiking, trekking, and cycling teams who need to maintain team contact in the wilderness or areas with poor signal.
*   **School Field Trip/Company Outing Coordinators:** Need to effectively manage students or employees to ensure the event proceeds smoothly.

### 1.5. Success Metrics
*   **User Activity:** Achieve 10,000 Monthly Active Users (MAU).
*   **Number of Groups Created:** Over 5,000 groups created by users within six months of launch.
*   **Core Feature Usage Rate:** 80% of active groups use the "Broadcast Command" or "Real-time Location" feature at least once a week.
*   **App Store Rating:** Maintain an average rating of 4.5 stars or higher.
*   **User Retention Rate:** Achieve a next-month retention rate of 40%.

## 2. User Personas & Scenarios

### 2.1. User Personas

*   **Leo the Leader:**
    *   **Background:** 45-year-old experienced hiking club leader who leads groups of 10-20 people on suburban hikes every month.
    *   **Pain Points:** Team members have varying physical abilities, causing the group to spread out. It's difficult to confirm the safety of members at the rear. Waiting and taking roll call at trail forks is time-consuming. Walkie-talkie communication can be disrupted by terrain.
    *   **Goals:** Wants a tool to see all members' locations at a glance and to send simple commands like "Rest for 5 minutes" or "Take the right fork ahead" with one tap to ensure everyone's safety.

*   **Fiona the Follower:**
    *   **Background:** 28-year-old who enjoys traveling abroad independently with friends and family. She has a poor sense of direction and easily gets separated in crowded attractions or shopping malls.
    *   **Pain Points:** Frequently needs to call or text "Where are you?". Sometimes she wants to use the restroom or browse a shop a little longer but is hesitant to speak up, fearing she'll delay the group.
    *   **Goals:** Hopes to clearly know her relative direction and distance from the leader to feel secure. Also wants a non-disruptive way to request things like "I want to find a restroom" or "I'd like to stay here for 10 more minutes."

### 2.2. User Scenarios

*   **Scenario 1: Hiking Activity**
    *   **Before Departure:** Leo the Leader creates a Hither group named "Yangmingshan Grand Traverse" and shares the invitation link in their LINE group. Members join by clicking the link.
    *   **On the Move:** Leo, leading from the front, occasionally opens Hither's map view to confirm all member icons are on the route. He notices two members have fallen behind by over 500 meters and uses the "Broadcast Command" to send a message: "Everyone rest for 5 minutes, wait for members at the back."
    *   **Directional Guidance:** A member who temporarily steps off the trail to take photos opens Hither's "Directional Awareness" mode. An arrow clearly points towards Leo, allowing them to rejoin the group quickly.
    *   **Unexpected Situation:** It starts raining heavily. Leo decides to cancel the rest of the trip and head to the nearest bus stop. He uses the "Itinerary Adjustment" feature to change the destination to the bus stop. All members' apps receive a push notification about the route change and an updated map.

*   **Scenario 2: Family Trip in Japan**
    *   **At Universal Studios:** The father acts as the leader, while the mother and Fiona are followers. They agree to split up and enjoy their preferred rides.
    *   **Finding Each Other:** After a ride, Fiona wants to find her parents. She opens Hither and activates the UWB-supported "Precision Finding" feature. The interface displays "Dad is 15 meters to your front-right," helping her locate her family quickly.
    *   **Making a Request:** Fiona passes a souvenir shop she wants to visit. She sends a "Request to Add Stop" to her dad via the app, with the message "I want to browse this shop for 15 minutes."
    *   **Leader's Decision:** Her dad receives the request notification, sees Fiona's location and her message. He assesses the schedule and taps "Approve." Both mother and Fiona receive a "Request Approved" notification.
    *   **Live Information:** On her iPhone's Lock Screen, Fiona can see her distance from her dad at any time via "Live Activities (ActivityKit)," without constantly unlocking her phone.

## 3. Functional Requirements

### 3.1. MVP Core Features

#### 3.1.1. Group Management
*   **User Authentication (Firebase Authentication):** Users can sign up and log in using Apple ID, Google, or email. The system assigns a unique UID to each user upon login.
*   **Create Group:** Any user can create a new group and automatically becomes the "Leader." The group name and event date can be set during creation.
*   **Invite & Join:** The leader can generate a time-limited (e.g., 24-hour) invitation link or QR Code. Other users can join the group as "Followers" by clicking the link or scanning the QR Code.
*   **Group Information (Firestore):** Stores basic group info (name, ID). Stores a member list, including each member's UID, role (Leader/Follower), and nickname.

#### 3.1.2. 📍 Real-time Location Module
*   **Map View (MapKit):** Displays the real-time location of all members on a map with different icons (e.g., a crown for the Leader, dots for Followers). Users can zoom and pan the map. Provides standard, satellite, and hybrid map modes.
*   **Location Updates (CoreLocation & Firestore):** The app, in background mode, periodically fetches the user's GPS location (e.g., every 30-60 seconds, adjustable based on movement speed). Coordinates are synced to Firestore in real-time, and all group members' apps listen for database changes to update the map. Battery usage must be optimized by reducing update frequency when stationary.

#### 3.1.3. 🧭 Directional Awareness Module
*   **Relative Direction & Distance Guidance:** Provides a non-map "Compass Mode." The screen displays a large arrow that always points toward the leader. The distance to the leader is shown below or inside the arrow (e.g., "150 meters").
*   **Precision Finding (NearbyInteraction - for supported devices):** This feature can be enabled when members are less than 50 meters apart and their devices support UWB chips. The interface provides more precise directional cues and distance, similar to the AirTag finding experience.

#### 3.1.4. 📣 Broadcast Command Module
*   **Quick Commands:** The leader's interface provides several preset quick command buttons, such as: "Gather," "Depart," "Rest," "Be careful," "Go Left," "Go Right." Tapping a command sends it to all followers via FCM push notifications and in-app alerts.
*   **Custom Messages:** The leader can send short text or voice messages to the entire group. Messages are displayed prominently within the app and accompanied by a push notification.

#### 3.1.5. ⛳ Itinerary Adjustment Module
*   **Simple Itinerary Points:** The leader can set several key points on the map (e.g., meeting point, lunch spot, destination). These points are marked on all members' maps.
*   **Real-time Adjustments:** The leader can add, delete, or move itinerary points at any time. Any changes are synced in real-time via Firestore, and an "Itinerary Updated" push notification (UserNotifications) is sent to all members.

### 3.2. Post-MVP Features

#### 3.2.1. Follower Request System
*   **Make a Request:** The follower interface provides shortcut buttons to make requests, such as: "Request a break," "Request to add a stop," "Request to change itinerary." A short description can be attached to the request (e.g., "I need to use the restroom").
*   **Notification Mechanism:** Requests are sent to the leader (primary notification) and other followers (secondary notification).

#### 3.2.2. Leader Decision System
*   **Review Interface:** The leader receives a notification card with "Approve" and "Decline" buttons. The leader can see who made the request, its content, and location.
*   **Result Sync:** The leader's decision is sent back to all members and displayed as "Request Approved" or "Request Declined."

### 3.3. Tech Stack & Implementation
*   **iOS Frameworks:**
    *   **CoreLocation:** To get GPS positions and calculate distances between members.
    *   **MapKit:** To display maps, pins, and routes.
    *   **NearbyInteraction:** To implement high-precision close-range finding.
    *   **ActivityKit:** To display real-time information on the Lock Screen, like distance to the leader or the next stop.
    *   **UserNotifications:** To send local/remote push notifications for arrival alerts, broadcast commands, and status changes.
*   **Backend (Firebase):**
    *   **Authentication:** To handle user login and identity verification.
    *   **Firestore:** As the primary real-time database for storing group, member, location, itinerary, and request data.
    *   **Cloud Messaging (FCM):** To push important notifications in real-time when the app is closed or in the background.

## 4. Design & UX

### 4.1. Key UI Flows
*   **Onboarding:** A clean set of introductory screens explaining the app's core values (Safety, Sync, Stay Connected), guiding the user to log in.
*   **Main Interface (Map View):** Centered around the map, clearly marking the user and all members. A bottom or side panel provides the leader with quick access to "Broadcast Command" and "Itinerary Management." For followers, it provides buttons for "Directional Awareness" and "Make a Request."
*   **Directional Awareness Interface (Compass/AR View):** A minimalist design with only a large directional arrow and distance number, eliminating all unnecessary distractions.
*   **Communication Interface:** A timeline format that clearly and chronologically displays all commands from the leader and system notifications.

### 4.2. Design Principles
*   **Ease of Use First:** Operations must be intuitive, allowing even users less familiar with digital products (like seniors) to use it easily. This is especially critical for leaders who need to operate the app quickly while managing a group.
*   **Information Clarity:** On any screen, the most important information (like direction, distance, latest command) must be the most prominent.
*   **Battery Optimization:** Design and development must prioritize battery life to prevent the app from being a power drain.
*   **Status Transparency:** Users need to be clearly aware of the app's current connection status, location accuracy, etc.

## 5. Future Roadmap
*   **Android Version Development:** Expand the user base and support cross-platform groups.
*   **Web-based Admin Panel:** Allow professional travel agencies to pre-plan itineraries and manage multiple groups on a computer.
*   **Offline Maps:** Allow users to pre-download maps of specific areas for use in offline outdoor environments.
*   **Geo-fencing & Alerts:** Allow leaders to set a safe zone. When a member leaves this area, both the leader and the member receive an alert.
*   **Data Analytics:** Provide leaders with a post-activity summary, including total distance, average speed, number of times members went off-track, etc.
*   **Third-party Integration:** Integrate with Apple Watch for more convenient notifications and directional guidance.