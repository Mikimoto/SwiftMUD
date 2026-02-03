# Swift MUD 遊戲實作計劃

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 使用 Swift 實作一個跨平台 MUD 伺服器，包含即時戰鬥、技能、任務、商店與管理系統。

**Architecture:** 採用分層架構，Network Layer (SwiftNIO) 處理連線，Game Layer 管理世界狀態，Combat Engine 處理即時戰鬥，Repository Pattern 抽象化資料存取。所有系統透過 CommandParser 統一處理玩家輸入。

**Tech Stack:** Swift 5.9+, SwiftNIO, PostgresNIO/MySQLNIO, Swift Crypto, Swift Argument Parser

---

## Phase 1: 專案基礎架構

### Task 1: 初始化 Swift Package

**Files:**
- Create: `SwiftMUD/Package.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/main.swift`

**Step 1: 建立專案目錄**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD && mkdir -p SwiftMUD/Tests/SwiftMUDTests`

**Step 2: 建立 Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftMUD",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftMUD",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "SwiftMUDTests",
            dependencies: ["SwiftMUD"]
        ),
    ]
)
```

**Step 3: 建立 main.swift 進入點**

```swift
import ArgumentParser
import Logging

@main
struct SwiftMUD: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftmud",
        abstract: "A Swift MUD game server"
    )

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 4000

    @Option(name: .shortAndLong, help: "Host to bind to")
    var host: String = "0.0.0.0"

    func run() throws {
        var logger = Logger(label: "com.swiftmud.server")
        logger.logLevel = .info
        logger.info("SwiftMUD server starting on \(host):\(port)")

        // TODO: Start server
        print("SwiftMUD server placeholder - press Ctrl+C to exit")
        dispatchMain()
    }
}
```

**Step 4: 驗證專案可編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 5: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: initialize Swift package with dependencies"
```

---

### Task 2: 建立基礎資料模型 - Enums 與 Types

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Game/Types.swift`
- Create: `SwiftMUD/Tests/SwiftMUDTests/TypesTests.swift`

**Step 1: 建立目錄結構**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD/Game`

**Step 2: 建立 Types.swift**

```swift
import Foundation

// MARK: - 管理權限層級
enum AdminTier: Int, Codable, Comparable {
    case player = 0      // 一般玩家
    case trainee = 1     // 見習GM
    case gm = 2          // GM
    case superGM = 3     // 超級GM
    case creator = 4     // 創世神

    static func < (lhs: AdminTier, rhs: AdminTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 裝備欄位
enum EquipmentSlot: String, Codable, CaseIterable {
    case head
    case body
    case hands
    case legs
    case feet
    case mainHand
    case offHand
    case accessory1
    case accessory2
}

// MARK: - 技能類型
enum SkillType: String, Codable {
    case active
    case passive
}

// MARK: - 任務類型
enum QuestType: String, Codable {
    case single      // 單次任務
    case repeatable  // 可重複任務
    case chain       // 任務鏈
}

// MARK: - 任務目標
enum QuestObjective: Codable, Equatable {
    case kill(monsterId: String, count: Int)
    case collect(itemId: String, count: Int)
    case visit(roomId: String)
    case talk(npcId: String)
    case reachLevel(level: Int)
    case learnSkill(skillId: String)
}

// MARK: - 屬性類型
enum Stat: String, Codable {
    case maxHP
    case maxMP
    case attack
    case defense
    case magic
    case speed
    case critRate
    case critDamage
}

// MARK: - 效果類型
enum Effect: Codable, Equatable {
    case damage(base: Int, scaling: Double, stat: Stat)
    case heal(base: Int, scaling: Double)
    case buff(stat: Stat, value: Int, duration: TimeInterval)
    case debuff(stat: Stat, value: Int, duration: TimeInterval)
    case dot(damage: Int, interval: TimeInterval, duration: TimeInterval)
    case hot(heal: Int, interval: TimeInterval, duration: TimeInterval)
    case taunt(duration: TimeInterval)
    case stun(duration: TimeInterval)
}

// MARK: - 方向
enum Direction: String, Codable, CaseIterable {
    case north = "n"
    case south = "s"
    case east = "e"
    case west = "w"
    case up = "u"
    case down = "d"

    var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        case .up: return .down
        case .down: return .up
        }
    }

    var displayName: String {
        switch self {
        case .north: return "北"
        case .south: return "南"
        case .east: return "東"
        case .west: return "西"
        case .up: return "上"
        case .down: return "下"
        }
    }
}
```

**Step 3: 建立測試檔案**

```swift
import XCTest
@testable import SwiftMUD

final class TypesTests: XCTestCase {

    func testAdminTierComparison() {
        XCTAssertTrue(AdminTier.player < AdminTier.trainee)
        XCTAssertTrue(AdminTier.trainee < AdminTier.gm)
        XCTAssertTrue(AdminTier.gm < AdminTier.superGM)
        XCTAssertTrue(AdminTier.superGM < AdminTier.creator)
    }

    func testDirectionOpposite() {
        XCTAssertEqual(Direction.north.opposite, .south)
        XCTAssertEqual(Direction.south.opposite, .north)
        XCTAssertEqual(Direction.east.opposite, .west)
        XCTAssertEqual(Direction.west.opposite, .east)
        XCTAssertEqual(Direction.up.opposite, .down)
        XCTAssertEqual(Direction.down.opposite, .up)
    }

    func testEquipmentSlotAllCases() {
        XCTAssertEqual(EquipmentSlot.allCases.count, 9)
    }
}
```

**Step 4: 執行測試**

Run: `cd SwiftMUD && swift test --filter TypesTests`
Expected: All tests passed

**Step 5: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add base types and enums for game entities"
```

---

### Task 3: 建立 Player 資料模型

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Game/Player.swift`
- Create: `SwiftMUD/Tests/SwiftMUDTests/PlayerTests.swift`

**Step 1: 建立 Player.swift**

```swift
import Foundation

struct Player: Codable, Identifiable {
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

    // 位置
    var currentRoomId: String

    // 技能 (技能ID -> 等級)
    var skills: [String: Int]

    // 管理權限
    var adminLevel: AdminTier

    // 狀態
    var isMuted: Bool
    var mutedUntil: Date?
    var isBanned: Bool
    var bannedUntil: Date?

    // 建立新玩家
    static func create(name: String, passwordHash: String, startingRoom: String = "town_square") -> Player {
        Player(
            id: UUID(),
            name: name,
            passwordHash: passwordHash,
            level: 1,
            exp: 0,
            gold: 100,
            currentHP: 100,
            maxHP: 100,
            currentMP: 50,
            maxMP: 50,
            baseAttack: 10,
            baseDefense: 5,
            baseMagic: 5,
            currentRoomId: startingRoom,
            skills: [:],
            adminLevel: .player,
            isMuted: false,
            mutedUntil: nil,
            isBanned: false,
            bannedUntil: nil
        )
    }

    // 計算升級所需經驗
    func expToNextLevel() -> Int {
        level * 100
    }

    // 是否存活
    var isAlive: Bool {
        currentHP > 0
    }

    // 治療
    mutating func heal(_ amount: Int) {
        currentHP = min(currentHP + amount, maxHP)
    }

    // 受傷
    mutating func takeDamage(_ amount: Int) {
        currentHP = max(currentHP - amount, 0)
    }

    // 增加經驗
    mutating func gainExp(_ amount: Int) -> Bool {
        exp += amount
        var leveledUp = false
        while exp >= expToNextLevel() {
            exp -= expToNextLevel()
            level += 1
            leveledUp = true
            onLevelUp()
        }
        return leveledUp
    }

    private mutating func onLevelUp() {
        maxHP += 10
        maxMP += 5
        baseAttack += 2
        baseDefense += 1
        baseMagic += 1
        currentHP = maxHP
        currentMP = maxMP
    }
}
```

**Step 2: 建立測試**

```swift
import XCTest
@testable import SwiftMUD

final class PlayerTests: XCTestCase {

    func testCreateNewPlayer() {
        let player = Player.create(name: "TestPlayer", passwordHash: "hash123")

        XCTAssertEqual(player.name, "TestPlayer")
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.gold, 100)
        XCTAssertEqual(player.currentHP, 100)
        XCTAssertEqual(player.maxHP, 100)
        XCTAssertEqual(player.adminLevel, .player)
        XCTAssertEqual(player.currentRoomId, "town_square")
    }

    func testExpToNextLevel() {
        var player = Player.create(name: "Test", passwordHash: "hash")
        XCTAssertEqual(player.expToNextLevel(), 100) // level 1 = 100 exp

        player.level = 5
        XCTAssertEqual(player.expToNextLevel(), 500) // level 5 = 500 exp
    }

    func testGainExpAndLevelUp() {
        var player = Player.create(name: "Test", passwordHash: "hash")
        let initialMaxHP = player.maxHP

        let leveledUp = player.gainExp(150)

        XCTAssertTrue(leveledUp)
        XCTAssertEqual(player.level, 2)
        XCTAssertEqual(player.exp, 50) // 150 - 100 = 50
        XCTAssertEqual(player.maxHP, initialMaxHP + 10)
    }

    func testTakeDamageAndHeal() {
        var player = Player.create(name: "Test", passwordHash: "hash")

        player.takeDamage(30)
        XCTAssertEqual(player.currentHP, 70)
        XCTAssertTrue(player.isAlive)

        player.heal(20)
        XCTAssertEqual(player.currentHP, 90)

        player.heal(100) // 不應超過 maxHP
        XCTAssertEqual(player.currentHP, 100)

        player.takeDamage(200) // 不應低於 0
        XCTAssertEqual(player.currentHP, 0)
        XCTAssertFalse(player.isAlive)
    }
}
```

**Step 3: 執行測試**

Run: `cd SwiftMUD && swift test --filter PlayerTests`
Expected: All tests passed

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add Player model with level and combat stats"
```

---

### Task 4: 建立 Room 資料模型

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Game/Room.swift`
- Create: `SwiftMUD/Tests/SwiftMUDTests/RoomTests.swift`

**Step 1: 建立 Room.swift**

```swift
import Foundation

struct Room: Codable, Identifiable {
    let id: String
    var name: String
    var description: String

    // 連接的房間 (方向 -> 房間ID)
    var exits: [Direction: String]

    // 房間屬性
    var isSafeZone: Bool
    var canPvP: Bool
    var respawnPoint: Bool

    // 房間內的實體 ID
    var playerIds: Set<String>
    var monsterIds: Set<String>
    var itemIds: Set<String>
    var npcIds: Set<String>
    var shopId: String?

    init(
        id: String,
        name: String,
        description: String,
        exits: [Direction: String] = [:],
        isSafeZone: Bool = false,
        canPvP: Bool = true,
        respawnPoint: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.exits = exits
        self.isSafeZone = isSafeZone
        self.canPvP = canPvP
        self.respawnPoint = respawnPoint
        self.playerIds = []
        self.monsterIds = []
        self.itemIds = []
        self.npcIds = []
        self.shopId = nil
    }

    // 取得可用出口的描述
    func exitsDescription() -> String {
        guard !exits.isEmpty else {
            return "這裡沒有明顯的出口。"
        }
        let exitList = exits.keys.map { $0.displayName }.sorted().joined(separator: "、")
        return "出口：\(exitList)"
    }

    // 完整的房間描述
    func fullDescription(playerNames: [String], monsterNames: [String]) -> String {
        var lines: [String] = []
        lines.append("【\(name)】")
        lines.append(description)
        lines.append("")
        lines.append(exitsDescription())

        if !playerNames.isEmpty {
            lines.append("玩家：\(playerNames.joined(separator: "、"))")
        }
        if !monsterNames.isEmpty {
            lines.append("怪物：\(monsterNames.joined(separator: "、"))")
        }

        return lines.joined(separator: "\n")
    }
}
```

**Step 2: 建立測試**

```swift
import XCTest
@testable import SwiftMUD

final class RoomTests: XCTestCase {

