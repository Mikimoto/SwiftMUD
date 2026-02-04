# SwiftMUD 架構文件

## 系統架構概述

SwiftMUD 採用模組化的分層架構設計，將系統劃分為多個獨立的模組，每個模組負責特定的職責。這種設計使得系統易於維護、測試和擴展。

### 架構圖

```
┌─────────────────────────────────────────────────────────────────┐
│                         客戶端連線                               │
│                    (Telnet / MUDClient)                         │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Server 模組                                │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │  MUDServer  │──│ClientHandler │──│   SessionManager        │ │
│  │  (TCP 伺服器) │  │ (連線處理)    │  │   (Session 管理)        │ │
│  └─────────────┘  └──────────────┘  └───────────┬─────────────┘ │
└───────────────────────────────────────────────────┬─────────────┘
                                                    │
                                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Commands 模組                               │
│  ┌───────────────┐  ┌──────────────────────────────────────────┐│
│  │ CommandParser │──│ Commands (Move, Look, Attack, Quest...) ││
│  │ (指令解析器)    │  │ (各類指令實作)                            ││
│  └───────────────┘  └──────────────────────────────────────────┘│
└───────────────────────────────────────────────────┬─────────────┘
                                                    │
                    ┌───────────────────────────────┼───────────────────────────┐
                    │                               │                           │
                    ▼                               ▼                           ▼
┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
│      Combat 模組         │  │       Quest 模組        │  │       Shop 模組         │
│  ┌────────────────────┐ │  │  ┌────────────────────┐ │  │  ┌────────────────────┐ │
│  │   CombatManager    │ │  │  │   QuestManager     │ │  │  │   ShopManager      │ │
│  │   CombatState      │ │  │  │   Quest            │ │  │  │   Shop             │ │
│  └────────────────────┘ │  │  │   QuestProgress    │ │  │  │   NPC              │ │
└────────────┬────────────┘  └────────────┬──────────┘  └────────────┬────────────┘
             │                            │                          │
             └────────────────────────────┼──────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        World 模組                                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                       World                                 │ │
│  │  (遊戲世界中央狀態容器：玩家、房間、怪物、物品、技能)           │ │
│  └────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────┬─────────────┘
                                                    │
                    ┌───────────────────────────────┴───────────────┐
                    │                                               │
                    ▼                                               ▼
┌─────────────────────────────────┐          ┌─────────────────────────────────┐
│          Game 模組               │          │       Persistence 模組          │
│  ┌─────────┐  ┌─────────┐       │          │  ┌────────────────────────────┐ │
│  │ Player  │  │  Room   │       │          │  │    JSONPlayerRepository    │ │
│  │ Monster │  │  Item   │       │          │  │    JSONFileStorage         │ │
│  │  Skill  │  │ Types   │       │          │  └────────────────────────────┘ │
│  └─────────┘  └─────────┘       │          └─────────────────────────────────┘
└─────────────────────────────────┘
```

### 資料流概述

1. **連線請求**：客戶端透過 TCP 連接到 MUDServer
2. **連線處理**：ClientHandler 處理連線事件，建立 Session
3. **指令輸入**：玩家輸入的文字透過 Session 傳遞給 CommandParser
4. **指令執行**：CommandParser 解析並執行對應的 Command
5. **狀態更新**：Command 透過各個 Manager（Combat、Quest、Shop）更新 World 狀態
6. **持久化**：重要資料變更透過 Persistence 模組儲存到檔案系統
7. **回應輸出**：執行結果透過 Session 傳回客戶端

---

## 各模組說明

### 1. Server 模組

負責網路通訊和連線管理。

#### MUDServer

TCP 伺服器的核心類別，使用 SwiftNIO 實作非同步網路處理。

**主要職責**：
- 監聽指定埠號的 TCP 連線
- 設定 Channel Pipeline（BackPressure、行分隔解碼、字串編碼）
- 管理伺服器生命週期（啟動、停止）

**關鍵元件**：
- `LineBasedFrameDecoder`：將 TCP 串流分割成行
- `StringCodec`：處理字串編碼/解碼和換行符號

```swift
final class MUDServer {
    func start() throws    // 啟動伺服器
    func stop()            // 停止伺服器
    func waitForClose()    // 等待伺服器關閉
}
```

#### ClientHandler

處理個別客戶端連線的 Channel Handler。

**主要職責**：
- 處理連線建立和斷開事件
- 接收玩家輸入並傳遞給 Session
- 發送訊息給客戶端

