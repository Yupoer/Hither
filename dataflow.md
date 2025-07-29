# Hither 數據流與 Firebase 整合

## 概述

本文檔描述了 Hither iOS 應用程式與 Firebase 後端之間的數據流，包括數據格式、同步模式和 API 交互。

## Firebase 集合

### 群組集合 (`/groups/{groupId}`)

**文檔結構：**
```json
{
  "id": "UUID-字符串",
  "name": "群組名稱",
  "leaderId": "用戶ID字符串",
  "createdAt": "Firebase 時間戳",
  "inviteCode": "6位字母數字邀請碼",
  "inviteExpiresAt": "Firebase 時間戳 (創建後24小時)",
  "isActive": true,
  "members": [
    {
      "id": "成員uuid",
      "userId": "用戶ID字符串",
      "displayName": "用戶顯示名稱",
      "role": "leader" | "follower",
      "joinedAt": "Firebase 時間戳",
      "location": {
        "latitude": 37.7749,
        "longitude": -122.4194
      },
      "lastLocationUpdate": "Firebase 時間戳"
    }
  ]
}
```

**關鍵字段：**
- `id`: 唯一群組識別符 (UUID)
- `name`: 人類可讀的群組名稱
- `leaderId`: 群組領導者的用戶 ID
- `inviteCode`: 6位字符加入碼（24小時後過期）
- `members`: 包含角色和位置的群組成員數組
- `isActive`: 群組狀態的布爾標誌

## 數據流模式

### 1. 驗證流程

```
用戶 → AuthenticationService → Firebase Auth → HitherUser
```

**流程：**
1. 用戶使用 Google/Apple ID/電子郵件登錄
2. AuthenticationService 處理 Firebase Auth
3. 創建/更新 HitherUser 對象
4. 在 AuthenticationService 中存儲當前用戶

**數據模型：**
```swift
struct HitherUser {
    let id: String
    let email: String
    let displayName: String
    let photoURL: String?
}
```

### 2. 群組創建流程

```
用戶輸入 → GroupService → Firebase Firestore → 實時監聽器
```

**流程：**
1. 用戶在 GroupSetupView 中輸入群組名稱
2. 調用 GroupService.createGroup() 並帶有領導者資訊
3. 創建 HitherGroup 對象，領導者為第一個成員
4. 寫入 Firebase `/groups/{groupId}` 集合
5. 啟動群組更新的實時監聽器
6. 更新本地 currentGroup 狀態

### 3. 群組加入流程

```
邀請碼 → GroupService → Firebase 查詢 → 成員添加 → 實時同步
```

**流程：**
1. 用戶輸入邀請碼或掃描 QR 碼
2. GroupService.joinGroup() 查詢 Firebase 匹配邀請碼
3. 驗證邀請碼過期時間和用戶資格
4. 將新成員添加到現有成員數組
5. 使用新成員更新 Firebase 文檔
6. 實時監聽器將更改同步到所有群組成員

### 4. 實時同步

```
Firebase 更改 → Firestore 監聽器 → GroupService → SwiftUI 狀態更新
```

**實現：**
- 使用 Firestore `addSnapshotListener` 進行實時更新
- GroupService 維護當前群組的活動監聽器
- 自動解析和驗證傳入數據
- SwiftUI 視圖對 `@Published` 屬性更改做出反應

**關鍵方法：**
- `startListeningToGroup(groupId:)` - 啟動實時監聽器
- `parseGroupFromData(_:)` - 解析 Firebase 數據為 HitherGroup
- `validateAndRepairGroupData(_:)` - 驗證和修復損壞的數據

### 5. 位置更新

```
CoreLocation → 位置服務 → Firebase 更新 → 實時同步
```

**流程：**
1. CoreLocation 提供 GPS 坐標
2. 位置更新發送到 Firebase 的 member.location 字段
3. 在 member.lastLocationUpdate 中更新時間戳
4. 其他群組成員通過監聽器接收位置更新

### 6. 推送通知

```
FCM 令牌 → Firebase Functions → 推送通知 → 用戶設備
```

**整合：**
- Firebase Cloud Messaging (FCM) 處理推送通知
- 用於群組命令、航點更新和成員警報
- 不同操作類型的通知類別

## 錯誤處理與數據驗證

### 數據驗證流水線

1. **輸入驗證**：UI 層級的用戶輸入驗證
2. **Firebase 驗證**：伺服器端驗證規則
3. **客戶端修復**：`validateAndRepairGroupData()` 修復損壞數據
4. **錯誤恢復**：重複成員的自動清理

### 常見錯誤場景

1. **缺少成員字段**：創建空數組，記錄警告
2. **無效成員格式**：將單個成員轉換為數組
3. **重複成員**：基於 userId 的自動去重
4. **過期邀請碼**：加入前驗證時間戳
5. **網絡故障**：指數退避的重試邏輯

## 狀態管理

### GroupService (@MainActor)

**發布屬性：**
- `currentGroup: HitherGroup?` - 當前活動群組
- `allUserGroups: [HitherGroup]` - 用戶所屬的所有群組
- `isLoading: Bool` - UI 的加載狀態
- `errorMessage: String?` - 用戶顯示的錯誤消息

**關鍵方法：**
- `createGroup()` - 創建新群組
- `joinGroup()` - 加入現有群組
- `leaveGroup()` - 離開群組並進行領導者轉移邏輯
- `loadUserGroups()` - 加載用戶的所有群組
- `cleanupGroupData()` - 修復損壞的群組數據

### AuthenticationService

**發布屬性：**
- `isAuthenticated: Bool` - 用戶驗證狀態
- `currentUser: HitherUser?` - 當前已驗證用戶

## 深層鏈接與 QR 碼

### URL 方案：`hither://join`

**格式：**
```
hither://join?code=ABC123&name=Group%20Name
```

**流程：**
1. 使用深層鏈接 URL 生成 QR 碼
2. 原生相機應用掃描 QR 碼
3. iOS 使用深層鏈接打開 Hither 應用
4. ContentView 處理 URL 並顯示加入確認
5. 用戶確認並加入群組

## 性能優化

### Firestore 優化

1. **複合查詢**：使用多個過濾器的高效查詢
2. **實時監聽器**：最小化監聽器範圍
3. **數據去重**：自動移除重複項
4. **批量操作**：高效的成員更新

### 記憶體管理

1. **監聽器清理**：正確移除 Firestore 監聽器
2. **弱引用**：防止閉包中的保留循環
3. **延遲加載**：按需加載群組
4. **狀態清理**：離開群組時清理數據

## 安全考慮

1. **Firebase 安全規則**：伺服器端存取控制
2. **邀請碼過期**：24小時時間限制
3. **用戶驗證**：操作前驗證用戶成員身份
4. **數據清理**：清理用戶輸入後再寫入 Firebase

## 測試與除錯

### 除錯日誌

- GroupService 中的廣泛日誌記錄用於數據流追蹤
- 錯誤分類（警告與錯誤）
- Firebase 操作的性能指標

### 除錯功能

- 損壞數據的群組清理功能
- 成員驗證和修復
- iOS 16.1+ 的 Live Activity 測試

## 未來增強

1. **離線支援**：本地數據緩存和同步
2. **衝突解決**：處理併發成員更新
3. **數據加密**：敏感數據的端到端加密
4. **分析**：使用跟蹤和性能監控