    func testCreateRoom() {
        let room = Room(
            id: "town_square",
            name: "城鎮廣場",
            description: "一個繁忙的城鎮廣場，四周圍繞著商店和民宅。",
            exits: [.north: "temple", .east: "market"],
            isSafeZone: true
        )

        XCTAssertEqual(room.id, "town_square")
        XCTAssertEqual(room.name, "城鎮廣場")
        XCTAssertTrue(room.isSafeZone)
        XCTAssertEqual(room.exits.count, 2)
    }

    func testExitsDescription() {
        let room = Room(
            id: "test",
            name: "Test",
            description: "Test room",
            exits: [.north: "a", .south: "b", .east: "c"]
        )

        let desc = room.exitsDescription()
        XCTAssertTrue(desc.contains("北"))
        XCTAssertTrue(desc.contains("南"))
        XCTAssertTrue(desc.contains("東"))
    }

    func testEmptyExitsDescription() {
        let room = Room(id: "test", name: "Test", description: "Test")
        XCTAssertEqual(room.exitsDescription(), "這裡沒有明顯的出口。")
    }

    func testFullDescription() {
        let room = Room(
            id: "test",
            name: "測試房間",
            description: "這是一個測試房間。",
            exits: [.north: "other"]
        )

        let desc = room.fullDescription(playerNames: ["Alice", "Bob"], monsterNames: ["哥布林"])

        XCTAssertTrue(desc.contains("【測試房間】"))
        XCTAssertTrue(desc.contains("這是一個測試房間。"))
        XCTAssertTrue(desc.contains("出口：北"))
        XCTAssertTrue(desc.contains("玩家：Alice、Bob"))
        XCTAssertTrue(desc.contains("怪物：哥布林"))
    }
}
```

**Step 3: 執行測試**

Run: `cd SwiftMUD && swift test --filter RoomTests`
Expected: All tests passed

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add Room model with exits and descriptions"
```

---

### Task 5: 建立 Item 與 Inventory 資料模型

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Game/Item.swift`
- Create: `SwiftMUD/Tests/SwiftMUDTests/ItemTests.swift`

**Step 1: 建立 Item.swift**

```swift
import Foundation

// 物品模板（定義）
struct ItemTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: ItemType

    // 裝備屬性
    let equipSlot: EquipmentSlot?
    let statBonus: [Stat: Int]
    let levelRequired: Int

    // 經濟屬性
    let basePrice: Int
    let stackable: Bool
    let maxStack: Int

    init(
        id: String,
        name: String,
        description: String,
        type: ItemType,
        equipSlot: EquipmentSlot? = nil,
        statBonus: [Stat: Int] = [:],
        levelRequired: Int = 1,
        basePrice: Int = 0,
        stackable: Bool = false,
        maxStack: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.equipSlot = equipSlot
        self.statBonus = statBonus
        self.levelRequired = levelRequired
        self.basePrice = basePrice
        self.stackable = stackable
        self.maxStack = maxStack
    }
}

enum ItemType: String, Codable {
    case weapon
    case armor
    case accessory
    case consumable
    case material
    case quest
    case misc
}

// 物品實例（玩家擁有的）
struct ItemInstance: Codable, Identifiable {
    let id: UUID
    let templateId: String
    var count: Int

    init(templateId: String, count: Int = 1) {
        self.id = UUID()
        self.templateId = templateId
        self.count = count
    }
}

// 背包系統
struct Inventory: Codable {
    var items: [ItemInstance]
    let maxSlots: Int

    init(maxSlots: Int = 20) {
        self.items = []
        self.maxSlots = maxSlots
    }

    var usedSlots: Int {
        items.count
    }

    var isFull: Bool {
        usedSlots >= maxSlots
    }

    mutating func addItem(_ templateId: String, count: Int = 1, stackable: Bool) -> Bool {
        if stackable, let index = items.firstIndex(where: { $0.templateId == templateId }) {
            items[index].count += count
            return true
        }

        guard !isFull else { return false }
        items.append(ItemInstance(templateId: templateId, count: count))
        return true
    }

    mutating func removeItem(_ templateId: String, count: Int = 1) -> Bool {
        guard let index = items.firstIndex(where: { $0.templateId == templateId }) else {
            return false
        }

        if items[index].count > count {
            items[index].count -= count
        } else {
            items.remove(at: index)
        }
        return true
    }

    func countOf(_ templateId: String) -> Int {
        items.filter { $0.templateId == templateId }.reduce(0) { $0 + $1.count }
    }
}
```

**Step 2: 建立測試**

```swift
import XCTest
@testable import SwiftMUD

final class ItemTests: XCTestCase {

    func testCreateItemTemplate() {
        let sword = ItemTemplate(
            id: "iron_sword",
            name: "鐵劍",
            description: "一把普通的鐵劍",
            type: .weapon,
            equipSlot: .mainHand,
            statBonus: [.attack: 10],
            levelRequired: 1,
            basePrice: 100
        )

        XCTAssertEqual(sword.id, "iron_sword")
        XCTAssertEqual(sword.name, "鐵劍")
        XCTAssertEqual(sword.type, .weapon)
        XCTAssertEqual(sword.equipSlot, .mainHand)
        XCTAssertEqual(sword.statBonus[.attack], 10)
    }

    func testInventoryAddItem() {
        var inventory = Inventory(maxSlots: 5)

        let success = inventory.addItem("iron_sword", stackable: false)
        XCTAssertTrue(success)
        XCTAssertEqual(inventory.usedSlots, 1)
    }

    func testInventoryStackable() {
        var inventory = Inventory(maxSlots: 5)

        _ = inventory.addItem("health_potion", count: 5, stackable: true)
        _ = inventory.addItem("health_potion", count: 3, stackable: true)

        XCTAssertEqual(inventory.usedSlots, 1) // 應該堆疊
        XCTAssertEqual(inventory.countOf("health_potion"), 8)
    }

    func testInventoryFull() {
        var inventory = Inventory(maxSlots: 2)

        _ = inventory.addItem("item1", stackable: false)
        _ = inventory.addItem("item2", stackable: false)
        let success = inventory.addItem("item3", stackable: false)

        XCTAssertFalse(success)
        XCTAssertTrue(inventory.isFull)
    }

    func testInventoryRemoveItem() {
        var inventory = Inventory(maxSlots: 5)

        _ = inventory.addItem("health_potion", count: 5, stackable: true)

        let success = inventory.removeItem("health_potion", count: 3)
        XCTAssertTrue(success)
        XCTAssertEqual(inventory.countOf("health_potion"), 2)

        _ = inventory.removeItem("health_potion", count: 2)
        XCTAssertEqual(inventory.countOf("health_potion"), 0)
        XCTAssertEqual(inventory.usedSlots, 0)
    }
}
```

**Step 3: 執行測試**

Run: `cd SwiftMUD && swift test --filter ItemTests`
Expected: All tests passed

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add Item templates and Inventory system"
```

---

### Task 6: 建立 Monster 資料模型

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Game/Monster.swift`
- Create: `SwiftMUD/Tests/SwiftMUDTests/MonsterTests.swift`

**Step 1: 建立 Monster.swift**

```swift
import Foundation

// 怪物模板
struct MonsterTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String

    let level: Int
    let maxHP: Int
    let attack: Int
    let defense: Int
    let magic: Int

    let expReward: Int
    let goldReward: ClosedRange<Int>
    let lootTable: [LootEntry]

    // 行為屬性
    let aggressive: Bool
    let respawnTime: TimeInterval
}

struct LootEntry: Codable {
    let itemId: String
    let chance: Double // 0.0 - 1.0
    let countRange: ClosedRange<Int>
}

// 怪物實例
struct Monster: Codable, Identifiable {
    let id: UUID
    let templateId: String
    var name: String

    var currentHP: Int
    var maxHP: Int
    var attack: Int
    var defense: Int
    var magic: Int

    var currentRoomId: String
    var inCombatWith: UUID? // 玩家 ID

    var respawnTime: TimeInterval
    var diedAt: Date?

    init(from template: MonsterTemplate, roomId: String) {
        self.id = UUID()
        self.templateId = template.id
        self.name = template.name
        self.currentHP = template.maxHP
        self.maxHP = template.maxHP
        self.attack = template.attack
        self.defense = template.defense
        self.magic = template.magic
        self.currentRoomId = roomId
        self.inCombatWith = nil
        self.respawnTime = template.respawnTime
        self.diedAt = nil
    }

    var isAlive: Bool {
        currentHP > 0
    }

    mutating func takeDamage(_ amount: Int) {
        currentHP = max(currentHP - amount, 0)
        if currentHP == 0 {
            diedAt = Date()
        }
    }

    mutating func respawn(template: MonsterTemplate) {
        currentHP = maxHP
        diedAt = nil
        inCombatWith = nil
    }

    func shouldRespawn() -> Bool {
        guard let diedAt = diedAt else { return false }
        return Date().timeIntervalSince(diedAt) >= respawnTime
    }
}
```

**Step 2: 建立測試**

```swift
import XCTest
@testable import SwiftMUD

final class MonsterTests: XCTestCase {

    let wolfTemplate = MonsterTemplate(
        id: "wolf",
        name: "野狼",
        description: "一隻凶猛的野狼",
        level: 3,
        maxHP: 50,
        attack: 8,
        defense: 3,
        magic: 0,
        expReward: 30,
        goldReward: 5...15,
        lootTable: [
            LootEntry(itemId: "wolf_pelt", chance: 0.5, countRange: 1...1),
            LootEntry(itemId: "wolf_fang", chance: 0.2, countRange: 1...2)
        ],
        aggressive: true,
        respawnTime: 60
    )

    func testCreateMonsterFromTemplate() {
        let wolf = Monster(from: wolfTemplate, roomId: "forest_entrance")

        XCTAssertEqual(wolf.name, "野狼")
        XCTAssertEqual(wolf.currentHP, 50)
        XCTAssertEqual(wolf.maxHP, 50)
        XCTAssertEqual(wolf.attack, 8)
        XCTAssertEqual(wolf.currentRoomId, "forest_entrance")
        XCTAssertTrue(wolf.isAlive)
    }

    func testMonsterTakeDamage() {
        var wolf = Monster(from: wolfTemplate, roomId: "forest")

        wolf.takeDamage(20)
        XCTAssertEqual(wolf.currentHP, 30)
        XCTAssertTrue(wolf.isAlive)

        wolf.takeDamage(50)
        XCTAssertEqual(wolf.currentHP, 0)
        XCTAssertFalse(wolf.isAlive)
        XCTAssertNotNil(wolf.diedAt)
    }

    func testMonsterRespawn() {
        var wolf = Monster(from: wolfTemplate, roomId: "forest")
        wolf.takeDamage(100)
        XCTAssertFalse(wolf.isAlive)

        wolf.respawn(template: wolfTemplate)
        XCTAssertTrue(wolf.isAlive)
        XCTAssertEqual(wolf.currentHP, 50)
        XCTAssertNil(wolf.diedAt)
    }
}
```

**Step 3: 執行測試**

Run: `cd SwiftMUD && swift test --filter MonsterTests`
Expected: All tests passed

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add Monster template and instance models"
```

---

### Task 7: 建立 Skill 資料模型

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Game/Skill.swift`
- Create: `SwiftMUD/Tests/SwiftMUDTests/SkillTests.swift`

**Step 1: 建立 Skill.swift**

```swift
import Foundation