#### Session

代表一個玩家的連線 Session。

**主要職責**：
- 維護玩家連線狀態
- 儲存玩家 ID 和認證資訊
- 提供訊息發送介面

#### SessionManager

管理所有活動的 Session。

**主要職責**：
- 追蹤所有連線的玩家
- 提供廣播和群發功能
- 處理 Session 生命週期

---

### 2. Game 模組

定義遊戲的基礎資料結構。

#### Types

遊戲中使用的基礎類型定義。

**包含類型**：
- `AdminTier`：管理權限層級（player, trainee, gm, superGM, creator）
- `EquipmentSlot`：裝備欄位（head, body, hands, legs, feet, mainHand, offHand, accessory）
- `SkillType`：技能類型（active, passive）
- `QuestType`：任務類型（single, repeatable, daily, weekly, chain）
- `QuestObjective`：任務目標（kill, collect, visit, talkTo 等）
- `Stat`：屬性類型（maxHP, maxMP, attack, defense 等）
- `Effect`：效果類型（damage, heal, buff, debuff 等）
- `Direction`：方向（north, south, east, west, up, down）

#### Player

玩家資料結構，支援 Codable 以進行持久化。

**主要屬性**：
- 基本資訊：id, name, passwordHash
- 等級經驗：level, exp, gold
- 戰鬥屬性：currentHP, maxHP, currentMP, maxMP, baseAttack, baseDefense, baseMagic
- 位置：currentRoomId
- 技能：skills
- 背包裝備：inventory, equipment
- 狀態：isMuted, isBanned, isAFK

**主要方法**：
```swift
static func create(name:passwordHash:) -> Player  // 建立新玩家
mutating func heal(_ amount: Int)                  // 治療
mutating func takeDamage(_ amount: Int)            // 受傷
mutating func gainExp(_ amount: Int) -> Bool       // 獲得經驗
mutating func equip(itemId:slot:) -> String?       // 裝備物品
func totalAttack() -> Int                          // 計算總攻擊力
func totalDefense() -> Int                         // 計算總防禦力
```

#### Room

房間資料結構。

**主要屬性**：
- 基本資訊：id, name, description
- 連接：exits（方向到房間ID的映射）
- 屬性：isSafeZone, canPvP, respawnPoint
- 內容物：playerIds, monsterIds, itemIds, npcIds

#### Monster

怪物資料結構，包含實例和模板。

**MonsterTemplate**（怪物模板）：
- 定義怪物類型的基本屬性
- 包含掉落表和重生時間

**Monster**（怪物實例）：
- 世界中實際存在的怪物
- 具有當前 HP 和位置

#### Item

物品系統，包含模板和背包。

**ItemTemplate**（物品模板）：
- 定義物品類型、屬性加成、價格等

**Inventory**（背包）：
- 管理玩家擁有的物品
- 支援堆疊和容量限制

#### Skill

技能系統。

**主要屬性**：
- 基本資訊：id, name, description
- 類型：type（active/passive）
- 消耗：mpCost, castTime, cooldown
- 效果：effects（傷害、治療、增益、減益等）
- 屬性加成：statBonus（被動技能）

---

### 3. World 模組

遊戲世界的中央狀態容器。

#### World

使用單例模式，管理所有遊戲實體。

**管理的實體**：
- `players`：線上玩家（UUID -> Player）
- `rooms`：所有房間（roomId -> Room）
- `monsters`：活動怪物（UUID -> Monster）
- `itemTemplates`：物品模板（templateId -> ItemTemplate）
- `monsterTemplates`：怪物模板（templateId -> MonsterTemplate）
- `skills`：技能定義（skillId -> Skill）

**主要方法**：
```swift
// 玩家操作
func addPlayer(_ player: Player)
func removePlayer(_ playerId: UUID)
func updatePlayer(_ player: Player)
func getPlayer(byId:) -> Player?
func getPlayer(byName:) -> Player?

// 房間操作
func getRoom(_ roomId: String) -> Room?
func movePlayer(_:from:to:)
func getPlayersInRoom(_ roomId: String) -> [Player]
func getMonstersInRoom(_ roomId: String) -> [Monster]

// 怪物操作
func addMonster(_ monster: Monster)
func removeMonster(_ monsterId: UUID)
func updateMonster(_ monster: Monster)
```

**執行緒安全**：
- 使用 NSLock 保護所有共享狀態
- 所有公開方法都是執行緒安全的

