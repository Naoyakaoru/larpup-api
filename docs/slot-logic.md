# Slot Allocation Logic

## 概念

每個劇本有三種槽位：

| 欄位           | 說明                                    |
| -------------- | --------------------------------------- |
| `male_slots`   | 只限男玩家（或女玩家反串）填入          |
| `female_slots` | 只限女玩家（或男玩家反串）填入          |
| `any_slots`    | 任何性別皆可                            |
| `total_slots`  | `male_slots + female_slots + any_slots` |

---

## confirmed_count（後端）

**`app/models/event.rb`**

```ruby
def confirmed_count
  event_members.confirmed.count + offline_male + offline_female
end
```

已確認人數 = 線上確認成員 + 線下男 + 線下女。  
`available_slots = total_slots - confirmed_count`

---

## sync_status（後端）

**`app/models/event.rb`**

```ruby
def sync_status
  return if cancelled? || completed?
  if confirmed_count >= total_slots
    update_column(:status, Event.statuses[:full])
  elsif full?
    update_column(:status, Event.statuses[:recruiting])
  end
end
```

雙向同步：達到上限 → `full`；有人離開後低於上限 → `recruiting`。  
在以下時機呼叫：

- host 透過 `EventMembersController#update` 確認一名成員後

---

## slot_available_for?（後端 join 驗證）

**`app/controllers/api/v1/events_controller.rb`**

玩家申請加入時，先計算各性別剩餘槽位，再判斷有無空位：

```
male_filled  = offline_male
female_filled = offline_female
any_filled   = 0

for each confirmed member:
  effective_gender = cross_gender ? opposite : own_gender
  if effective_gender == male and male_filled < male_slots → male_filled++
  elif effective_gender == female and female_filled < female_slots → female_filled++
  else → any_filled++

remaining_male = max(0, male_slots - male_filled)
remaining_female = max(0, female_slots - female_filled)
remaining_any = max(0, any_slots - any_filled)

male applicant can join if remaining_male > 0 or remaining_any > 0
female applicant can join if remaining_female > 0 or remaining_any > 0
```

**cross_gender 申請**：`params[:cross_gender].present? && event.allow_cross_gender`，
effective_gender 取反，再以此判斷槽位。

---

## offline 人數上限（後端驗證）

目前後端不驗證 `offline_male ≤ male_slots`，由前端 UI 控管（見下方）。

---

## 前端 slot 計算（`src/utils/slotCalc.ts`）

### `calcNeeded(script, params) → SlotAllocation`

用於**建立活動**表單，計算扣除主揪和線下朋友後的剩餘槽位。

**Overflow 規則（無論是否開放反串）：**

1. 先填自己性別的槽位
2. 自己性別用完 → 填 `any_slots`
3. `any_slots` 也用完 → 填對方性別槽位

```ts
calcNeeded(script, {
  host_in_game,
  host_cross_gender,
  offline_male,
  offline_female,
  hostGender,
});
```

主揪反串時，effective_gender 取反，再用 deductSlot 扣除。

---

### `calcRemainingAfterOnline(script, confirmedMembers) → SlotAllocation`

用於**編輯活動**表單，計算扣除線上已確認成員後的剩餘槽位。

```ts
calcRemainingAfterOnline(event.script, confirmedMembers);
```

`confirmedMembers` 為 `event.members` 中 `status === 'confirmed'` 的成員，  
各成員依自身 `cross_gender` flag 決定填入哪個性別槽。

---

### `canAddOffline(remaining, offlineMale, offlineFemale, addingGender, allowCrossGender) → boolean`

用於**建立 / 編輯**表單的線下人數 `+` 按鈕，防止超出可用槽位。

**流程：**

1. 以 `remaining`（扣掉線上成員後的槽位）為基礎
2. 模擬放入現有 `offlineMale` + `offlineFemale`
3. 再嘗試多放一個 `addingGender`
4. 任一步驟無位可填 → 回傳 `false`，`+` 按鈕無效

**`allowCrossGender = false`（不開放反串）：**

- offline 男只能填 `male_slots → any_slots`，不能填 `female_slots`
- offline 女只能填 `female_slots → any_slots`，不能填 `male_slots`

**`allowCrossGender = true`（開放反串）：**

- 三種槽位都可填，順序：own gender → any → opposite

---

## 建立表單 `+` 按鈕邏輯（`CreateEventPage`）

```ts
remainingAfterHost = calcNeeded(script, {
  host_in_game,
  host_cross_gender,
  offline_male: 0,
  offline_female: 0,
  hostGender: user.gender,
});
canAddOffline(
  remainingAfterHost,
  form.offline_male,
  form.offline_female,
  addingGender,
  form.allow_cross_gender,
);
```

---

## 編輯表單 `+` 按鈕邏輯（`EventDetailPage`）

```ts
remainingAfterOnline = calcRemainingAfterOnline(event.script, confirmedMembers);
canAddOffline(
  remainingAfterOnline,
  editForm.offline_male,
  editForm.offline_female,
  addingGender,
  event.allow_cross_gender,
);
```

`confirmedMembers` 包含主揪（若主揪在局），所以不需要另外扣。

---

## 「實際還需要」顯示（`CreateEventPage`）

呼叫 `calcNeeded`（含 offline）後，透過 `formatNeeded` 格式化為「2男 1女」，  
若全部為 0 顯示「已滿」。