struct Skill: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: SkillType

    // 前置技能需求 (技能ID -> 需求等級)
    let prerequisites: [String: Int]

    // 主動技能屬性
    let mpCost: Int
    let castTime: TimeInterval
    let cooldown: TimeInterval
    let effects: [Effect]

    // 被動技能屬性
    let statBonus: [Stat: Int]

    // 最大等級
    let maxLevel: Int

    init(
        id: String,
        name: String,
        description: String,
        type: SkillType,
        prerequisites: [String: Int] = [:],
        mpCost: Int = 0,
        castTime: TimeInterval = 0,
        cooldown: TimeInterval = 0,
        effects: [Effect] = [],
        statBonus: [Stat: Int] = [:],
        maxLevel: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.prerequisites = prerequisites
        self.mpCost = mpCost
        self.castTime = castTime
        self.cooldown = cooldown
        self.effects = effects
        self.statBonus = statBonus
        self.maxLevel = maxLevel
    }

    // 計算技能等級加成後的 MP 消耗
    func mpCostAtLevel(_ level: Int) -> Int {
        mpCost + (level - 1) * 5
    }

    // 計算技能等級加成後的效果倍率
    func effectMultiplier(at level: Int) -> Double {
        1.0 + Double(level - 1) * 0.15
    }
}

// 玩家的技能冷卻狀態
struct SkillCooldownState {
    var cooldowns: [String: Date] // 技能ID -> 冷卻結束時間
    var casting: (skillId: String, endsAt: Date)? // 正在施法的技能

    init() {
        self.cooldowns = [:]
        self.casting = nil
    }

    func isOnCooldown(_ skillId: String) -> Bool {
        guard let endTime = cooldowns[skillId] else { return false }
        return Date() < endTime
    }

    func remainingCooldown(_ skillId: String) -> TimeInterval {
        guard let endTime = cooldowns[skillId] else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }

    mutating func startCooldown(_ skillId: String, duration: TimeInterval) {
        cooldowns[skillId] = Date().addingTimeInterval(duration)
    }

    var isCasting: Bool {
        guard let casting = casting else { return false }
        return Date() < casting.endsAt
    }

    mutating func startCasting(_ skillId: String, castTime: TimeInterval) {
        casting = (skillId, Date().addingTimeInterval(castTime))
    }

    mutating func finishCasting() {
        casting = nil
    }
}
```

**Step 2: 建立測試**

```swift
import XCTest
@testable import SwiftMUD

final class SkillTests: XCTestCase {

    func testCreateActiveSkill() {
        let fireball = Skill(
            id: "fireball",
            name: "火球術",
            description: "發射一顆火球造成魔法傷害",
            type: .active,
            mpCost: 20,
            castTime: 1.5,
            cooldown: 8,
            effects: [.damage(base: 50, scaling: 1.5, stat: .magic)],
            maxLevel: 5
        )

        XCTAssertEqual(fireball.id, "fireball")
        XCTAssertEqual(fireball.type, .active)
        XCTAssertEqual(fireball.mpCost, 20)
        XCTAssertEqual(fireball.castTime, 1.5)
        XCTAssertEqual(fireball.cooldown, 8)
    }

    func testCreatePassiveSkill() {
        let toughness = Skill(
            id: "toughness",
            name: "強壯體魄",
            description: "永久提升最大生命值",
            type: .passive,
            statBonus: [.maxHP: 10],
            maxLevel: 3
        )

        XCTAssertEqual(toughness.type, .passive)
        XCTAssertEqual(toughness.statBonus[.maxHP], 10)
    }

    func testMpCostScaling() {
        let skill = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            type: .active,
            mpCost: 20,
            maxLevel: 5
        )

        XCTAssertEqual(skill.mpCostAtLevel(1), 20)
        XCTAssertEqual(skill.mpCostAtLevel(2), 25)
        XCTAssertEqual(skill.mpCostAtLevel(5), 40)
    }

    func testEffectMultiplier() {
        let skill = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            type: .active,
            maxLevel: 5
        )

        XCTAssertEqual(skill.effectMultiplier(at: 1), 1.0)
        XCTAssertEqual(skill.effectMultiplier(at: 2), 1.15, accuracy: 0.01)
        XCTAssertEqual(skill.effectMultiplier(at: 5), 1.6, accuracy: 0.01)
    }

    func testCooldownState() {
        var state = SkillCooldownState()

        XCTAssertFalse(state.isOnCooldown("fireball"))

        state.startCooldown("fireball", duration: 5)
        XCTAssertTrue(state.isOnCooldown("fireball"))
        XCTAssertTrue(state.remainingCooldown("fireball") > 4)
    }

    func testCastingState() {
        var state = SkillCooldownState()

        XCTAssertFalse(state.isCasting)

        state.startCasting("fireball", castTime: 1.5)
        XCTAssertTrue(state.isCasting)
        XCTAssertEqual(state.casting?.skillId, "fireball")

        state.finishCasting()
        XCTAssertFalse(state.isCasting)
    }
}
```

**Step 3: 執行測試**

Run: `cd SwiftMUD && swift test --filter SkillTests`
Expected: All tests passed

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add Skill model with cooldown state management"
```

---

### Task 8: 建立錯誤類型

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Core/MUDError.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Core/` (directory)

**Step 1: 建立目錄**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD/Core`

**Step 2: 建立 MUDError.swift**

```swift
import Foundation

enum MUDError: Error, Equatable {
    // 連線相關
    case connectionFailed(reason: String)
    case sessionExpired
    case notLoggedIn

    // 玩家相關
    case playerNotFound(name: String)
    case playerAlreadyExists(name: String)
    case invalidCredentials
    case accountBanned(until: Date?)
    case accountMuted(until: Date?)

    // 房間與移動
    case roomNotFound(id: String)
    case invalidDirection(direction: String)
    case noExitInDirection(direction: Direction)

    // 指令相關
    case invalidCommand(command: String)
    case unknownCommand(command: String)
    case missingArgument(name: String)
    case invalidArgument(name: String, value: String)

    // 物品與交易
    case itemNotFound(id: String)
    case insufficientGold(required: Int, has: Int)
    case inventoryFull
    case cannotEquip(reason: String)
    case levelTooLow(required: Int, has: Int)

    // 戰鬥相關
    case notInCombat
    case alreadyInCombat
    case targetNotFound(name: String)
    case cannotAttackInSafeZone
    case skillOnCooldown(skillId: String, remaining: TimeInterval)
    case insufficientMP(required: Int, has: Int)
    case stillCasting
    case skillNotLearned(skillId: String)
    case prerequisiteNotMet(skillId: String, required: String, requiredLevel: Int)

    // 任務相關
    case questNotFound(id: String)
    case questAlreadyActive(id: String)
    case questNotActive(id: String)
    case questPrerequisiteNotMet(required: String)
    case questObjectiveNotComplete
    case questOnCooldown(remaining: TimeInterval)

    // 權限相關
    case permissionDenied(required: AdminTier)
    case targetHigherRank
    case cannotTargetSelf

    // 系統相關
    case databaseError(message: String)
    case configurationError(message: String)

    var localizedDescription: String {
        switch self {
        case .connectionFailed(let reason):
            return "連線失敗：\(reason)"
        case .sessionExpired:
            return "連線已過期，請重新登入"
        case .notLoggedIn:
            return "請先登入"
        case .playerNotFound(let name):
            return "找不到玩家：\(name)"
        case .playerAlreadyExists(let name):
            return "玩家名稱已被使用：\(name)"
        case .invalidCredentials:
            return "帳號或密碼錯誤"
        case .accountBanned(let until):
            if let until = until {
                return "帳號已被封禁至 \(until)"
            }
            return "帳號已被永久封禁"
        case .accountMuted(let until):
            if let until = until {
                return "你已被禁言至 \(until)"
            }
            return "你已被永久禁言"
        case .roomNotFound(let id):
            return "找不到房間：\(id)"
        case .invalidDirection(let direction):
            return "無效的方向：\(direction)"
        case .noExitInDirection(let direction):
            return "那個方向沒有出口（\(direction.displayName)）"
        case .invalidCommand(let command):
            return "無效的指令：\(command)"
        case .unknownCommand(let command):
            return "未知的指令：\(command)。輸入 help 查看可用指令。"
        case .missingArgument(let name):
            return "缺少參數：\(name)"
        case .invalidArgument(let name, let value):
            return "無效的參數 \(name)：\(value)"
        case .itemNotFound(let id):
            return "找不到物品：\(id)"
        case .insufficientGold(let required, let has):
            return "金幣不足！需要 \(required)，只有 \(has)"
        case .inventoryFull:
            return "背包已滿"
        case .cannotEquip(let reason):
            return "無法裝備：\(reason)"
        case .levelTooLow(let required, let has):
            return "等級不足！需要 \(required) 級，目前 \(has) 級"
        case .notInCombat:
            return "你不在戰鬥中"
        case .alreadyInCombat:
            return "你已經在戰鬥中了"
        case .targetNotFound(let name):
            return "找不到目標：\(name)"
        case .cannotAttackInSafeZone:
            return "這裡是安全區，無法進行戰鬥"
        case .skillOnCooldown(let skillId, let remaining):
            return "技能 \(skillId) 冷卻中，剩餘 \(String(format: "%.1f", remaining)) 秒"
        case .insufficientMP(let required, let has):
            return "MP 不足！需要 \(required)，只有 \(has)"
        case .stillCasting:
            return "正在施法中，請稍候"
        case .skillNotLearned(let skillId):
            return "你還沒學會技能：\(skillId)"
        case .prerequisiteNotMet(_, let required, let requiredLevel):
            return "需要先將 \(required) 升到 \(requiredLevel) 級"
        case .questNotFound(let id):
            return "找不到任務：\(id)"
        case .questAlreadyActive(let id):
            return "任務已在進行中：\(id)"
        case .questNotActive(let id):
            return "你沒有接這個任務：\(id)"
        case .questPrerequisiteNotMet(let required):
            return "需要先完成任務：\(required)"
        case .questObjectiveNotComplete:
            return "任務目標尚未完成"
        case .questOnCooldown(let remaining):
            return "任務冷卻中，剩餘 \(Int(remaining)) 秒"
        case .permissionDenied(let required):
            return "權限不足，需要 \(required) 或更高權限"
        case .targetHigherRank:
            return "無法對權限比你高的人執行此操作"
        case .cannotTargetSelf:
            return "無法對自己執行此操作"
        case .databaseError(let message):
            return "資料庫錯誤：\(message)"
        case .configurationError(let message):
            return "設定錯誤：\(message)"
        }
    }
}
```

**Step 3: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add comprehensive MUDError types with localized messages"
```

---

## Phase 2: SwiftNIO 網路層

### Task 9: 建立基礎 TCP 伺服器

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Server/MUDServer.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Server/` (directory)

**Step 1: 建立目錄**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD/Server`

**Step 2: 建立 MUDServer.swift**

```swift
import NIO
import NIOCore
import NIOPosix
import Logging

final class MUDServer {
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let logger: Logger

    let host: String
    let port: Int

    init(host: String, port: Int) {
        self.host = host
        self.port = port
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.logger = Logger(label: "com.swiftmud.server")
    }

    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandlers([
                    BackPressureHandler(),
                    LineBasedFrameDecoder(),
                    StringCodec(),
                    ClientHandler()
                ])
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)

        channel = try bootstrap.bind(host: host, port: port).wait()
        logger.info("SwiftMUD server started on \(host):\(port)")
    }

    func stop() {
        do {
            try channel?.close().wait()
            try group.syncShutdownGracefully()
            logger.info("SwiftMUD server stopped")
        } catch {
            logger.error("Error stopping server: \(error)")
        }
    }

    func waitForClose() throws {
        try channel?.closeFuture.wait()
    }
}

// 行分隔解碼器
final class LineBasedFrameDecoder: ByteToMessageDecoder {
    typealias InboundOut = ByteBuffer

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if let lineEnd = buffer.readableBytesView.firstIndex(of: UInt8(ascii: "\n")) {
            let length = lineEnd - buffer.readerIndex
            var line = buffer.readSlice(length: length + 1)!

            // 移除 \r\n 或 \n
            if line.readableBytes > 0 && line.getBytes(at: line.writerIndex - 1, length: 1)?[0] == UInt8(ascii: "\n") {
                line.moveWriterIndex(to: line.writerIndex - 1)
            }
            if line.readableBytes > 0 && line.getBytes(at: line.writerIndex - 1, length: 1)?[0] == UInt8(ascii: "\r") {
                line.moveWriterIndex(to: line.writerIndex - 1)
            }

            context.fireChannelRead(wrapInboundOut(line))
            return .continue
        }
        return .needMoreData
    }
}