---

### 4. Commands 模組

遊戲指令系統。

#### Command 協定

所有指令必須實作的協定。

```swift
protocol Command {
    static var name: String { get }           // 主要名稱
    static var aliases: [String] { get }      // 別名
    static var description: String { get }    // 說明
    static var usage: String { get }          // 用法
    static var requiredAdminLevel: AdminTier { get }  // 權限需求

    init()
    func execute(context: CommandContext) -> CommandResult
}
```

#### CommandContext

指令執行的上下文資訊。

```swift
struct CommandContext {
    let session: Session      // 玩家 Session
    let playerId: UUID        // 玩家 ID
    var player: Player        // 玩家資料
    let args: [String]        // 指令參數
    let rawInput: String      // 原始輸入
}
```

#### CommandParser

指令解析器，負責解析玩家輸入並執行對應的指令。

**主要功能**：
- 註冊和管理所有指令
- 解析輸入字串
- 處理方向快捷鍵（n, s, e, w, u, d）
- 檢查權限並執行指令

**指令類別**：

| 類別 | 指令 |
|------|------|
| 移動 | MoveCommand |
| 查看 | LookCommand, StatusCommand, WhoCommand |
| 通訊 | SayCommand, YellCommand |
| 系統 | HelpCommand, QuitCommand |
| 戰鬥 | AttackCommand, FleeCommand |
| 任務 | QuestCommand, AcceptCommand, CompleteCommand, AbandonCommand |
| 商店 | ShopCommand, BuyCommand, SellCommand |
| 背包 | InventoryCommand, UseCommand, EquipCommand, UnequipCommand |
| 管理員 | KickCommand, BanCommand, MuteCommand, TeleportCommand... |

---

### 5. Combat 模組

戰鬥系統。

#### CombatManager

管理所有活動戰鬥的單例類別。

**主要職責**：
- 追蹤活動的戰鬥狀態
- 計算傷害和處理攻擊
- 管理戰鬥參與者

**傷害公式**：
```
最終傷害 = 基礎傷害 * (1 - 防禦減傷)
防禦減傷 = 防禦力 / (防禦力 + 50)
```

#### CombatState

單場戰鬥的狀態。

**主要屬性**：
- `id`：戰鬥唯一識別碼
- `roomId`：戰鬥發生的房間
- `participants`：參與者列表
- `isActive`：戰鬥是否進行中

#### CombatantType

戰鬥參與者類型。

```swift
enum CombatantType {
    case player(UUID)
    case monster(UUID)
}
```

---

### 6. Quest 模組

任務系統。

#### Quest

任務定義結構。

**主要屬性**：
- 基本資訊：id, name, description
- 類型：type（single, repeatable, daily...）
- 目標：objectives（QuestObjective 陣列）
- 獎勵：rewards（經驗、金幣、物品）
- 前置條件：prerequisites, levelRequired
- 冷卻：cooldown（可重複任務）

#### QuestProgress

玩家的任務進度。

**主要屬性**：
- `questId`：任務 ID
- `status`：任務狀態（active, complete, turnedIn）
- `objectiveProgress`：各目標的進度
- `acceptedAt`、`completedAt`：時間戳記

#### QuestManager

任務管理器單例。

**主要方法**：
```swift
func getAvailableQuests(for player: Player) -> [Quest]
func getActiveQuests(for playerId: UUID) -> [QuestProgress]
func acceptQuest(playerId:questId:player:) -> Result<QuestProgress, MUDError>
func completeQuest(playerId:questId:) -> Result<QuestRewards, MUDError>
func abandonQuest(playerId:questId:) -> Result<Void, MUDError>
func updateKillProgress(playerId:monsterId:)
func updateCollectProgress(playerId:itemId:)
func updateVisitProgress(playerId:roomId:)
```

---

### 7. Shop 模組

商店系統。

#### Shop

商店定義結構。

**主要屬性**：
- 基本資訊：id, name, description
- 商品：itemIds
- 價格倍率：buyRate, sellRate
- 收購設定：buyAllItems

#### NPC

非玩家角色定義。

**主要屬性**：
- 基本資訊：id, name, description
- 類型：type（shopkeeper, questGiver...）
- 位置：roomId
- 關聯商店：shopId
- 對話：dialogues

#### ShopManager

商店管理器單例。

