# LarpUp 開發 Spec

## 產品概述

LarpUp 是一個劇本殺揪團平台，讓玩家可以瀏覽劇本、建立活動、揪友組局。

---

## Repo 架構

| Repo | 技術 | 狀態 |
|------|------|------|
| `larpup-api` | Rails 7 API-only, PostgreSQL, JWT | 基礎完成 |
| `larpup-web` | React + Vite + TypeScript | 空白 |
| `larpup-app` | Expo + React Native + TypeScript | 空白 |

API base URL（開發）：`http://localhost:3000/api/v1`

---

## 資料模型

### User
| 欄位 | 類型 | 說明 |
|------|------|------|
| id | bigint | PK |
| email | string | 唯一、不區分大小寫 |
| password_digest | string | bcrypt |
| nickname | string | 顯示名稱 |

### Script（劇本）
| 欄位 | 類型 | 說明 |
|------|------|------|
| id | bigint | PK |
| title | string | 劇本名稱 |
| description | text | 簡介 |
| difficulty | integer | 0=easy, 1=medium, 2=hard |
| genres | integer[] | 多選，值見下方 |
| male_slots | integer | 男角人數 |
| female_slots | integer | 女角人數 |
| any_slots | integer | 不限性別人數 |

**Genres（類型）**
```
0=推理, 1=還原, 2=恐怖, 3=情感, 4=歡樂, 5=機制, 6=陣營, 7=古風, 8=現代
```

### Event（活動）
| 欄位 | 類型 | 說明 |
|------|------|------|
| id | bigint | PK |
| script_id | bigint | FK |
| host_id | bigint | FK → users |
| scheduled_at | datetime | 活動時間 |
| location | string | 地點 |
| status | integer | 0=recruiting, 1=full, 2=completed, 3=cancelled |

狀態轉換：
- `recruiting` → `full`（confirmed 人數達到 total_slots 時自動更新）
- `recruiting`/`full` → `cancelled`（host 刪除活動）
- `full` → `recruiting`（有人離開後 slots 釋出）

### EventMember（報名紀錄）
| 欄位 | 類型 | 說明 |
|------|------|------|
| id | bigint | PK |
| event_id | bigint | FK |
| user_id | bigint | FK |
| status | integer | 0=pending, 1=confirmed, 2=rejected, 3=cancelled, 4=leave_requested |

狀態轉換：
```
pending → confirmed（host 審核通過）
pending → rejected（host 拒絕）
pending → cancelled（玩家自行取消）
confirmed → leave_requested（玩家申請退出）
leave_requested → cancelled（host 同意退出）
```

---

## API Endpoints

### Auth（無需 token）
```
POST /auth/register    body: { email, password, password_confirmation, nickname }
                       resp: { token, user: { id, email, nickname } }

POST /auth/login       body: { email, password }
                       resp: { token, user: { id, email, nickname } }

DELETE /auth/logout    需要 token
                       resp: { message }
```

### Users（需要 token）
```
GET    /users/me           resp: { id, email, nickname }
PATCH  /users/me           body: { email?, nickname?, password?, password_confirmation? }
GET    /users/me/events    resp: [ ...events ]（包含 hosted + joined）
```

### Scripts（index/show 無需 token，create/update 需要）
```
GET    /scripts            resp: [ { id, title, difficulty, genres, male_slots, female_slots, any_slots, total_slots } ]
GET    /scripts/:id        resp: 同上 + description
POST   /scripts            body: { title, description, difficulty, genres, male_slots, female_slots, any_slots }
PATCH  /scripts/:id        body: 同 create（部分欄位）
```