// 字串編解碼器
final class StringCodec: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = String
    typealias OutboundIn = String
    typealias OutboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        if let string = buffer.readString(length: buffer.readableBytes) {
            context.fireChannelRead(wrapInboundOut(string))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let string = unwrapOutboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: string.utf8.count + 2)
        buffer.writeString(string)
        buffer.writeString("\r\n")
        context.write(wrapOutboundOut(buffer), promise: promise)
    }
}
```

**Step 3: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add SwiftNIO TCP server with line-based framing"
```

---

### Task 10: 建立 Client Handler

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Server/ClientHandler.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Server/Session.swift`

**Step 1: 建立 Session.swift**

```swift
import Foundation
import NIO

enum SessionState {
    case connected
    case authenticating
    case playing
    case disconnecting
}

final class Session {
    let id: UUID
    let channel: Channel
    var state: SessionState
    var playerId: UUID?
    var playerName: String?
    let connectedAt: Date

    init(channel: Channel) {
        self.id = UUID()
        self.channel = channel
        self.state = .connected
        self.connectedAt = Date()
    }

    func send(_ message: String) {
        _ = channel.writeAndFlush(message)
    }

    func sendLines(_ lines: [String]) {
        for line in lines {
            send(line)
        }
    }

    func close() {
        state = .disconnecting
        _ = channel.close()
    }
}
```

**Step 2: 建立 ClientHandler.swift**

```swift
import NIO
import NIOCore
import Logging

final class ClientHandler: ChannelInboundHandler {
    typealias InboundIn = String
    typealias OutboundOut = String

    private var session: Session?
    private var logger = Logger(label: "com.swiftmud.client")

    func channelActive(context: ChannelHandlerContext) {
        let session = Session(channel: context.channel)
        self.session = session

        let remoteAddress = context.remoteAddress?.description ?? "unknown"
        logger.info("New connection from \(remoteAddress), session: \(session.id)")

        // 發送歡迎訊息
        sendWelcome(context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = unwrapInboundIn(data).trimmingCharacters(in: .whitespaces)

        guard !input.isEmpty else { return }
        guard let session = session else { return }

        logger.debug("[\(session.id)] Received: \(input)")

        // 處理輸入
        handleInput(input, session: session, context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        guard let session = session else { return }
        logger.info("Connection closed, session: \(session.id)")

        // TODO: 清理玩家狀態、儲存資料
        self.session = nil
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Error: \(error)")
        context.close(promise: nil)
    }

    private func sendWelcome(context: ChannelHandlerContext) {
        let welcome = """

        ╔════════════════════════════════════════╗
        ║     歡迎來到 SwiftMUD 世界！           ║
        ║                                        ║
        ║  輸入 login <名稱> <密碼> 登入         ║
        ║  輸入 register <名稱> <密碼> 註冊      ║
        ║  輸入 quit 離開                        ║
        ╚════════════════════════════════════════╝

        """
        for line in welcome.split(separator: "\n") {
            _ = context.writeAndFlush(wrapOutboundOut(String(line)))
        }
    }

    private func handleInput(_ input: String, session: Session, context: ChannelHandlerContext) {
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        let command = parts[0].lowercased()
        let args = parts.count > 1 ? parts[1] : ""

        switch session.state {
        case .connected, .authenticating:
            handleAuthCommand(command: command, args: args, session: session, context: context)
        case .playing:
            handleGameCommand(command: command, args: args, session: session, context: context)
        case .disconnecting:
            break
        }
    }

    private func handleAuthCommand(command: String, args: String, session: Session, context: ChannelHandlerContext) {
        switch command {
        case "quit", "exit":
            session.send("再見！")
            session.close()

        case "login":
            // TODO: 實作登入邏輯
            session.send("登入功能尚未實作")

        case "register":
            // TODO: 實作註冊邏輯
            session.send("註冊功能尚未實作")

        default:
            session.send("請先登入或註冊。輸入 help 查看說明。")
        }
    }

    private func handleGameCommand(command: String, args: String, session: Session, context: ChannelHandlerContext) {
        // TODO: 實作遊戲指令
        session.send("遊戲指令尚未實作：\(command)")
    }
}
```

**Step 3: 更新 main.swift**

修改 `SwiftMUD/Sources/SwiftMUD/main.swift`，將 TODO 替換為實際的伺服器啟動：

```swift
import ArgumentParser
import Logging

@main
struct SwiftMUD: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftmud",
        abstract: "A Swift MUD game server"
    )

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 4000

    @Option(name: .shortAndLong, help: "Host to bind to")
    var host: String = "0.0.0.0"

    func run() throws {
        var logger = Logger(label: "com.swiftmud.main")
        logger.logLevel = .info

        let server = MUDServer(host: host, port: port)

        // 處理 SIGINT (Ctrl+C)
        signal(SIGINT) { _ in
            print("\nShutting down...")
            exit(0)
        }

        do {
            try server.start()
            try server.waitForClose()
        } catch {
            logger.error("Server error: \(error)")
            throw error
        }
    }
}
```

**Step 4: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 5: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add ClientHandler and Session for connection management"
```

---

## Phase 3: 世界狀態管理

### Task 11: 建立 World 狀態容器

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/World/World.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/World/` (directory)

**Step 1: 建立目錄**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD/World`

**Step 2: 建立 World.swift**

```swift
import Foundation

/// 遊戲世界的中央狀態容器，管理所有遊戲實體
final class World {
    // 單例模式
    static let shared = World()

    // 玩家狀態 (UUID -> Player)
    private(set) var players: [UUID: Player] = [:]

    // 房間狀態 (roomId -> Room)
    private(set) var rooms: [String: Room] = [:]

    // 怪物狀態 (UUID -> Monster)
    private(set) var monsters: [UUID: Monster] = [:]

    // 物品模板 (templateId -> ItemTemplate)
    private(set) var itemTemplates: [String: ItemTemplate] = [:]

    // 怪物模板 (templateId -> MonsterTemplate)
    private(set) var monsterTemplates: [String: MonsterTemplate] = [:]

    // 技能定義 (skillId -> Skill)
    private(set) var skills: [String: Skill] = [:]

    // 線程安全鎖
    private let lock = NSLock()

    private init() {
        loadInitialData()
    }

    // MARK: - Player Operations

    func addPlayer(_ player: Player) {
        lock.lock()
        defer { lock.unlock() }
        players[player.id] = player

        // 將玩家加入房間
        if var room = rooms[player.currentRoomId] {
            room.playerIds.insert(player.id.uuidString)
            rooms[player.currentRoomId] = room
        }
    }

    func removePlayer(_ playerId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let player = players[playerId] else { return }

        // 從房間移除玩家
        if var room = rooms[player.currentRoomId] {
            room.playerIds.remove(playerId.uuidString)
            rooms[player.currentRoomId] = room
        }

        players.removeValue(forKey: playerId)
    }

    func updatePlayer(_ player: Player) {
        lock.lock()
        defer { lock.unlock() }
        players[player.id] = player
    }

    func getPlayer(byId id: UUID) -> Player? {
        lock.lock()
        defer { lock.unlock() }
        return players[id]
    }

    func getPlayer(byName name: String) -> Player? {
        lock.lock()
        defer { lock.unlock() }
        return players.values.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Room Operations

    func getRoom(_ roomId: String) -> Room? {
        lock.lock()
        defer { lock.unlock() }
        return rooms[roomId]
    }

    func updateRoom(_ room: Room) {
        lock.lock()
        defer { lock.unlock() }
        rooms[room.id] = room
    }

    func movePlayer(_ playerId: UUID, from oldRoomId: String, to newRoomId: String) {
        lock.lock()
        defer { lock.unlock() }

        // 從舊房間移除
        if var oldRoom = rooms[oldRoomId] {
            oldRoom.playerIds.remove(playerId.uuidString)
            rooms[oldRoomId] = oldRoom
        }

        // 加入新房間
        if var newRoom = rooms[newRoomId] {
            newRoom.playerIds.insert(playerId.uuidString)
            rooms[newRoomId] = newRoom
        }

        // 更新玩家位置
        if var player = players[playerId] {
            player.currentRoomId = newRoomId
            players[playerId] = player
        }
    }

    func getPlayersInRoom(_ roomId: String) -> [Player] {
        lock.lock()
        defer { lock.unlock() }

        guard let room = rooms[roomId] else { return [] }
        return room.playerIds.compactMap { UUID(uuidString: $0) }.compactMap { players[$0] }
    }

    func getMonstersInRoom(_ roomId: String) -> [Monster] {
        lock.lock()
        defer { lock.unlock() }

        guard let room = rooms[roomId] else { return [] }
        return room.monsterIds.compactMap { UUID(uuidString: $0) }.compactMap { monsters[$0] }
    }

    // MARK: - Monster Operations

    func addMonster(_ monster: Monster) {
        lock.lock()
        defer { lock.unlock() }
        monsters[monster.id] = monster

        if var room = rooms[monster.currentRoomId] {
            room.monsterIds.insert(monster.id.uuidString)
            rooms[monster.currentRoomId] = room
        }
    }

    func getMonster(_ monsterId: UUID) -> Monster? {
        lock.lock()
        defer { lock.unlock() }
        return monsters[monsterId]
    }

    func updateMonster(_ monster: Monster) {
        lock.lock()
        defer { lock.unlock() }
        monsters[monster.id] = monster
    }

    func removeMonster(_ monsterId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let monster = monsters[monsterId] else { return }

        if var room = rooms[monster.currentRoomId] {
            room.monsterIds.remove(monsterId.uuidString)
            rooms[monster.currentRoomId] = room
        }

        monsters.removeValue(forKey: monsterId)
    }

    // MARK: - Initial Data Loading

    private func loadInitialData() {
        // 載入起始房間
        let townSquare = Room(
            id: "town_square",
            name: "城鎮廣場",
            description: "這是一個繁忙的城鎮廣場，四周圍繞著商店和民宅。中央有一座噴水池，旅人們在此休息聊天。",
            exits: [.north: "temple", .east: "market", .south: "south_gate", .west: "tavern"],
            isSafeZone: true,
            respawnPoint: true
        )

        let temple = Room(
            id: "temple",
            name: "神殿",
            description: "一座莊嚴的神殿，供奉著守護這片土地的神明。祭司們在此為旅人提供治療和祝福。",
            exits: [.south: "town_square"],
            isSafeZone: true
        )

        let market = Room(
            id: "market",
            name: "市場",
            description: "熱鬧的市場，攤販們叫賣著各種商品。空氣中瀰漫著香料和食物的氣味。",
            exits: [.west: "town_square", .east: "east_road"],
            isSafeZone: true
        )

        let tavern = Room(
            id: "tavern",
            name: "酒館",
            description: "「醉夢軒」酒館，冒險者們最愛的聚會場所。吧台後方的老闆正在擦拭酒杯。",
            exits: [.east: "town_square"],
            isSafeZone: true
        )

        let southGate = Room(
            id: "south_gate",
            name: "南門",
            description: "城鎮的南門，通往廣闘的平原。守衛在此巡邏，保護城鎮免受怪物侵襲。",
            exits: [.north: "town_square", .south: "plains"]
        )

        let plains = Room(
            id: "plains",
            name: "平原",
            description: "一望無際的草原，偶爾可見野生動物出沒。這裡是新手冒險者練功的好地方。",
            exits: [.north: "south_gate", .south: "forest_entrance"],
            canPvP: true
        )

        let forestEntrance = Room(
            id: "forest_entrance",
            name: "森林入口",
            description: "茂密森林的入口，樹木遮天蔽日。傳說森林深處住著強大的怪物。",
            exits: [.north: "plains", .south: "deep_forest"],
            canPvP: true
        )

        let eastRoad = Room(
            id: "east_road",
            name: "東方道路",
            description: "通往東方城鎮的道路，路旁偶有旅人經過。",
            exits: [.west: "market"]
        )

        let deepForest = Room(
            id: "deep_forest",
            name: "森林深處",
            description: "幽暗的森林深處，陽光幾乎無法穿透樹冠。四周傳來不明生物的低吼聲。",
            exits: [.north: "forest_entrance"],
            canPvP: true
        )

        rooms = [
            townSquare.id: townSquare,
            temple.id: temple,
            market.id: market,
            tavern.id: tavern,
            southGate.id: southGate,
            plains.id: plains,
            forestEntrance.id: forestEntrance,
            eastRoad.id: eastRoad,
            deepForest.id: deepForest
        ]

        // 載入怪物模板
        monsterTemplates = [
            "slime": MonsterTemplate(
                id: "slime",
                name: "史萊姆",
                description: "一團黏糊糊的生物",
                level: 1,
                maxHP: 30,
                attack: 5,
                defense: 2,
                magic: 0,
                expReward: 10,
                goldReward: 2...5,
                lootTable: [],
                aggressive: false,
                respawnTime: 30
            ),
            "wolf": MonsterTemplate(
                id: "wolf",
                name: "野狼",
                description: "一隻凶猛的野狼",
                level: 3,
                maxHP: 50,
                attack: 8,
                defense: 3,
                magic: 0,
                expReward: 30,
                goldReward: 5...15,
                lootTable: [
                    LootEntry(itemId: "wolf_pelt", chance: 0.5, countRange: 1...1),
                    LootEntry(itemId: "wolf_fang", chance: 0.2, countRange: 1...2)
                ],
                aggressive: true,
                respawnTime: 60
            ),
            "goblin": MonsterTemplate(
                id: "goblin",
                name: "哥布林",
                description: "一隻狡猾的哥布林",
                level: 5,
                maxHP: 80,
                attack: 12,
                defense: 5,
                magic: 3,
                expReward: 50,
                goldReward: 10...30,
                lootTable: [
                    LootEntry(itemId: "goblin_ear", chance: 0.3, countRange: 1...2)
                ],
                aggressive: true,
                respawnTime: 120
            )
        ]

        // 生成初始怪物
        spawnInitialMonsters()

        // 載入物品模板
        itemTemplates = [
            "health_potion": ItemTemplate(
                id: "health_potion",
                name: "治療藥水",
                description: "恢復 50 HP",
                type: .consumable,
                basePrice: 50,
                stackable: true,
                maxStack: 99
            ),
            "mana_potion": ItemTemplate(
                id: "mana_potion",
                name: "魔力藥水",
                description: "恢復 30 MP",
                type: .consumable,
                basePrice: 40,
                stackable: true,
                maxStack: 99
            ),
            "iron_sword": ItemTemplate(
                id: "iron_sword",
                name: "鐵劍",
                description: "一把普通的鐵劍",
                type: .weapon,
                equipSlot: .mainHand,
                statBonus: [.attack: 10],
                levelRequired: 1,
                basePrice: 100
            ),
            "leather_armor": ItemTemplate(
                id: "leather_armor",
                name: "皮甲",
                description: "基本的皮革護甲",
                type: .armor,
                equipSlot: .body,
                statBonus: [.defense: 5, .maxHP: 20],
                levelRequired: 1,
                basePrice: 150
            )
        ]

        // 載入技能
        skills = [
            "slash": Skill(
                id: "slash",
                name: "斬擊",
                description: "對敵人造成物理傷害",
                type: .active,
                mpCost: 10,
                cooldown: 3,
                effects: [.damage(base: 20, scaling: 1.2, stat: .attack)],
                maxLevel: 5
            ),
            "heal": Skill(
                id: "heal",
                name: "治療術",
                description: "恢復自身生命值",
                type: .active,
                mpCost: 15,
                cooldown: 5,
                effects: [.heal(base: 30, scaling: 1.0)],
                maxLevel: 5
            ),
            "fireball": Skill(
                id: "fireball",
                name: "火球術",
                description: "發射火球造成魔法傷害",
                type: .active,
                mpCost: 25,
                castTime: 1.5,
                cooldown: 8,
                effects: [.damage(base: 50, scaling: 1.5, stat: .magic)],
                maxLevel: 5
            ),
            "toughness": Skill(
                id: "toughness",
                name: "強壯體魄",
                description: "永久提升最大生命值",
                type: .passive,
                statBonus: [.maxHP: 20],
                maxLevel: 3
            )
        ]
    }

    private func spawnInitialMonsters() {
        // 在平原生成史萊姆
        if let template = monsterTemplates["slime"] {
            for _ in 0..<3 {
                let monster = Monster(from: template, roomId: "plains")
                addMonster(monster)
            }
        }

        // 在森林入口生成野狼
        if let template = monsterTemplates["wolf"] {
            for _ in 0..<2 {
                let monster = Monster(from: template, roomId: "forest_entrance")
                addMonster(monster)
            }
        }

        // 在森林深處生成哥布林
        if let template = monsterTemplates["goblin"] {
            for _ in 0..<2 {
                let monster = Monster(from: template, roomId: "deep_forest")
                addMonster(monster)
            }
        }
    }
}
```

