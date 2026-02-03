# Swift MUD 遊戲設計文件

## 概述

使用 Swift 實作跨平台 MUD（多人線上文字冒險遊戲）伺服器，包含即時戰鬥、技能樹、任務系統、商店交易與多層級管理系統。

## 技術棧

- **語言**：Swift 5.9+
- **網路層**：SwiftNIO（非同步 TCP 伺服器）
- **資料庫**：抽象化 Repository 層，支援 PostgreSQL / MySQL
- **平台**：macOS、Linux 跨平台

---

## 系統架構

```
┌─────────────────────────────────────────────────────┐
│                    MUD Server                        │
├──────────┬──────────┬──────────┬──────────┬─────────┤
│ Network  │  Game    │  Combat  │  Data    │  Admin  │
│  Layer   │  World   │  Engine  │  Layer   │  System │
├──────────┼──────────┼──────────┼──────────┼─────────┤
│ SwiftNIO │ Room     │ Realtime │ Repository│ 4-Tier │
│ Handler  │ Player   │ Skill    │ Pattern  │ Permission
│ Protocol │ Monster  │ Cooldown │ PostgreSQL│ Commands│
│ Session  │ Item     │ Combat   │ MySQL    │ Logging │
└──────────┴──────────┴──────────┴──────────┴─────────┘
```

### 連線流程

1. 玩家 TCP 連線 → SwiftNIO 建立 Channel
2. 登入/註冊 → 驗證後載入玩家資料
3. 進入遊戲世界 → 指令迴圈
4. 斷線 → 儲存資料、清理狀態

---

## 資料模型

### Player（玩家）

```swift
struct Player {
    let id: UUID
    var name: String
    var passwordHash: String

    // 等級與經驗
    var level: Int
    var exp: Int
    var gold: Int

    // 屬性
    var currentHP: Int
    var maxHP: Int
    var currentMP: Int
    var maxMP: Int
    var baseAttack: Int
    var baseDefense: Int
    var baseMagic: Int

    // 位置與物品
    var currentRoomId: String
    var inventory: [ItemInstance]
    var equipment: [EquipmentSlot: ItemInstance]

    // 技能
    var skills: [SkillId: Int]  // 技能ID -> 等級

    // 管理權限
    var adminLevel: AdminTier
}
```

### Skill（技能）

```swift
struct Skill {
    let id: String
    let name: String
    let description: String
    let type: SkillType  // .active / .passive

    // 前置技能需求
    let prerequisites: [String: Int]  // 技能ID -> 需求等級

    // 主動技能屬性
    let mpCost: Int
    let castTime: TimeInterval
    let cooldown: TimeInterval
    let effects: [Effect]

    // 被動技能屬性
    let statBonus: [Stat: Int]
}

enum SkillType {
    case active
    case passive
}
```

### Quest（任務）

```swift
struct Quest {
    let id: String
    let name: String
    let description: String
    let type: QuestType

    let prerequisites: [String]  // 前置任務ID
    let objectives: [Objective]
    let rewards: QuestRewards
    let repeatCooldown: TimeInterval?
}

enum QuestType {
    case single      // 單次任務
    case repeatable  // 可重複任務
    case chain       // 任務鏈
}

enum Objective {
    case kill(monsterId: String, count: Int)
    case collect(itemId: String, count: Int)
    case visit(roomId: String)
    case talk(npcId: String)
    case reachLevel(level: Int)
    case learnSkill(skillId: String)
}
```

### Shop（商店）

```swift
struct Shop {
    let id: String
    let name: String
    let roomId: String
    var inventory: [ShopItem]
    let buyRate: Float  // 收購價格比例
}

struct ShopItem {
    let itemId: String
    let price: Int
    var stock: Int?  // nil = 無限庫存
}
```

---

## 即時戰鬥系統

### 戰鬥流程

```
玩家輸入 attack <目標>
        ↓
    進入戰鬥狀態
        ↓
┌─────────────────────────────┐
│     戰鬥循環 (每 2 秒)       │
│  ┌─────────────────────┐    │
│  │ 1. 檢查施法中的技能  │    │
│  │ 2. 處理冷卻中的技能  │    │
│  │ 3. 執行自動攻擊      │    │
│  │ 4. 套用被動技能加成  │    │
│  │ 5. 計算傷害與效果    │    │
│  │ 6. 更新狀態與通知    │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
        ↓
  目標死亡 或 玩家逃跑/死亡
        ↓
    結算經驗、掉落
```

### 技能施放

```
cast <技能名>
  → 檢查：MP 足夠？冷卻完成？正在施法中？
  → 開始施法（顯示施法進度）
  → castTime 後：扣 MP、造成效果、進入冷卻
```

### 主動技能範例