### Events（index/show 無需 token，其餘需要）
```
GET    /events             query: ?status=&script_id=&date=YYYY-MM-DD
                           resp: [ { id, script, host, scheduled_at, location, status, confirmed_count, available_slots } ]

GET    /events/:id         resp: 同上 + members: [ { id, user: { id, nickname }, status } ]

POST   /events             body: { script_id, scheduled_at, location }
                           resp: event object

PATCH  /events/:id         body: { scheduled_at?, location?, status? }（僅 host）

DELETE /events/:id         → 將 status 設為 cancelled（僅 host）

POST   /events/:id/join    → 建立 pending EventMember
                           resp: { message }

DELETE /events/:id/leave   → pending → cancelled；confirmed → leave_requested
                           resp: { message }
```

### Event Members（需要 token，僅 host 可操作）
```
GET    /events/:event_id/members        resp: [ { id, user, status } ]

PATCH  /events/:event_id/members/:id   body: { status }
                                        → host 審核：pending→confirmed/rejected，leave_requested→cancelled
```

### 認證方式
所有需要 token 的 endpoint，請在 header 帶：
```
Authorization: Bearer <token>
```

---

## 前端功能規劃

### Web（larpup-web）— 主要面向桌機/平板

#### Pages

| 路徑 | 功能 | 需要登入 |
|------|------|---------|
| `/` | 首頁：最新活動列表 + 搜尋篩選 | 否 |
| `/scripts` | 劇本列表（篩選 genre/難度） | 否 |
| `/scripts/:id` | 劇本詳情 | 否 |
| `/events` | 活動列表（篩選 status/日期/劇本） | 否 |
| `/events/:id` | 活動詳情 + 報名 | 否（報名需登入）|
| `/events/new` | 建立活動 | 是 |
| `/events/:id/edit` | 編輯活動 | 是（僅 host）|
| `/me` | 我的頁面：個人資料 + 我的活動 | 是 |
| `/me/hosting` | 我主辦的活動 + 成員審核 | 是 |
| `/login` | 登入 | 否 |
| `/register` | 註冊 | 否 |

#### 功能優先級

**P0（MVP）**
- 劇本列表 + 詳情
- 活動列表 + 詳情
- 登入 / 註冊
- 建立活動
- 報名活動（join/leave）

**P1**
- 我的活動頁面
- 成員審核（host 確認/拒絕報名）
- 篩選搜尋（genre/難度/日期/狀態）

**P2**
- 劇本建立/編輯（admin UI，`/admin/scripts`）
- 個人資料編輯

---

### App（larpup-app）— 主要面向手機

#### Screens

| Screen | 功能 |
|--------|------|
| `HomeScreen` | 活動列表（分頁：全部/揪中/我辦）|
| `EventDetailScreen` | 活動詳情 + 報名/退出 |
| `CreateEventScreen` | 建立活動（選劇本、時間、地點）|
| `ScriptListScreen` | 劇本瀏覽 |
| `ScriptDetailScreen` | 劇本詳情 |
| `MembersScreen` | 活動成員審核（host 用）|
| `ProfileScreen` | 個人資料 |
| `LoginScreen` | 登入 |
| `RegisterScreen` | 註冊 |

#### Navigation 架構
```
RootNavigator
├── AuthStack（未登入）
│   ├── LoginScreen
│   └── RegisterScreen
└── MainTabs（已登入）
    ├── HomeTab → HomeScreen → EventDetailScreen
    ├── ScriptsTab → ScriptListScreen → ScriptDetailScreen
    └── ProfileTab → ProfileScreen
```

---

## 共用規格

### API 呼叫規範

**Request**
- Content-Type: `application/json`
- 需要認證時帶 `Authorization: Bearer <token>`

**Response 錯誤格式**
```json
{ "error": "message" }         // 單一錯誤
{ "errors": ["msg1", "msg2"] } // 多個驗證錯誤
```

**HTTP 狀態碼**
| 情境 | 狀態碼 |
|------|--------|
| 建立成功 | 201 |
| 成功 | 200 |
| 未授權 | 401 |
| 禁止（非 host）| 403 |
| 找不到資源 | 404 |
| 驗證失敗 | 422 |

### Token 管理
- Web：存在 `localStorage`，key = `larpup_token`
- App：存在 SecureStore（Expo），key = `larpup_token`
- 登出時清除 token