**Step 3: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add World state container with initial game data"
```

---

### Task 12: 建立 SessionManager

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Server/SessionManager.swift`

**Step 1: 建立 SessionManager.swift**

```swift
import Foundation
import NIO
import Logging

/// 管理所有活動連線的 Session
final class SessionManager {
    static let shared = SessionManager()

    private var sessions: [UUID: Session] = [:]
    private var playerToSession: [UUID: UUID] = [:] // playerId -> sessionId
    private let lock = NSLock()
    private var logger = Logger(label: "com.swiftmud.session")

    private init() {}

    // MARK: - Session Management

    func register(_ session: Session) {
        lock.lock()
        defer { lock.unlock() }
        sessions[session.id] = session
        logger.info("Session registered: \(session.id)")
    }

    func unregister(_ sessionId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let session = sessions[sessionId] else { return }

        // 如果有關聯的玩家，清理玩家狀態
        if let playerId = session.playerId {
            playerToSession.removeValue(forKey: playerId)
            World.shared.removePlayer(playerId)
            logger.info("Player \(session.playerName ?? "unknown") logged out")
        }

        sessions.removeValue(forKey: sessionId)
        logger.info("Session unregistered: \(sessionId)")
    }

    func getSession(_ sessionId: UUID) -> Session? {
        lock.lock()
        defer { lock.unlock() }
        return sessions[sessionId]
    }

    func getSessionForPlayer(_ playerId: UUID) -> Session? {
        lock.lock()
        defer { lock.unlock() }

        guard let sessionId = playerToSession[playerId] else { return nil }
        return sessions[sessionId]
    }

    // MARK: - Player Login/Logout

    func loginPlayer(_ player: Player, session: Session) {
        lock.lock()
        defer { lock.unlock() }

        session.playerId = player.id
        session.playerName = player.name
        session.state = .playing
        playerToSession[player.id] = session.id

        World.shared.addPlayer(player)
        logger.info("Player \(player.name) logged in")
    }

    func isPlayerOnline(_ playerName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return sessions.values.contains { $0.playerName?.lowercased() == playerName.lowercased() }
    }

    // MARK: - Broadcasting

    func broadcast(_ message: String, inRoom roomId: String, except excludePlayerId: UUID? = nil) {
        lock.lock()
        let sessionsSnapshot = sessions
        lock.unlock()

        for session in sessionsSnapshot.values {
            guard session.state == .playing,
                  let playerId = session.playerId,
                  playerId != excludePlayerId,
                  let player = World.shared.getPlayer(byId: playerId),
                  player.currentRoomId == roomId else { continue }

            session.send(message)
        }
    }

    func broadcastGlobal(_ message: String, except excludePlayerId: UUID? = nil) {
        lock.lock()
        let sessionsSnapshot = sessions
        lock.unlock()

        for session in sessionsSnapshot.values {
            guard session.state == .playing,
                  let playerId = session.playerId,
                  playerId != excludePlayerId else { continue }

            session.send(message)
        }
    }

    func sendToPlayer(_ playerId: UUID, message: String) {
        guard let session = getSessionForPlayer(playerId) else { return }
        session.send(message)
    }

    // MARK: - Statistics

    var onlinePlayerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return playerToSession.count
    }

    var sessionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return sessions.count
    }
}
```

**Step 2: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add SessionManager for connection and player state management"
```

---

### Task 13: 整合 World 與 SessionManager 到 ClientHandler

**Files:**
- Modify: `SwiftMUD/Sources/SwiftMUD/Server/ClientHandler.swift`

**Step 1: 更新 ClientHandler.swift**

修改 `ClientHandler.swift`，整合 SessionManager：

```swift
import NIO
import NIOCore
import Logging
import Crypto

final class ClientHandler: ChannelInboundHandler {
    typealias InboundIn = String
    typealias OutboundOut = String

    private var session: Session?
    private var logger = Logger(label: "com.swiftmud.client")