**主要方法**：
```swift
func getShop(_ shopId: String) -> Shop?
func getShopInRoom(_ roomId: String) -> Shop?
func getNPCInRoom(_ roomId: String, type: NPCType?) -> NPC?
func buyItem(playerId:itemId:count:shopId:) -> Result<(item, totalCost), MUDError>
func sellItem(playerId:itemId:count:shopId:) -> Result<(item, totalEarned), MUDError>
```

---

### 8. Persistence 模組

資料持久化系統。

#### Repository 協定

通用儲存庫協定。

```swift
protocol Repository<Entity> {
    associatedtype Entity: Identifiable & Codable where Entity.ID == UUID

    func save(_ entity: Entity) async throws
    func load(id: UUID) async throws -> Entity?
    func delete(id: UUID) async throws
    func loadAll() async throws -> [Entity]
}
```

#### PlayerRepository 協定

玩家專用儲存庫協定，擴展 Repository。

```swift
protocol PlayerRepository: Repository where Entity == Player {
    func loadByName(_ name: String) async throws -> Player?
}
```

#### JSONFileStorage

JSON 檔案儲存服務。

**主要方法**：
```swift
func save<T: Encodable>(_ entity: T, to filePath: String) throws
func load<T: Decodable>(_ type: T.Type, from filePath: String) throws -> T?
func delete(filePath: String) throws
func listFiles(in directory: String) throws -> [String]
```

#### JSONPlayerRepository

基於 JSON 檔案的玩家儲存庫實作。

**特點**：
- 每個玩家存為獨立的 JSON 檔案
- 維護名稱索引以支援按名稱查詢
- 提供同步和非同步兩種 API

---

## 資料流說明

### 玩家登入流程

```
1. 客戶端連線
   └─> MUDServer 接受連線
       └─> ClientHandler 初始化
           └─> Session 建立

2. 輸入使用者名稱
   └─> Session 接收輸入
       └─> 驗證或建立帳號

3. 驗證密碼
   └─> JSONPlayerRepository.loadByName()
       └─> 比對密碼雜湊

4. 登入成功
   └─> World.addPlayer()
       └─> Room.playerIds.insert()
           └─> 通知同房間玩家
```

### 指令執行流程

```
1. 玩家輸入 "attack slime"
   └─> Session 接收文字

2. 解析指令
   └─> CommandParser.parse()
       └─> 分割指令名稱和參數
           └─> 查找對應的 Command

3. 權限檢查
   └─> 比對 player.adminLevel 和 Command.requiredAdminLevel

4. 建立 CommandContext

5. 執行指令
   └─> AttackCommand.execute()
       └─> CombatManager.startCombat()
           └─> CombatManager.processAttack()

6. 更新狀態
   └─> World.updatePlayer()
       └─> World.updateMonster()

7. 回傳結果
   └─> Session.send()
       └─> ClientHandler.write()
```

### 任務完成流程

```
1. 玩家擊殺怪物
   └─> AttackCommand 執行

2. 怪物死亡
   └─> World.removeMonster()

3. 更新任務進度
   └─> QuestManager.updateKillProgress()
       └─> 檢查所有進行中任務
           └─> 更新符合條件的目標進度

4. 玩家輸入 "complete quest_id"
   └─> CompleteCommand 執行
       └─> QuestManager.completeQuest()
           └─> 驗證目標完成
               └─> 發放獎勵
                   └─> 更新玩家資料
```

---

## 擴展指南

### 新增遊戲指令

1. 建立新的指令類別：

```swift
// Sources/SwiftMUD/Commands/MyNewCommand.swift
final class MyNewCommand: Command {
    static let name = "mycommand"
    static let aliases = ["mc", "新指令"]
    static let description = "這是新指令的說明"
    static let usage = "mycommand <參數>"
    static let requiredAdminLevel: AdminTier = .player

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        // 實作指令邏輯

        // 成功時
        return .success(message: "執行成功")

        // 失敗時
        // return .failure(error: .customError("錯誤訊息"))
    }
}
```

2. 在 CommandParser 中註冊：

```swift
// CommandParser.swift 的 registerBuiltInCommands() 方法中
register(MyNewCommand.self)
```

### 新增怪物類型

在 `World.swift` 的 `loadInitialData()` 方法中加入新的怪物模板：

