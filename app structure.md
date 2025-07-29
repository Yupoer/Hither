# Hither 應用結構與架構

## 概述

Hither 是一個基於 SwiftUI 的 iOS 應用程式，用於群組位置追蹤和管理。本文檔概述了應用程式的架構、文件結構和組件組織。

## 架構模式

### MVVM + 服務層架構

```
視圖 (SwiftUI) → 視圖模型 (服務) → 模型 → Firebase 後端
```

**核心組件：**
- **視圖**：SwiftUI 視圖用於 UI 展示
- **服務**：業務邏輯和數據管理 (@MainActor ObservableObject)
- **模型**：數據結構和業務實體
- **Firebase**：後端即服務用於數據持久化

## 專案結構

```
Hither/
├── App/
│   ├── HitherApp.swift                 # 應用程式入口點
│   └── ContentView.swift               # 根視圖控制器
├── Models/
│   ├── Group.swift                     # 群組相關數據模型
│   ├── User.swift                      # 用戶數據模型
│   └── ActivityAttributes.swift        # Live Activity 屬性
├── Services/
│   ├── AuthenticationService.swift     # Firebase Auth 整合
│   ├── GroupService.swift              # 群組管理邏輯
│   ├── LocationService.swift           # CoreLocation 包裝器
│   ├── ItineraryService.swift          # 航點管理
│   └── LiveActivityService.swift       # ActivityKit 整合
├── Views/
│   ├── Auth/
│   │   └── LoginView.swift             # 驗證 UI
│   ├── Group/
│   │   ├── GroupSetupView.swift        # 群組創建/加入
│   │   └── GroupDetailsView.swift      # 群組管理
│   ├── Map/
│   │   └── MapView.swift               # 實時位置顯示
│   ├── Direction/
│   │   └── DirectionView.swift         # 指南針和導航
│   ├── Itinerary/
│   │   ├── ItineraryView.swift         # 航點管理
│   │   └── AddWaypointSheet.swift      # 航點創建
│   ├── Commands/
│   │   └── CommandsView.swift          # 廣播命令
│   └── Components/
│       ├── RoleIndicatorView.swift     # 可重複使用的 UI 組件
│       └── QuickActionButton.swift     # 按鈕組件
├── Extensions/
│   └── String+Extensions.swift         # 工具擴展
├── Resources/
│   ├── GoogleService-Info.plist        # Firebase 配置
│   └── Assets.xcassets                 # 應用程式資源
└── Widgets/
    ├── WidgetsExtension.swift          # 小工具擴展
    └── WidgetsLiveActivity.swift       # Live Activity 小工具
```

## 核心服務

### 1. AuthenticationService

**目的**：管理用戶驗證和會話狀態

**主要功能：**
- Firebase Auth 整合 (Google、Apple ID、電子郵件)
- 用戶會話管理
- 個人資料更新 (顯示名稱、照片)

**屬性：**
```swift
@Published var isAuthenticated: Bool
@Published var currentUser: HitherUser?
@Published var isLoading: Bool
```

**方法：**
- `signInWithGoogle()` - Google 登錄
- `signInWithApple()` - Apple 登錄
- `signOut()` - 用戶登出
- `updateProfile()` - 個人資料更新

### 2. GroupService

**目的**：核心群組管理和 Firebase 同步

**主要功能：**
- 群組創建和加入
- 實時成員同步
- 自動領導者轉移
- 數據驗證和修復

**屬性：**
```swift
@Published var currentGroup: HitherGroup?
@Published var allUserGroups: [HitherGroup]
@Published var isLoading: Bool
@Published var errorMessage: String?
```

**方法：**
- `createGroup()` - 創建新群組
- `joinGroup()` - 加入現有群組
- `leaveGroup()` - 離開群組並清理
- `generateNewInviteCode()` - 刷新邀請碼
- `cleanupGroupData()` - 修復損壞的數據

### 3. LocationService

**目的**：GPS 位置追蹤和分享

**主要功能：**
- 背景位置更新
- 電池優化
- 權限管理
- 位置精度監控

### 4. ItineraryService

**目的**：航點和路線管理

**主要功能：**
- 航點創建和管理
- 路線計算
- 逐步導航
- 實時同步

### 5. LiveActivityService

**目的**：iOS 16.1+ Live Activities 整合

**主要功能：**
- 鎖屏距離顯示
- Dynamic Island 整合
- 實時更新
- 電池高效更新

## 數據模型

### 核心模型

#### HitherGroup
```swift
struct HitherGroup: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let leaderId: String
    let createdAt: Date
    let inviteCode: String
    let inviteExpiresAt: Date
    var members: [GroupMember]
    var isActive: Bool
}
```

#### GroupMember
```swift
struct GroupMember: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let displayName: String
    let role: MemberRole
    let joinedAt: Date
    var location: GeoPoint?
    var lastLocationUpdate: Date?
}
```

#### HitherUser
```swift
struct HitherUser: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String
    let photoURL: String?
}
```

#### MemberRole
```swift
enum MemberRole: String, Codable, CaseIterable {
    case leader = "leader"
    case follower = "follower"
}
```

## 視圖架構

### 導航結構

```
ContentView (根視圖)
├── LoginView (未驗證)
├── NicknameSetupView (首次用戶)
└── GroupSetupView (主要入口)
    └── MainTabView (群組活動)
        ├── MapView (標籤 1)
        ├── DirectionView (標籤 2)
        ├── ItineraryView (標籤 3)
        ├── CommandsView (標籤 4)
        └── GroupDetailsView (標籤 5)
```