    func channelActive(context: ChannelHandlerContext) {
        let session = Session(channel: context.channel)
        self.session = session
        SessionManager.shared.register(session)

        let remoteAddress = context.remoteAddress?.description ?? "unknown"
        logger.info("New connection from \(remoteAddress), session: \(session.id)")

        sendWelcome(context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = unwrapInboundIn(data).trimmingCharacters(in: .whitespaces)

        guard !input.isEmpty else { return }
        guard let session = session else { return }

        logger.debug("[\(session.id)] Received: \(input)")

        handleInput(input, session: session, context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        guard let session = session else { return }
        logger.info("Connection closed, session: \(session.id)")

        SessionManager.shared.unregister(session.id)
        self.session = nil
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Error: \(error)")
        context.close(promise: nil)
    }

    private func sendWelcome(context: ChannelHandlerContext) {
        let welcome = """

        ========================================
        |     歡迎來到 SwiftMUD 世界！         |
        |                                      |
        |  輸入: login <名稱> <密碼> 登入      |
        |  輸入: register <名稱> <密碼> 註冊   |
        |  輸入: quit 離開                     |
        ========================================

        """
        for line in welcome.split(separator: "\n") {
            _ = context.writeAndFlush(wrapOutboundOut(String(line)))
        }
    }

    private func handleInput(_ input: String, session: Session, context: ChannelHandlerContext) {
        let parts = input.split(separator: " ", maxSplits: 2).map(String.init)
        let command = parts[0].lowercased()
        let args = Array(parts.dropFirst())

        switch session.state {
        case .connected, .authenticating:
            handleAuthCommand(command: command, args: args, session: session, context: context)
        case .playing:
            handleGameCommand(command: command, args: args, session: session, context: context)
        case .disconnecting:
            break
        }
    }

    private func handleAuthCommand(command: String, args: [String], session: Session, context: ChannelHandlerContext) {
        switch command {
        case "quit", "exit":
            session.send("再見！")
            session.close()

        case "login":
            guard args.count >= 2 else {
                session.send("用法: login <名稱> <密碼>")
                return
            }
            let name = args[0]
            let password = args[1]
            handleLogin(name: name, password: password, session: session)

        case "register":
            guard args.count >= 2 else {
                session.send("用法: register <名稱> <密碼>")
                return
            }
            let name = args[0]
            let password = args[1]
            handleRegister(name: name, password: password, session: session)

        case "help":
            session.send("可用指令：login <名稱> <密碼>、register <名稱> <密碼>、quit")

        default:
            session.send("請先登入或註冊。輸入 help 查看說明。")
        }
    }

    private func handleLogin(name: String, password: String, session: Session) {
        // 檢查玩家是否已在線
        if SessionManager.shared.isPlayerOnline(name) {
            session.send("該玩家已經在線上！")
            return
        }

        // TODO: 從資料庫載入玩家
        // 暫時使用簡化版：檢查 World 是否有此玩家
        if let existingPlayer = World.shared.getPlayer(byName: name) {
            // 驗證密碼
            let inputHash = hashPassword(password)
            if existingPlayer.passwordHash == inputHash {
                SessionManager.shared.loginPlayer(existingPlayer, session: session)
                session.send("登入成功！歡迎回來，\(name)！")
                showRoom(session: session)
            } else {
                session.send("密碼錯誤！")
            }
        } else {
            session.send("找不到此玩家，請先註冊。")
        }
    }

    private func handleRegister(name: String, password: String, session: Session) {
        // 驗證名稱
        guard name.count >= 2 && name.count <= 16 else {
            session.send("名稱長度必須在 2-16 字元之間。")
            return
        }

        guard name.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            session.send("名稱只能包含字母和數字。")
            return
        }

        // 檢查名稱是否已存在
        if World.shared.getPlayer(byName: name) != nil {
            session.send("此名稱已被使用！")
            return
        }

        // 驗證密碼
        guard password.count >= 4 else {
            session.send("密碼長度至少需要 4 個字元。")
            return
        }

        // 建立新玩家
        let passwordHash = hashPassword(password)
        let player = Player.create(name: name, passwordHash: passwordHash)

        // 登入
        SessionManager.shared.loginPlayer(player, session: session)
        session.send("註冊成功！歡迎來到 SwiftMUD，\(name)！")
        showRoom(session: session)
    }

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func handleGameCommand(command: String, args: [String], session: Session, context: ChannelHandlerContext) {
        guard let playerId = session.playerId,
              let player = World.shared.getPlayer(byId: playerId) else {
            session.send("錯誤：找不到玩家資料")
            return
        }

        switch command {
        // 移動指令
        case "n", "north", "北":
            move(player: player, session: session, direction: .north)
        case "s", "south", "南":
            move(player: player, session: session, direction: .south)
        case "e", "east", "東":
            move(player: player, session: session, direction: .east)
        case "w", "west", "西":
            move(player: player, session: session, direction: .west)
        case "u", "up", "上":
            move(player: player, session: session, direction: .up)
        case "d", "down", "下":
            move(player: player, session: session, direction: .down)

        // 查看指令
        case "look", "l", "看":
            showRoom(session: session)

        case "status", "stat", "狀態":
            showStatus(player: player, session: session)

        case "who", "在線":
            showOnlinePlayers(session: session)

        case "say", "說":
            if args.isEmpty {
                session.send("說什麼？")
            } else {
                say(player: player, session: session, message: args.joined(separator: " "))
            }

        case "yell", "喊":
            if args.isEmpty {
                session.send("喊什麼？")
            } else {
                yell(player: player, session: session, message: args.joined(separator: " "))
            }

        case "quit", "exit", "離開":
            session.send("再見，\(player.name)！期待你的歸來！")
            session.close()

        case "help", "幫助", "?":
            showHelp(session: session)

        default:
            session.send("未知指令：\(command)。輸入 help 查看可用指令。")
        }
    }

    // MARK: - Game Actions

    private func move(player: Player, session: Session, direction: Direction) {
        guard let room = World.shared.getRoom(player.currentRoomId) else {
            session.send("錯誤：找不到目前房間")
            return
        }

        guard let destinationId = room.exits[direction] else {
            session.send("那個方向沒有出口。")
            return
        }

        guard World.shared.getRoom(destinationId) != nil else {
            session.send("錯誤：目的地房間不存在")
            return
        }

        // 通知原房間的其他玩家
        SessionManager.shared.broadcast(
            "\(player.name) 往\(direction.displayName)離開了。",
            inRoom: player.currentRoomId,
            except: player.id
        )

        // 移動玩家
        World.shared.movePlayer(player.id, from: player.currentRoomId, to: destinationId)

        // 通知新房間的其他玩家
        SessionManager.shared.broadcast(
            "\(player.name) 從\(direction.opposite.displayName)進來了。",
            inRoom: destinationId,
            except: player.id
        )

        // 顯示新房間
        showRoom(session: session)
    }

    private func showRoom(session: Session) {
        guard let playerId = session.playerId,
              let player = World.shared.getPlayer(byId: playerId),
              let room = World.shared.getRoom(player.currentRoomId) else {
            session.send("錯誤：找不到房間資料")
            return
        }

        // 取得房間內其他玩家和怪物
        let otherPlayers = World.shared.getPlayersInRoom(room.id)
            .filter { $0.id != playerId }
            .map { $0.name }

        let monsters = World.shared.getMonstersInRoom(room.id)
            .filter { $0.isAlive }
            .map { $0.name }

        let description = room.fullDescription(playerNames: otherPlayers, monsterNames: monsters)
        session.send(description)
    }

    private func showStatus(player: Player, session: Session) {
        let status = """
        ===== \(player.name) 的狀態 =====
        等級: \(player.level)  經驗: \(player.exp)/\(player.expToNextLevel())
        HP: \(player.currentHP)/\(player.maxHP)  MP: \(player.currentMP)/\(player.maxMP)
        攻擊: \(player.baseAttack)  防禦: \(player.baseDefense)  魔力: \(player.baseMagic)
        金幣: \(player.gold)
        =========================
        """
        session.sendLines(status.split(separator: "\n").map(String.init))
    }

    private func showOnlinePlayers(session: Session) {
        let count = SessionManager.shared.onlinePlayerCount
        session.send("目前在線玩家數：\(count)")
    }

    private func say(player: Player, session: Session, message: String) {
        session.send("你說：「\(message)」")
        SessionManager.shared.broadcast(
            "\(player.name) 說：「\(message)」",
            inRoom: player.currentRoomId,
            except: player.id
        )
    }

    private func yell(player: Player, session: Session, message: String) {
        session.send("你大喊：「\(message)」")
        SessionManager.shared.broadcastGlobal(
            "\(player.name) 大喊：「\(message)」",
            except: player.id
        )
    }

    private func showHelp(session: Session) {
        let help = """
        ===== 可用指令 =====
        移動: n/s/e/w/u/d 或 north/south/east/west/up/down
        look (l): 查看房間
        status (stat): 查看狀態
        who: 查看在線玩家
        say <訊息>: 對房間內說話
        yell <訊息>: 對全服喊話
        quit: 離開遊戲
        help: 顯示此說明
        ===================
        """
        session.sendLines(help.split(separator: "\n").map(String.init))
    }
}
```

**Step 2: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 3: 手動測試（可選）**

Run: `cd SwiftMUD && swift run SwiftMUD --port 4000 &`
Then: `nc localhost 4000`
Test: register TestPlayer 1234, then walk around

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: integrate World and SessionManager with basic game commands"
```

---

## Phase 4: 指令解析系統

### Task 14: 建立 Command Protocol 與 CommandParser

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/Command.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/CommandParser.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/` (directory)

**Step 1: 建立目錄**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD/Commands`

**Step 2: 建立 Command.swift**

```swift
import Foundation

/// 指令執行結果
enum CommandResult {
    case success(message: String?)
    case failure(error: MUDError)
    case quit
}

/// 指令的執行上下文
struct CommandContext {
    let session: Session
    let playerId: UUID
    var player: Player
    let args: [String]
    let rawInput: String
}

/// 所有遊戲指令必須實作此協定
protocol Command {
    /// 指令名稱（主要名稱）
    static var name: String { get }

    /// 別名
    static var aliases: [String] { get }

    /// 說明
    static var description: String { get }

    /// 用法
    static var usage: String { get }

    /// 執行所需的最低管理權限
    static var requiredAdminLevel: AdminTier { get }

    /// 執行指令
    func execute(context: CommandContext) -> CommandResult
}

extension Command {
    static var aliases: [String] { [] }
    static var requiredAdminLevel: AdminTier { .player }
}
```

**Step 3: 建立 CommandParser.swift**

```swift
import Foundation

/// 指令解析器，負責解析和分派指令
final class CommandParser {
    static let shared = CommandParser()

    private var commands: [String: Command.Type] = [:]
    private var commandInstances: [String: Command] = [:]

    private init() {
        registerBuiltInCommands()
    }

    private func registerBuiltInCommands() {
        // 移動指令
        register(MoveCommand.self)

        // 查看指令
        register(LookCommand.self)
        register(StatusCommand.self)
        register(WhoCommand.self)

        // 通訊指令
        register(SayCommand.self)
        register(YellCommand.self)

        // 系統指令
        register(HelpCommand.self)
        register(QuitCommand.self)

        // 戰鬥指令（Phase 5）
        // register(AttackCommand.self)
        // register(FleeCommand.self)
        // register(UseSkillCommand.self)
    }

    func register(_ commandType: Command.Type) {
        let instance = commandType.init()
        let name = commandType.name.lowercased()

        commands[name] = commandType
        commandInstances[name] = instance

        // 註冊別名
        for alias in commandType.aliases {
            let lowerAlias = alias.lowercased()
            commands[lowerAlias] = commandType
            commandInstances[lowerAlias] = instance
        }
    }

    func parse(_ input: String, session: Session) -> CommandResult {
        guard let playerId = session.playerId,
              let player = World.shared.getPlayer(byId: playerId) else {
            return .failure(error: .notLoggedIn)
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .success(message: nil)
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        let commandName = parts[0].lowercased()
        let argsString = parts.count > 1 ? parts[1] : ""
        let args = argsString.isEmpty ? [] : argsString.split(separator: " ").map(String.init)

        // 檢查是否為方向快捷鍵
        if let direction = parseDirection(commandName) {
            let context = CommandContext(
                session: session,
                playerId: playerId,
                player: player,
                args: [direction.rawValue],
                rawInput: trimmed
            )
            return MoveCommand().execute(context: context)
        }

        guard let command = commandInstances[commandName] else {
            return .failure(error: .unknownCommand(command: commandName))
        }

        // 檢查權限
        let commandType = commands[commandName]!
        if player.adminLevel < commandType.requiredAdminLevel {
            return .failure(error: .permissionDenied(required: commandType.requiredAdminLevel))
        }

        let context = CommandContext(
            session: session,
            playerId: playerId,
            player: player,
            args: args,
            rawInput: trimmed
        )

        return command.execute(context: context)
    }

    private func parseDirection(_ input: String) -> Direction? {
        switch input {
        case "n", "north", "北": return .north
        case "s", "south", "南": return .south
        case "e", "east", "東": return .east
        case "w", "west", "西": return .west
        case "u", "up", "上": return .up
        case "d", "down", "下": return .down
        default: return nil
        }
    }

    func getAllCommands() -> [(name: String, description: String, usage: String)] {
        var result: [(String, String, String)] = []
        var seen = Set<String>()

        for (_, commandType) in commands {
            let name = commandType.name
            if !seen.contains(name) {
                seen.insert(name)
                result.append((name, commandType.description, commandType.usage))
            }
        }

        return result.sorted { $0.0 < $1.0 }
    }
}
```

**Step 4: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add Command protocol and CommandParser"
```

---

### Task 15: 實作基本指令類別

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/MoveCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/LookCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/StatusCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/WhoCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/SayCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/YellCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/HelpCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/QuitCommand.swift`

**Step 1: 建立 MoveCommand.swift**

```swift
import Foundation

final class MoveCommand: Command {
    static let name = "move"
    static let aliases = ["go", "走"]
    static let description = "移動到指定方向"
    static let usage = "move <方向> 或直接輸入方向 (n/s/e/w/u/d)"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard let directionStr = context.args.first else {
            return .failure(error: .missingArgument(name: "方向"))
        }

        guard let direction = parseDirection(directionStr) else {
            return .failure(error: .invalidDirection(direction: directionStr))
        }

        guard let room = World.shared.getRoom(context.player.currentRoomId) else {
            return .failure(error: .roomNotFound(id: context.player.currentRoomId))
        }

        guard let destinationId = room.exits[direction] else {
            return .failure(error: .noExitInDirection(direction: direction))
        }

        guard World.shared.getRoom(destinationId) != nil else {
            return .failure(error: .roomNotFound(id: destinationId))
        }

        let player = context.player

        // 通知原房間
        SessionManager.shared.broadcast(
            "\(player.name) 往\(direction.displayName)離開了。",
            inRoom: player.currentRoomId,
            except: player.id
        )

        // 移動
        World.shared.movePlayer(player.id, from: player.currentRoomId, to: destinationId)

        // 通知新房間
        SessionManager.shared.broadcast(
            "\(player.name) 從\(direction.opposite.displayName)進來了。",
            inRoom: destinationId,
            except: player.id
        )

        // 顯示新房間
        showRoom(context: context, roomId: destinationId)

        return .success(message: nil)
    }

    private func parseDirection(_ input: String) -> Direction? {
        switch input.lowercased() {
        case "n", "north", "北": return .north
        case "s", "south", "南": return .south
        case "e", "east", "東": return .east
        case "w", "west", "西": return .west
        case "u", "up", "上": return .up
        case "d", "down", "下": return .down
        default: return nil
        }
    }

    private func showRoom(context: CommandContext, roomId: String) {
        guard let player = World.shared.getPlayer(byId: context.playerId),
              let room = World.shared.getRoom(roomId) else { return }

        let otherPlayers = World.shared.getPlayersInRoom(roomId)
            .filter { $0.id != context.playerId }
            .map { $0.name }

        let monsters = World.shared.getMonstersInRoom(roomId)
            .filter { $0.isAlive }
            .map { $0.name }

        let description = room.fullDescription(playerNames: otherPlayers, monsterNames: monsters)
        context.session.send(description)
    }
}
```

**Step 2: 建立 LookCommand.swift**

```swift
import Foundation

final class LookCommand: Command {
    static let name = "look"
    static let aliases = ["l", "看"]
    static let description = "查看目前房間"
    static let usage = "look"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard let room = World.shared.getRoom(context.player.currentRoomId) else {
            return .failure(error: .roomNotFound(id: context.player.currentRoomId))
        }

        let otherPlayers = World.shared.getPlayersInRoom(room.id)
            .filter { $0.id != context.playerId }
            .map { $0.name }

        let monsters = World.shared.getMonstersInRoom(room.id)
            .filter { $0.isAlive }
            .map { $0.name }

        let description = room.fullDescription(playerNames: otherPlayers, monsterNames: monsters)
        context.session.send(description)

        return .success(message: nil)
    }
}
```

**Step 3: 建立 StatusCommand.swift**

```swift
import Foundation

final class StatusCommand: Command {
    static let name = "status"
    static let aliases = ["stat", "狀態", "st"]
    static let description = "查看自己的狀態"
    static let usage = "status"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player
        let lines = [
            "===== \(player.name) 的狀態 =====",
            "等級: \(player.level)  經驗: \(player.exp)/\(player.expToNextLevel())",
            "HP: \(player.currentHP)/\(player.maxHP)  MP: \(player.currentMP)/\(player.maxMP)",
            "攻擊: \(player.baseAttack)  防禦: \(player.baseDefense)  魔力: \(player.baseMagic)",
            "金幣: \(player.gold)",
            "========================="
        ]
        context.session.sendLines(lines)
        return .success(message: nil)
    }
}
```

**Step 4: 建立 WhoCommand.swift**

```swift
import Foundation

final class WhoCommand: Command {
    static let name = "who"
    static let aliases = ["在線", "online"]
    static let description = "查看在線玩家"
    static let usage = "who"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let count = SessionManager.shared.onlinePlayerCount
        context.session.send("目前在線玩家數：\(count)")
        return .success(message: nil)
    }
}
```

**Step 5: 建立 SayCommand.swift**

```swift
import Foundation

final class SayCommand: Command {
    static let name = "say"
    static let aliases = ["說", "'"]
    static let description = "對房間內的人說話"
    static let usage = "say <訊息>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "訊息"))
        }

        let message = context.args.joined(separator: " ")
        let player = context.player

        context.session.send("你說：「\(message)」")

        SessionManager.shared.broadcast(
            "\(player.name) 說：「\(message)」",
            inRoom: player.currentRoomId,
            except: player.id
        )

        return .success(message: nil)
    }
}
```

**Step 6: 建立 YellCommand.swift**

```swift
import Foundation

final class YellCommand: Command {
    static let name = "yell"
    static let aliases = ["喊", "shout"]
    static let description = "對全服喊話"
    static let usage = "yell <訊息>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "訊息"))
        }

        let message = context.args.joined(separator: " ")
        let player = context.player

        context.session.send("你大喊：「\(message)」")

        SessionManager.shared.broadcastGlobal(
            "\(player.name) 大喊：「\(message)」",
            except: player.id
        )

        return .success(message: nil)
    }
}
```

**Step 7: 建立 HelpCommand.swift**

```swift
import Foundation

final class HelpCommand: Command {
    static let name = "help"
    static let aliases = ["幫助", "?", "h"]
    static let description = "顯示幫助訊息"
    static let usage = "help [指令名稱]"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        if context.args.isEmpty {
            showGeneralHelp(context: context)
        } else {
            showCommandHelp(context: context, commandName: context.args[0])
        }
        return .success(message: nil)
    }

    private func showGeneralHelp(context: CommandContext) {
        var lines = ["===== 可用指令 ====="]

        let commands = CommandParser.shared.getAllCommands()
        for (name, description, _) in commands {
            lines.append("  \(name): \(description)")
        }

        lines.append("")
        lines.append("移動快捷鍵: n/s/e/w/u/d")
        lines.append("輸入 help <指令> 查看詳細用法")
        lines.append("===================")

        context.session.sendLines(lines)
    }

    private func showCommandHelp(context: CommandContext, commandName: String) {
        let commands = CommandParser.shared.getAllCommands()
        if let cmd = commands.first(where: { $0.name.lowercased() == commandName.lowercased() }) {
            context.session.sendLines([
                "指令: \(cmd.name)",
                "說明: \(cmd.description)",
                "用法: \(cmd.usage)"
            ])
        } else {
            context.session.send("找不到指令：\(commandName)")
        }
    }
}
```

**Step 8: 建立 QuitCommand.swift**

```swift
import Foundation

final class QuitCommand: Command {
    static let name = "quit"
    static let aliases = ["exit", "離開", "bye"]
    static let description = "離開遊戲"
    static let usage = "quit"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        context.session.send("再見，\(context.player.name)！期待你的歸來！")
        return .quit
    }
}
```

**Step 9: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 10: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: implement basic game commands (move, look, status, say, etc.)"
```

---

### Task 16: 重構 ClientHandler 使用 CommandParser

**Files:**
- Modify: `SwiftMUD/Sources/SwiftMUD/Server/ClientHandler.swift`

**Step 1: 簡化 ClientHandler，使用 CommandParser**

修改 `handleGameCommand` 方法：

```swift
private func handleGameCommand(command: String, args: [String], session: Session, context: ChannelHandlerContext) {
    let fullInput = ([command] + args).joined(separator: " ")
    let result = CommandParser.shared.parse(fullInput, session: session)

    switch result {
    case .success(let message):
        if let msg = message {
            session.send(msg)
        }
    case .failure(let error):
        session.send(error.localizedDescription)
    case .quit:
        session.close()
    }
}
```

**Step 2: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add SwiftMUD/
git commit -m "refactor: use CommandParser in ClientHandler for game commands"
```

---

## Phase 5: 戰鬥系統

### Task 17: 建立 CombatState 與 CombatManager

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Combat/CombatState.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Combat/CombatManager.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Combat/` (directory)

**Step 1: 建立目錄**

Run: `mkdir -p SwiftMUD/Sources/SwiftMUD/Combat`

**Step 2: 建立 CombatState.swift**

```swift
import Foundation

/// 戰鬥參與者類型
enum CombatantType {
    case player(UUID)
    case monster(UUID)
}

/// 單場戰鬥的狀態
struct CombatState {
    let id: UUID
    let roomId: String
    var participants: [CombatantType]
    var turnOrder: [CombatantType]
    var currentTurnIndex: Int
    let startedAt: Date