| 技能 | 施法時間 | 冷卻 | 效果 |
|------|---------|------|------|
| 火球術 | 1.5秒 | 8秒 | 魔法傷害 150% |
| 治療術 | 2秒 | 15秒 | 恢復 30% HP |
| 疾風斬 | 0秒 | 5秒 | 物理傷害 120% |
| 嘲諷 | 0秒 | 20秒 | 強制目標攻擊自己 |

### 被動技能範例

| 技能 | 效果 |
|------|------|
| 強壯體魄 I-III | maxHP +10/20/30% |
| 銳利 I-III | 攻擊力 +5/10/15% |
| 魔力湧泉 I-III | MP 回復 +1/2/3 每秒 |

---

## 任務系統

### 任務類型

| 類型 | 說明 | 範例 |
|------|------|------|
| 單次 | 完成一次，永久完成 | 主線劇情、新手引導 |
| 可重複 | 有冷卻時間，可再次接取 | 每日討伐、賞金任務 |
| 任務鏈 | 需完成前置才能接續 | 史詩故事線 |

### 任務指令

```
quest list          - 查看可接任務
quest active        - 查看進行中任務
quest info <任務>   - 查看任務詳情與進度
quest accept <任務> - 接受任務
quest abandon <任務> - 放棄任務
quest complete      - 向 NPC 回報完成
```

### 任務鏈範例：森林危機

```
[1] 初探森林 (單次)
    → 目標：前往森林入口
    → 獎勵：100 金幣
        ↓
[2] 狼患 (單次)
    → 目標：擊殺 5 隻野狼
    → 獎勵：200 金幣、狼皮披風
        ↓
[3] 蜘蛛巢穴 (單次)
    → 目標：擊殺森林蜘蛛 x3、收集蜘蛛絲 x5
    → 獎勵：500 金幣、學習技能「毒抗」
```

---

## 商店與交易系統

### 固定商店

| 商店 | 位置 | 販售內容 |
|------|------|----------|
| 武器店 | 市集 | 劍、斧、弓、法杖 |
| 藥水店 | 市集 | 紅藥水、藍藥水、解毒劑 |
| 雜貨店 | 市集 | 火把、繩索、背包擴充 |
| 神殿商人 | 神殿 | 祝福卷軸、復活石 |

### 商店指令

```
shop                - 查看當前房間商店
shop list           - 列出商品與價格
buy <物品> [數量]   - 購買物品
sell <物品> [數量]  - 出售物品（商店以 50% 價格收購）
```

### 玩家交易指令

```
trade <玩家名>      - 發起交易請求
trade accept        - 接受交易請求
trade add <物品>    - 放入物品
trade gold <數量>   - 放入金幣
trade confirm       - 確認交易內容
trade cancel        - 取消交易
```

### 交易流程

```
A: trade B     →  B 收到交易請求
B: trade accept
A: trade add 鐵劍
B: trade gold 500
A: trade confirm   →  顯示「A 已確認」
B: trade confirm   →  雙方都確認，交易完成
```

### 擺攤系統

```
stall open              - 在當前位置擺攤
stall add <物品> <價格> - 上架商品
stall remove <物品>     - 下架商品
stall close             - 收攤
```

---

## 管理者（巫司）系統

### 四層權限架構

| 層級 | 名稱 | 權限範圍 |
|------|------|----------|
| 1 | 見習GM | 監控、禁言、查看玩家資訊 |
| 2 | GM | + 踢人、傳送、發送警告 |
| 3 | 超級GM | + 世界編輯、修改玩家數據、生成物品 |
| 4 | 創世神 | + 系統設定、管理其他GM、關閉伺服器 |

### 見習GM 指令

```
@who                    - 查看所有在線玩家詳細資訊
@info <玩家>            - 查看玩家完整資料
@mute <玩家> <分鐘>     - 禁言
@unmute <玩家>          - 解除禁言
@watch <玩家>           - 監控玩家行動（記錄到日誌）
```

### GM 指令

```
@kick <玩家> [原因]     - 踢出玩家
@teleport <玩家> <房間> - 傳送玩家
@goto <房間>            - 自己傳送
@summon <玩家>          - 召喚玩家到身邊
@warn <玩家> <訊息>     - 發送警告（記錄到玩家檔案）
@announce <訊息>        - 全服公告
```

### 超級GM 指令

```
@spawn <怪物> [數量]    - 生成怪物
@give <玩家> <物品> [數量] - 給予物品
@setgold <玩家> <數量>  - 設定金幣
@setlevel <玩家> <等級> - 設定等級
@heal <玩家>            - 完全治療
@room create <名稱>     - 創建房間
@room edit <屬性> <值>  - 編輯當前房間
@room link <方向> <房間> - 連接房間
```

### 創世神 指令