### 視圖責任

#### ContentView
- 根導航控制器
- 深層鏈接處理
- 驗證流程管理
- 暱稱設置協調

#### GroupSetupView
- 群組創建界面
- 群組加入界面
- 多群組管理
- QR 碼掃描

#### MainTabView
- 基於標籤的導航
- 服務注入
- 狀態管理協調

#### MapView
- 實時位置顯示
- 成員視覺化
- 地圖交互（縮放、平移）
- 路線覆蓋

#### DirectionView
- 指南針界面
- 距離計算
- 精密定位 (UWB)
- 電池優化

#### ItineraryView
- 航點列表管理
- 路線規劃
- 逐步導航
- 領導者/追隨者工作流程

#### CommandsView
- 廣播消息
- 快速命令按鈕
- 推送通知觸發
- 語音消息支持

#### GroupDetailsView
- 成員管理
- 群組設置
- 邀請碼分享
- 離開群組功能

## 組件架構

### 可重複使用的組件

#### QuickActionButton
```swift
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
}
```

#### RoleIndicatorView
```swift
struct RoleIndicatorView: View {
    let role: MemberRole
    let size: CGFloat
}
```

#### StatusIndicatorView
```swift
struct StatusIndicatorView: View {
    let isActive: Bool
    let title: String
    let size: CGFloat
}
```

#### GroupHeaderView
```swift
struct GroupHeaderView: View {
    let group: HitherGroup
    let currentUser: HitherUser
}
```

## 狀態管理

### 環境對象

服務作為環境對象注入到整個視圖階層中：

```swift
@EnvironmentObject private var authService: AuthenticationService
@EnvironmentObject private var groupService: GroupService
@EnvironmentObject private var locationService: LocationService
```

### @MainActor 併發

所有服務都標記為 `@MainActor` 以確保 UI 更新在主線程上進行：

```swift
@MainActor
class GroupService: ObservableObject {
    @Published var currentGroup: HitherGroup?
    // ...
}
```

## 深層鏈接與 URL 方案

### 自定義 URL 方案：`hither://`

**支持的 URL：**
- `hither://join?code=ABC123&name=Group%20Name`

**處理：**
1. AppDelegate/SceneDelegate 捕獲 URL
2. ContentView.onOpenURL 處理深層鏈接
3. 提取參數並顯示加入確認
4. GroupService 處理實際加入流程

## 推送通知

### Firebase Cloud Messaging 整合

**通知類別：**
- 群組命令（集合、出發、休息）
- 航點更新（新增、修改、刪除）
- 成員警報（加入、離開、位置過期）

**實現：**
- FCM 令牌註冊
- 通知權限處理
- 背景通知處理
- 操作按鈕處理

## Live Activities (iOS 16.1+)

### ActivityKit 整合

**功能：**
- 鎖屏距離顯示
- Dynamic Island 整合
- 實時位置更新
- 電池高效更新

**實現：**
```swift
struct ActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let distance: Double
        let lastUpdate: Date
        let leaderName: String
    }
    
    let groupName: String
    let groupId: String
}
```

## 小工具擴展

### 小工具類型

1. **距離小工具**：顯示到領導者的距離
2. **群組狀態小工具**：顯示群組資訊和成員數量
3. **下一個航點小工具**：顯示即將到達的航點

## 安全與隱私

### 數據保護

1. **Firebase 安全規則**：伺服器端存取控制
2. **Keychain 存儲**：安全憑證存儲
3. **位置隱私**：用戶控制的位置分享
4. **數據加密**：敏感數據加密

### 隱私功能

1. **位置權限**：細粒度位置存取
2. **通知權限**：用戶控制的通知
3. **照片存取**：可選的個人資料照片存取
4. **背景應用刷新**：用戶控制的背景更新

## 測試策略

### 單元測試

- 服務層邏輯
- 數據模型驗證
- 工具函數
- 錯誤處理

### 整合測試

- Firebase 整合
- 位置服務整合
- 推送通知處理
- 深層鏈接處理

### UI 測試

- 用戶流程驗證
- 輔助功能測試
- 性能測試
- 設備兼容性

## 性能優化

### 記憶體管理

1. **監聽器清理**：正確的 Firestore 監聽器移除
2. **弱引用**：防止保留循環
3. **延遲加載**：按需加載數據
4. **圖像緩存**：高效的圖像加載

### 電池優化

1. **自適應位置更新**：基於移動的頻率
2. **背景處理**：最少的背景工作
3. **網絡效率**：批量 Firebase 操作
4. **UI 優化**：高效的 SwiftUI 更新

## 構建配置

### Xcode 專案設置

- **部署目標**：iOS 15.0+
- **Swift 版本**：5.0+
- **方向**：僅縱向
- **背景模式**：位置、背景處理

### Firebase 配置

- **GoogleService-Info.plist**：Firebase 專案配置
- **Bundle Identifier**：Firebase 的應用程式識別符
- **API 金鑰**：Firebase 服務憑證

## 未來架構考慮

### 計劃增強

1. **離線支援**：本地數據緩存和同步
2. **衝突解決**：樂觀更新和回滾
3. **微服務**：可擴展性的服務分解
4. **GraphQL**：高效的數據獲取
5. **SwiftUI 導航**：iOS 16+ NavigationStack 採用

### 可擴展性考慮

1. **數據庫分片**：Firebase 集合分區
2. **CDN 整合**：資源交付優化
3. **負載平衡**：Firebase Functions 擴展
4. **緩存策略**：多級數據緩存