```swift
monsterTemplates["dragon"] = MonsterTemplate(
    id: "dragon",
    name: "巨龍",
    description: "一隻噴火的巨龍",
    level: 50,
    maxHP: 5000,
    attack: 100,
    defense: 50,
    magic: 80,
    expReward: 5000,
    goldReward: 500...1000,
    lootTable: [
        LootEntry(itemId: "dragon_scale", chance: 0.3, countRange: 1...3),
        LootEntry(itemId: "dragon_fang", chance: 0.1, countRange: 1...1)
    ],
    aggressive: true,
    respawnTime: 3600  // 1 小時
)
```

### 新增物品類型

在 `World.swift` 的 `loadInitialData()` 方法中加入新的物品模板：

```swift
itemTemplates["legendary_sword"] = ItemTemplate(
    id: "legendary_sword",
    name: "傳說之劍",
    description: "傳說中的神兵利器",
    type: .weapon,
    equipSlot: .mainHand,
    statBonus: [.attack: 100, .critRate: 10],
    levelRequired: 50,
    basePrice: 100000,
    stackable: false
)
```

### 新增房間

在 `World.swift` 的 `loadInitialData()` 方法中加入新房間：

```swift
let dragonLair = Room(
    id: "dragon_lair",
    name: "龍穴",
    description: "巨龍的巢穴，四處散落著寶藏和骸骨。",
    exits: [.north: "deep_forest"],
    canPvP: true
)
rooms[dragonLair.id] = dragonLair

// 記得更新連接房間的出口
if var deepForest = rooms["deep_forest"] {
    deepForest.exits[.south] = "dragon_lair"
    rooms["deep_forest"] = deepForest
}
```

### 新增任務

在 `QuestManager.swift` 的 `loadInitialQuests()` 方法中加入新任務：

```swift
let dragonSlayer = Quest(
    id: "dragon_slayer",
    name: "屠龍勇士",
    description: "傳說中的巨龍正在威脅這片土地，勇士啊，去消滅牠！",
    objectives: [
        .kill(monsterId: "dragon", count: 1)
    ],
    rewards: QuestRewards(
        exp: 10000,
        gold: 5000,
        items: ["legendary_sword": 1]
    ),
    prerequisites: ["wolf_threat"],
    levelRequired: 40
)
quests[dragonSlayer.id] = dragonSlayer
```

### 新增技能

在 `World.swift` 的 `loadInitialData()` 方法中加入新技能：

```swift
skills["thunder_strike"] = Skill(
    id: "thunder_strike",
    name: "雷霆一擊",
    description: "召喚雷電打擊敵人",
    type: .active,
    mpCost: 50,
    castTime: 2.0,
    cooldown: 15,
    effects: [
        .damage(base: 100, scaling: 2.0, stat: .magic),
        .stun(duration: 2.0)
    ],
    maxLevel: 5
)
```

### 新增 NPC 和商店

在 `ShopManager.swift` 的 `loadInitialData()` 方法中加入：

```swift
// 新商店
let magicShop = Shop(
    id: "magic_shop",
    name: "魔法商店",
    description: "販售各種魔法物品和捲軸",
    itemIds: ["mana_potion", "scroll_of_teleport"],
    buyRate: 1.5,
    sellRate: 0.3
)
shops[magicShop.id] = magicShop

// 新 NPC
let wizardNPC = NPC(
    id: "wizard_merlin",
    name: "梅林法師",
    description: "一位白髮蒼蒼的老法師",
    type: .shopkeeper,
    roomId: "temple",
    shopId: "magic_shop",
    dialogues: [
        "魔法的世界深不可測...",
        "需要什麼魔法物品嗎？"
    ]
)
npcs[wizardNPC.id] = wizardNPC
```

---

## 設計原則

### 單例模式

以下類別使用單例模式以確保全域唯一性：
- `World.shared`
- `CommandParser.shared`
- `CombatManager.shared`
- `QuestManager.shared`
- `ShopManager.shared`

### 執行緒安全

- 所有共享狀態都使用 `NSLock` 保護
- 公開的 API 都是執行緒安全的
- 內部方法（以 `Internal` 結尾）不加鎖，需在已加鎖的情況下呼叫

### 錯誤處理

使用 `Result` 類型和自定義 `MUDError` 枚舉進行錯誤處理：

```swift
enum MUDError: Error {
    case playerNotFound(name: String)
    case roomNotFound(id: String)
    case unknownCommand(command: String)
    case permissionDenied(required: AdminTier)
    // ...
}
```

### 可擴展性

- 使用協定定義介面（`Command`, `Repository`）
- 使用泛型提高程式碼重用性
- 模組化設計便於新增功能

---

*本文件最後更新於 Phase 10 完成時*