    var isActive: Bool {
        participants.count >= 2
    }

    init(roomId: String) {
        self.id = UUID()
        self.roomId = roomId
        self.participants = []
        self.turnOrder = []
        self.currentTurnIndex = 0
        self.startedAt = Date()
    }

    mutating func addParticipant(_ participant: CombatantType) {
        if !participants.contains(where: { $0.id == participant.id }) {
            participants.append(participant)
            recalculateTurnOrder()
        }
    }

    mutating func removeParticipant(_ participantId: UUID) {
        participants.removeAll { $0.id == participantId }
        turnOrder.removeAll { $0.id == participantId }
        if currentTurnIndex >= turnOrder.count {
            currentTurnIndex = 0
        }
    }

    mutating func nextTurn() {
        guard !turnOrder.isEmpty else { return }
        currentTurnIndex = (currentTurnIndex + 1) % turnOrder.count
    }

    var currentCombatant: CombatantType? {
        guard currentTurnIndex < turnOrder.count else { return nil }
        return turnOrder[currentTurnIndex]
    }

    private mutating func recalculateTurnOrder() {
        // 簡單的回合順序：按照加入順序
        // 未來可以根據速度屬性排序
        turnOrder = participants
    }
}

extension CombatantType {
    var id: UUID {
        switch self {
        case .player(let id): return id
        case .monster(let id): return id
        }
    }
}

extension CombatantType: Equatable {}
```

**Step 3: 建立 CombatManager.swift**

```swift
import Foundation
import Logging

/// 戰鬥管理器
final class CombatManager {
    static let shared = CombatManager()

    private var activeCombats: [UUID: CombatState] = [:] // combatId -> CombatState
    private var participantToCombat: [UUID: UUID] = [:] // participantId -> combatId
    private let lock = NSLock()
    private var logger = Logger(label: "com.swiftmud.combat")

    private init() {}

    // MARK: - Combat Lifecycle

    func startCombat(playerId: UUID, targetId: UUID, targetType: CombatantType, roomId: String) -> Result<CombatState, MUDError> {
        lock.lock()
        defer { lock.unlock() }

        // 檢查是否已在戰鬥中
        if participantToCombat[playerId] != nil {
            return .failure(.alreadyInCombat)
        }

        // 檢查目標是否已在戰鬥中
        if participantToCombat[targetId] != nil {
            // 加入現有戰鬥
            if let combatId = participantToCombat[targetId],
               var combat = activeCombats[combatId] {
                combat.addParticipant(.player(playerId))
                activeCombats[combatId] = combat
                participantToCombat[playerId] = combatId
                return .success(combat)
            }
        }

        // 建立新戰鬥
        var combat = CombatState(roomId: roomId)
        combat.addParticipant(.player(playerId))
        combat.addParticipant(targetType)

        activeCombats[combat.id] = combat
        participantToCombat[playerId] = combat.id
        participantToCombat[targetId] = combat.id

        logger.info("Combat started: \(combat.id)")
        return .success(combat)
    }

    func endCombat(_ combatId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let combat = activeCombats[combatId] else { return }

        for participant in combat.participants {
            participantToCombat.removeValue(forKey: participant.id)
        }

        activeCombats.removeValue(forKey: combatId)
        logger.info("Combat ended: \(combatId)")
    }

    func getCombat(forParticipant participantId: UUID) -> CombatState? {
        lock.lock()
        defer { lock.unlock() }

        guard let combatId = participantToCombat[participantId] else { return nil }
        return activeCombats[combatId]
    }

    func isInCombat(_ participantId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return participantToCombat[participantId] != nil
    }

    func leaveCombat(_ participantId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let combatId = participantToCombat[participantId],
              var combat = activeCombats[combatId] else { return }

        combat.removeParticipant(participantId)
        participantToCombat.removeValue(forKey: participantId)

        if combat.participants.count < 2 {
            // 戰鬥結束
            for participant in combat.participants {
                participantToCombat.removeValue(forKey: participant.id)
            }
            activeCombats.removeValue(forKey: combatId)
            logger.info("Combat ended (not enough participants): \(combatId)")
        } else {
            activeCombats[combatId] = combat
        }
    }

