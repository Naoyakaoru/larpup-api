# LarpUp API

LarpUp 劇本殺揪團平台的 Rails 7 後端 API。

## Tech Stack

- Ruby on Rails 7.2 (API-only)
- PostgreSQL
- JWT Authentication
- Active Storage + Cloudflare R2

## 快速開始

```bash
bundle install
bin/rails db:setup
bin/rails s
```

API 跑在 `http://localhost:3000`，所有 endpoint 前綴為 `/api/v1`。

## 主要功能

| 模組 | 說明 |
|------|------|
| Auth | 註冊 / 登入 / 登出（JWT Bearer token）|
| Users | 個人資料、頭像上傳、我的活動 |
| Scripts | 劇本管理（admin-only 建立/編輯）|
| Events | 活動揪團、報名、成員審核 |

## API 文件

完整 endpoint 說明見 [SPEC.md](./SPEC.md)。

## 環境設定

```bash
# 設定 Cloudflare R2 credentials
bin/rails credentials:edit

# 格式：
# cloudflare:
#   r2_access_key_id: xxx
#   r2_secret_access_key: xxx
#   r2_endpoint: https://<account_id>.r2.cloudflarestorage.com
#   r2_bucket: larpup-production
```

## 部署

部署至 Fly.io，詳見 [SPEC.md](./SPEC.md) 部署架構章節。