```
@promote <玩家> <層級>  - 提升管理權限
@demote <玩家>          - 降低管理權限
@ban <玩家> [天數]      - 封禁帳號
@unban <玩家>           - 解除封禁
@config <設定> <值>     - 修改系統設定
@shutdown [秒數]        - 關閉伺服器
@reload                 - 重載設定檔
```

### 管理日誌

所有 GM 操作自動記錄：

```
[2024-01-15 14:32:05] [GM] Alice @kick Bob 原因：惡意洗頻
[2024-01-15 14:35:22] [超級GM] Admin @give Alice iron_sword x1
```

---

## 專案結構

```
SwiftMUD/
├── Package.swift
├── Sources/
│   └── SwiftMUD/
│       ├── main.swift
│       ├── Server/
│       │   ├── MUDServer.swift        # SwiftNIO 伺服器
│       │   ├── ClientHandler.swift    # 連線處理
│       │   └── SessionManager.swift   # 會話管理
│       ├── Game/
│       │   ├── World.swift            # 世界狀態
│       │   ├── Room.swift
│       │   ├── Player.swift
│       │   ├── Monster.swift
│       │   ├── Item.swift
│       │   └── NPC.swift
│       ├── Combat/
│       │   ├── CombatEngine.swift     # 即時戰鬥引擎
│       │   ├── SkillSystem.swift      # 技能系統
│       │   └── DamageCalculator.swift
│       ├── Systems/
│       │   ├── QuestSystem.swift      # 任務系統
│       │   ├── ShopSystem.swift       # 商店系統
│       │   ├── TradeSystem.swift      # 交易系統
│       │   └── AdminSystem.swift      # 管理系統
│       ├── Commands/
│       │   ├── CommandParser.swift    # 指令解析
│       │   ├── PlayerCommands.swift
│       │   ├── CombatCommands.swift
│       │   └── AdminCommands.swift
│       ├── Data/
│       │   ├── Repository.swift       # 抽象資料層
│       │   ├── PostgresRepo.swift
│       │   ├── MySQLRepo.swift
│       │   └── Migrations/
│       └── Config/
│           └── GameConfig.swift
├── Tests/
│   └── SwiftMUDTests/
└── Resources/
    ├── rooms.json                     # 預設房間資料
    ├── monsters.json
    ├── items.json
    ├── skills.json
    └── quests.json
```

---

## 依賴套件

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.0.0"),
    .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
]
```

---

## 錯誤處理

```swift
enum MUDError: Error {
    // 連線相關
    case connectionFailed(reason: String)
    case sessionExpired

    // 遊戲邏輯
    case playerNotFound(name: String)
    case roomNotFound(id: String)
    case invalidCommand(command: String)
    case insufficientGold(required: Int, has: Int)
    case inventoryFull

    // 戰鬥相關
    case notInCombat
    case skillOnCooldown(remaining: TimeInterval)
    case insufficientMP(required: Int, has: Int)
    case invalidTarget

    // 權限相關
    case permissionDenied(required: AdminTier)
    case targetHigherRank
}
```

---

## 測試策略

| 層級 | 測試內容 | 工具 |
|------|----------|------|
| 單元測試 | 傷害計算、技能效果、任務邏輯 | XCTest |
| 整合測試 | 資料庫操作、指令解析 | XCTest + TestContainer |
| 端對端測試 | 完整遊戲流程 | 模擬 TCP 客戶端 |

### 關鍵測試案例

- **戰鬥**：技能傷害計算、冷卻時間、被動加成疊加
- **任務**：前置條件檢查、進度追蹤、獎勵發放
- **交易**：雙方確認、物品轉移原子性、金幣不足處理
- **權限**：各層級指令存取控制、禁止越權操作

---

## 日誌等級

```
DEBUG - 開發除錯用
INFO  - 一般操作記錄
WARN  - 異常但可處理
ERROR - 錯誤需關注
FATAL - 嚴重錯誤，需停機
```

---

## 遊戲地圖

```
                         ┌─────────────┐
                         │ 森林小徑    │
                         │ 狼、蜘蛛    │
                         └──────┬──────┘
                                │
┌─────────┐    ┌─────────┐     │      ┌─────────────┐
│ 蜘蛛巢穴│←───│         │←────┘      │   神殿      │
│ 蜘蛛×2  │    │         │            │  (祈禱回血) │
└─────────┘    │ 森林入口│            └──────┬──────┘
               │   狼    │                   │
               └────┬────┘            ┌──────┴──────┐
                    │                 │  城鎮廣場   │
┌─────────────┐     │                 │  (安全區)   │────→ 客棧 (休息)
│  山賊營地   │     │                 └──────┬──────┘
│ 山賊、哥布林│     │                        │
└──────┬──────┘     │                 ┌──────┴──────┐
       │            │                 │    市集     │
       └────────────┴────森林深處←────┤  (安全區)   │
                          哥布林      └─────────────┘
```