    // MARK: - Damage Calculation

    func calculateDamage(attacker: CombatStats, defender: CombatStats, skill: Skill? = nil) -> Int {
        let baseDamage: Int
        let attackStat: Int

        if let skill = skill {
            // 技能傷害
            guard let damageEffect = skill.effects.first(where: {
                if case .damage = $0 { return true }
                return false
            }),
            case .damage(let base, let scaling, let stat) = damageEffect else {
                return 0
            }

            attackStat = stat == .magic ? attacker.magic : attacker.attack
            baseDamage = base + Int(Double(attackStat) * scaling)
        } else {
            // 普通攻擊
            attackStat = attacker.attack
            baseDamage = attackStat
        }

        // 計算防禦減傷
        let defenseReduction = Double(defender.defense) / Double(defender.defense + 50)
        let finalDamage = Int(Double(baseDamage) * (1 - defenseReduction))

        // 最小傷害為 1
        return max(1, finalDamage)
    }

    /// 處理攻擊動作
    func processAttack(attackerId: UUID, attackerType: CombatantType, skill: Skill? = nil) -> AttackResult {
        lock.lock()
        defer { lock.unlock() }

        guard let combatId = participantToCombat[attackerId],
              let combat = activeCombats[combatId] else {
            return AttackResult(success: false, damage: 0, message: "你不在戰鬥中", targetDied: false)
        }

        // 找到對手
        guard let targetType = combat.participants.first(where: { $0.id != attackerId }) else {
            return AttackResult(success: false, damage: 0, message: "找不到攻擊目標", targetDied: false)
        }

        let attackerStats: CombatStats
        let defenderStats: CombatStats
        let attackerName: String
        let targetName: String

        // 取得攻擊者資料
        switch attackerType {
        case .player(let id):
            guard let player = World.shared.getPlayer(byId: id) else {
                return AttackResult(success: false, damage: 0, message: "找不到攻擊者資料", targetDied: false)
            }
            attackerStats = CombatStats(from: player)
            attackerName = player.name
        case .monster(let id):
            guard let monster = World.shared.getMonster(id) else {
                return AttackResult(success: false, damage: 0, message: "找不到攻擊者資料", targetDied: false)
            }
            attackerStats = CombatStats(from: monster)
            attackerName = monster.name
        }

        // 取得防禦者資料
        switch targetType {
        case .player(let id):
            guard let player = World.shared.getPlayer(byId: id) else {
                return AttackResult(success: false, damage: 0, message: "找不到目標資料", targetDied: false)
            }
            defenderStats = CombatStats(from: player)
            targetName = player.name
        case .monster(let id):
            guard let monster = World.shared.getMonster(id) else {
                return AttackResult(success: false, damage: 0, message: "找不到目標資料", targetDied: false)
            }
            defenderStats = CombatStats(from: monster)
            targetName = monster.name
        }

        // 計算傷害
        let damage = calculateDamage(attacker: attackerStats, defender: defenderStats, skill: skill)

        // 套用傷害
        var targetDied = false
        switch targetType {
        case .player(let id):
            if var player = World.shared.getPlayer(byId: id) {
                player.takeDamage(damage)
                World.shared.updatePlayer(player)
                targetDied = !player.isAlive
            }
        case .monster(let id):
            if var monster = World.shared.getMonster(id) {
                monster.takeDamage(damage)
                World.shared.updateMonster(monster)
                targetDied = !monster.isAlive
            }
        }

        let skillName = skill?.name ?? "普通攻擊"
        let message = "\(attackerName) 對 \(targetName) 使用 \(skillName)，造成 \(damage) 點傷害！"

        return AttackResult(success: true, damage: damage, message: message, targetDied: targetDied, targetType: targetType)
    }
}

/// 戰鬥統計數據
struct CombatStats {
    let attack: Int
    let defense: Int
    let magic: Int
    let speed: Int

    init(from player: Player) {
        self.attack = player.baseAttack
        self.defense = player.baseDefense
        self.magic = player.baseMagic
        self.speed = 10 // 預設速度
    }

    init(from monster: Monster) {
        self.attack = monster.attack
        self.defense = monster.defense
        self.magic = monster.magic
        self.speed = 10
    }
}

/// 攻擊結果
struct AttackResult {
    let success: Bool
    let damage: Int
    let message: String
    let targetDied: Bool
    var targetType: CombatantType?
}
```

**Step 4: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 5: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add CombatState and CombatManager for battle system"
```

---

### Task 18: 實作戰鬥指令

**Files:**
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/AttackCommand.swift`
- Create: `SwiftMUD/Sources/SwiftMUD/Commands/FleeCommand.swift`
- Modify: `SwiftMUD/Sources/SwiftMUD/Commands/CommandParser.swift` (註冊新指令)

**Step 1: 建立 AttackCommand.swift**

```swift
import Foundation

final class AttackCommand: Command {
    static let name = "attack"
    static let aliases = ["kill", "hit", "攻擊", "打"]
    static let description = "攻擊目標"
    static let usage = "attack <目標名稱>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "目標"))
        }

        let targetName = context.args[0].lowercased()
        let player = context.player

        // 檢查是否在安全區
        if let room = World.shared.getRoom(player.currentRoomId), room.isSafeZone {
            return .failure(error: .cannotAttackInSafeZone)
        }

        // 檢查是否已在戰鬥中
        if CombatManager.shared.isInCombat(player.id) {
            // 繼續攻擊
            let result = CombatManager.shared.processAttack(
                attackerId: player.id,
                attackerType: .player(player.id)
            )
            context.session.send(result.message)

            if result.targetDied {
                handleTargetDeath(context: context, targetType: result.targetType)
            }

            return .success(message: nil)
        }

        // 尋找目標（先找怪物，再找玩家）
        let monstersInRoom = World.shared.getMonstersInRoom(player.currentRoomId)
        if let targetMonster = monstersInRoom.first(where: {
            $0.name.lowercased().contains(targetName) && $0.isAlive
        }) {
            return startCombatWithMonster(context: context, monster: targetMonster)
        }

        // 找不到目標
        return .failure(error: .targetNotFound(name: targetName))
    }

    private func startCombatWithMonster(context: CommandContext, monster: Monster) -> CommandResult {
        let player = context.player

        let result = CombatManager.shared.startCombat(
            playerId: player.id,
            targetId: monster.id,
            targetType: .monster(monster.id),
            roomId: player.currentRoomId
        )

        switch result {
        case .success:
            context.session.send("你開始攻擊 \(monster.name)！")

            // 廣播給房間其他人
            SessionManager.shared.broadcast(
                "\(player.name) 開始攻擊 \(monster.name)！",
                inRoom: player.currentRoomId,
                except: player.id
            )

            // 執行第一次攻擊
            let attackResult = CombatManager.shared.processAttack(
                attackerId: player.id,
                attackerType: .player(player.id)
            )
            context.session.send(attackResult.message)

            if attackResult.targetDied {
                handleTargetDeath(context: context, targetType: attackResult.targetType)
            }

            return .success(message: nil)

        case .failure(let error):
            return .failure(error: error)
        }
    }

    private func handleTargetDeath(context: CommandContext, targetType: CombatantType?) {
        guard let targetType = targetType else { return }

        switch targetType {
        case .monster(let monsterId):
            guard let monster = World.shared.getMonster(monsterId),
                  let template = World.shared.monsterTemplates[monster.templateId] else { return }

            let expGained = template.expReward
            let goldGained = Int.random(in: template.goldReward)

            context.session.send("\(monster.name) 被擊敗了！")
            context.session.send("獲得 \(expGained) 經驗值和 \(goldGained) 金幣！")

            // 更新玩家
            if var player = World.shared.getPlayer(byId: context.playerId) {
                let leveledUp = player.gainExp(expGained)
                player.gold += goldGained
                World.shared.updatePlayer(player)

                if leveledUp {
                    context.session.send("恭喜！你升級了！目前等級：\(player.level)")
                }
            }

            // 結束戰鬥
            CombatManager.shared.leaveCombat(context.playerId)

            // 廣播
            SessionManager.shared.broadcast(
                "\(context.player.name) 擊敗了 \(monster.name)！",
                inRoom: context.player.currentRoomId,
                except: context.playerId
            )

        case .player(let playerId):
            // PvP 處理（未來實作）
            CombatManager.shared.leaveCombat(context.playerId)
            CombatManager.shared.leaveCombat(playerId)
        }
    }
}
```

**Step 2: 建立 FleeCommand.swift**

```swift
import Foundation

final class FleeCommand: Command {
    static let name = "flee"
    static let aliases = ["run", "escape", "逃跑", "逃"]
    static let description = "逃離戰鬥"
    static let usage = "flee"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player

        guard CombatManager.shared.isInCombat(player.id) else {
            return .failure(error: .notInCombat)
        }

        // 30% 機率逃跑失敗
        let escaped = Int.random(in: 1...100) > 30

        if escaped {
            CombatManager.shared.leaveCombat(player.id)

            // 隨機選擇一個出口逃跑
            if let room = World.shared.getRoom(player.currentRoomId),
               let (direction, destinationId) = room.exits.randomElement() {

                World.shared.movePlayer(player.id, from: player.currentRoomId, to: destinationId)

                context.session.send("你成功逃跑了！往\(direction.displayName)方向逃離。")

                SessionManager.shared.broadcast(
                    "\(player.name) 逃跑了！",
                    inRoom: player.currentRoomId,
                    except: player.id
                )

                // 顯示新房間
                if let newRoom = World.shared.getRoom(destinationId) {
                    let otherPlayers = World.shared.getPlayersInRoom(destinationId)
                        .filter { $0.id != player.id }
                        .map { $0.name }
                    let monsters = World.shared.getMonstersInRoom(destinationId)
                        .filter { $0.isAlive }
                        .map { $0.name }
                    context.session.send(newRoom.fullDescription(playerNames: otherPlayers, monsterNames: monsters))
                }
            } else {
                context.session.send("你成功逃跑了！")
            }

            return .success(message: nil)
        } else {
            context.session.send("逃跑失敗！")
            return .success(message: nil)
        }
    }
}
```

**Step 3: 更新 CommandParser 註冊戰鬥指令**

在 `registerBuiltInCommands()` 中加入：

```swift
// 戰鬥指令
register(AttackCommand.self)
register(FleeCommand.self)
```

**Step 4: 驗證編譯**

Run: `cd SwiftMUD && swift build`
Expected: Build succeeded

**Step 5: Commit**

```bash
git add SwiftMUD/
git commit -m "feat: add AttackCommand and FleeCommand for combat"
```

---

## Phase 6-10 預覽

後續 phases 將包含：

### Phase 6: 任務系統
- Task 19: Quest 資料模型
- Task 20: QuestManager
- Task 21: 任務指令 (quest, accept, complete)

### Phase 7: 商店與交易
- Task 22: Shop 資料模型
- Task 23: 購買/販賣指令
- Task 24: Inventory 指令 (inventory, use, equip)

### Phase 8: 管理者系統
- Task 25: 管理指令 (kick, ban, mute, teleport, spawn)
- Task 26: 權限檢查

### Phase 9: 資料持久化
- Task 27: Repository Protocol
- Task 28: JSON File Repository
- Task 29: 玩家資料儲存/載入

### Phase 10: 整合與部署
- Task 30: 整合測試
- Task 31: 效能優化
- Task 32: 部署腳本

---

## 驗證指令

**編譯專案：**
```bash
cd SwiftMUD && swift build
```

**執行測試：**
```bash
cd SwiftMUD && swift test
```

**啟動伺服器：**
```bash
cd SwiftMUD && swift run SwiftMUD --port 4000
```

**測試連線：**
```bash
telnet localhost 4000
```