### 日期格式
- API 傳輸：ISO 8601（`2026-05-10T14:00:00.000Z`）
- 顯示：`YYYY/MM/DD HH:mm`（台灣在地化）

---

## 開發順序建議

### Phase 1：Web MVP
1. 建立 API client + auth context（useAuth hook）
2. 登入 / 註冊頁面
3. 活動列表 + 詳情
4. 報名功能
5. 建立活動

### Phase 2：Web 完整功能
6. 劇本列表 + 詳情
7. 我的活動 / 成員審核
8. 篩選搜尋

### Phase 3：App
9. Navigation 架構 + Auth screens
10. 活動列表 + 詳情（照抄 Web 邏輯）
11. 報名 / 建立活動
12. 成員審核

---

## 部署架構

| 服務 | 平台 | 理由 |
|------|------|------|
| API (Rails) | Fly.io | Rails 支援佳、免費額度不 sleep、自動 Docker 打包 |
| Web (React) | Vercel | Vite/React 最佳、免費、auto preview deploy |
| App (Expo) | Expo EAS | 官方 build service，上 App Store / Play Store |
| 圖片儲存 | Cloudflare R2 | 無 egress 費、10GB 免費、S3-compatible |
| Database | Fly.io Postgres | 隨 API 一起管，免費 3GB |

MVP 階段預計費用：**$0**

---

## 架構決策紀錄

| 問題 | 決策 | 理由 |
|------|------|------|
| Script 由誰建立？ | Admin-only（`is_admin` flag on User） | 資料量有限、品質需一致、避免審核流程複雜度 |
| Location 欄位設計？ | 永遠是 free text string | 店家局填店名地址，自辦局填場地；不需綁 Store FK |
| 有沒有 Store 模型？ | 暫無，Phase 2+ 再加 StoreScript | 目前沒有店家要加入 |

### 未來 StoreScript 擴充方向（Phase 2+）

**Schema**
```
stores
  id, name, owner_id

store_branches
  id, store_id, name, city, address, phone

store_scripts
  id, store_id, script_id
  price, duration_minutes, description, is_available

store_branch_scripts              ← 純 junction，無 override
  store_branch_id, store_script_id
```

**設計原則**
- `StoreScript` 掛在品牌（Store），代表「這個定價的上架」
- 同劇本不同分店但價格相同 → 一筆 StoreScript，junction 連多個分店
- 同劇本不同分店且價格不同 → 各建一筆 StoreScript，各自連對應分店
- `Event` 加兩個 optional FK：`store_script_id` + `store_branch_id`
- `location` 維持 free text，店家局由前端 auto-fill 自 `branch.address`

---

## 待確認事項

- [x] 是否有圖片上傳需求 → 劇本封面 + 個人頭像，其餘不需要
- [x] 活動 `status` 是否需要手動設為 `completed` → 先不做
- [x] 需要通知機制嗎 → Email + Push，MVP 先不做，保留擴充空間

---

## 圖片上傳規格

**對象**
| Model | 欄位 | 說明 |
|-------|------|------|
| Script | `cover_image` | 劇本封面，1 張 |
| User | `avatar` | 個人頭像，1 張 |

**實作方式**
- Rails Active Storage + Cloudflare R2（S3-compatible）
- Gem：`aws-sdk-s3`（R2 相容）
- 開發環境用 local disk，production 用 R2

**R2 選擇理由**：無 egress 費、10GB 免費、API 相容 S3

---

## 通知規格（Phase 2+）

| 事件 | Email | Push |
|------|-------|------|
| 報名送出 | 玩家收到確認 | ✓ |
| 報名審核結果（通過/拒絕） | ✓ | ✓ |
| 活動時間/地點異動 | ✓ | ✓ |
| 活動取消 | ✓ | ✓ |

**實作方向**
- Email：Action Mailer + SendGrid / Resend
- Push：Expo Push Notifications（App）/ Web Push API（Web）
