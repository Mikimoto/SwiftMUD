# Swift MUD 遊戲實作計畫

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 使用 Swift 和 SwiftNIO 實作跨平台 MUD 伺服器，包含即時戰鬥、技能樹、任務、商店與管理系統。

**Architecture:** 採用模組化架構，Network 層處理連線，Game 層管理世界狀態，Combat 層處理即時戰鬥，Systems 層包含任務/商店/交易/管理功能，Data 層抽象資料庫操作。

**Tech Stack:** Swift 5.9+, SwiftNIO, PostgresNIO/MySQLNIO, swift-crypto

---

## Phase 1: 專案基礎建設

### Task 1: 建立 Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/SwiftMUD/main.swift`

**Step 1: 建立 Package.swift**

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
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.20.0"),
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftMUD",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftMUDTests",
            dependencies: ["SwiftMUD"]
        ),
    ]
)
```

**Step 2: 建立 main.swift 進入點**

```swift
import NIO
import ArgumentParser

@main
struct SwiftMUD: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Swift MUD Game Server"
    )

    @Option(name: .shortAndLong, help: "Server port")
    var port: Int = 4000

    @Option(name: .shortAndLong, help: "Server host")
    var host: String = "localhost"

    func run() throws {
        print("SwiftMUD Server starting on \(host):\(port)...")
    }
}
```

**Step 3: 建立測試目錄結構**

```bash
mkdir -p Tests/SwiftMUDTests
```

**Step 4: 建立基本測試檔案**

Create `Tests/SwiftMUDTests/SwiftMUDTests.swift`:

```swift
import XCTest
@testable import SwiftMUD

final class SwiftMUDTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

**Step 5: 驗證專案可編譯**

Run: `swift build`
Expected: Build Succeeded

**Step 6: 執行測試**

Run: `swift test`
Expected: Test Suite passed

**Step 7: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: initialize Swift package with dependencies"
```

---

### Task 2: 建立基礎資料模型

**Files:**
- Create: `Sources/SwiftMUD/Models/Item.swift`
- Create: `Sources/SwiftMUD/Models/Monster.swift`
- Create: `Sources/SwiftMUD/Models/Room.swift`
- Create: `Sources/SwiftMUD/Models/Player.swift`
- Create: `Sources/SwiftMUD/Models/Skill.swift`
- Create: `Sources/SwiftMUD/Models/Quest.swift`
- Create: `Sources/SwiftMUD/Models/Shop.swift`
- Create: `Sources/SwiftMUD/Models/AdminTier.swift`
- Create: `Tests/SwiftMUDTests/ModelsTests.swift`

**Step 1: 建立 AdminTier 列舉**

```swift
// Sources/SwiftMUD/Models/AdminTier.swift
import Foundation

public enum AdminTier: Int, Codable, Comparable, Sendable {
    case none = 0
    case trainee = 1    // 見習GM
    case gm = 2         // GM
    case superGm = 3    // 超級GM
    case creator = 4    // 創世神

    public static func < (lhs: AdminTier, rhs: AdminTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .none: return "玩家"
        case .trainee: return "見習GM"
        case .gm: return "GM"
        case .superGm: return "超級GM"
        case .creator: return "創世神"
        }
    }
}
```

**Step 2: 建立 Item 模型**

```swift
// Sources/SwiftMUD/Models/Item.swift
import Foundation

public enum ItemType: String, Codable, Sendable {
    case weapon
    case armor
    case potion
    case misc
}

public enum EquipmentSlot: String, Codable, Sendable {
    case weapon
    case head
    case body
    case hands
    case feet
    case accessory
}

public struct Item: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let itemType: ItemType
    public let power: Int
    public let price: Int
    public let slot: EquipmentSlot?

    public init(
        id: String,
        name: String,
        description: String,
        itemType: ItemType,
        power: Int = 0,
        price: Int = 0,
        slot: EquipmentSlot? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.itemType = itemType
        self.power = power
        self.price = price
        self.slot = slot
    }
}

public struct ItemInstance: Codable, Identifiable, Sendable {
    public let id: UUID
    public let itemId: String
    public var quantity: Int

    public init(itemId: String, quantity: Int = 1) {
        self.id = UUID()
        self.itemId = itemId
        self.quantity = quantity
    }
}
```

**Step 3: 建立 Skill 模型**

```swift
// Sources/SwiftMUD/Models/Skill.swift
import Foundation

public enum SkillType: String, Codable, Sendable {
    case active
    case passive
}

public enum EffectType: String, Codable, Sendable {
    case damage
    case heal
    case buff
    case debuff
    case taunt
}

public struct Effect: Codable, Sendable {
    public let type: EffectType
    public let value: Int
    public let duration: TimeInterval?

    public init(type: EffectType, value: Int, duration: TimeInterval? = nil) {
        self.type = type
        self.value = value
        self.duration = duration
    }
}

public struct StatBonus: Codable, Sendable {
    public var maxHP: Int
    public var maxMP: Int
    public var attack: Int
    public var defense: Int
    public var magic: Int
    public var mpRegen: Int

    public init(
        maxHP: Int = 0,
        maxMP: Int = 0,
        attack: Int = 0,
        defense: Int = 0,
        magic: Int = 0,
        mpRegen: Int = 0
    ) {
        self.maxHP = maxHP
        self.maxMP = maxMP
        self.attack = attack
        self.defense = defense
        self.magic = magic
        self.mpRegen = mpRegen
    }

    public static let zero = StatBonus()
}

public struct Skill: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let type: SkillType
    public let maxLevel: Int

    // 前置技能需求: [skillId: requiredLevel]
    public let prerequisites: [String: Int]

    // 主動技能屬性
    public let mpCost: Int
    public let castTime: TimeInterval
    public let cooldown: TimeInterval
    public let effects: [Effect]

    // 被動技能屬性
    public let statBonus: StatBonus

    public init(
        id: String,
        name: String,
        description: String,
        type: SkillType,
        maxLevel: Int = 3,
        prerequisites: [String: Int] = [:],
        mpCost: Int = 0,
        castTime: TimeInterval = 0,
        cooldown: TimeInterval = 0,
        effects: [Effect] = [],
        statBonus: StatBonus = .zero
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.maxLevel = maxLevel
        self.prerequisites = prerequisites
        self.mpCost = mpCost
        self.castTime = castTime
        self.cooldown = cooldown
        self.effects = effects
        self.statBonus = statBonus
    }
}
```

**Step 4: 建立 Monster 模型**

```swift
// Sources/SwiftMUD/Models/Monster.swift
import Foundation

public struct Monster: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let maxHP: Int
    public let attack: Int
    public let defense: Int
    public let exp: Int
    public let gold: Int
    public let drops: [String]  // Item IDs
    public let skills: [String] // Skill IDs monster can use

    public init(
        id: String,
        name: String,
        description: String,
        maxHP: Int,
        attack: Int,
        defense: Int,
        exp: Int,
        gold: Int = 0,
        drops: [String] = [],
        skills: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.maxHP = maxHP
        self.attack = attack
        self.defense = defense
        self.exp = exp
        self.gold = gold
        self.drops = drops
        self.skills = skills
    }
}

public final class MonsterInstance: Sendable {
    public let id: UUID
    public let monsterId: String
    public let currentHP: ManagedAtomic<Int>

    public init(monsterId: String, currentHP: Int) {
        self.id = UUID()
        self.monsterId = monsterId
        self.currentHP = ManagedAtomic(currentHP)
    }

    public var isAlive: Bool {
        currentHP.load(ordering: .relaxed) > 0
    }
}
```

**Note:** MonsterInstance 需要 import Atomics，我們先用簡化版本：

```swift
// Sources/SwiftMUD/Models/Monster.swift
import Foundation

public struct Monster: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let maxHP: Int
    public let attack: Int
    public let defense: Int
    public let exp: Int
    public let gold: Int
    public let drops: [String]
    public let skills: [String]

    public init(
        id: String,
        name: String,
        description: String,
        maxHP: Int,
        attack: Int,
        defense: Int,
        exp: Int,
        gold: Int = 0,
        drops: [String] = [],
        skills: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.maxHP = maxHP
        self.attack = attack
        self.defense = defense
        self.exp = exp
        self.gold = gold
        self.drops = drops
        self.skills = skills
    }
}

public struct MonsterInstance: Identifiable, Sendable {
    public let id: UUID
    public let monsterId: String
    public var currentHP: Int

    public init(monsterId: String, currentHP: Int) {
        self.id = UUID()
        self.monsterId = monsterId
        self.currentHP = currentHP
    }

    public var isAlive: Bool {
        currentHP > 0
    }
}
```

**Step 5: 建立 Room 模型**

```swift
// Sources/SwiftMUD/Models/Room.swift
import Foundation

public struct Room: Codable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var exits: [String: String]  // direction -> roomId
    public var items: [String]          // Item IDs on ground
    public var monsterSpawns: [String]  // Monster IDs that spawn here
    public var shopId: String?          // Shop in this room
    public var isSafeZone: Bool

    public init(
        id: String,
        name: String,
        description: String,
        exits: [String: String] = [:],
        items: [String] = [],
        monsterSpawns: [String] = [],
        shopId: String? = nil,
        isSafeZone: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.exits = exits
        self.items = items
        self.monsterSpawns = monsterSpawns
        self.shopId = shopId
        self.isSafeZone = isSafeZone
    }
}
```

**Step 6: 建立 Quest 模型**

```swift
// Sources/SwiftMUD/Models/Quest.swift
import Foundation

public enum QuestType: String, Codable, Sendable {
    case single
    case repeatable
    case chain
}

public enum QuestObjective: Codable, Sendable {
    case kill(monsterId: String, count: Int)
    case collect(itemId: String, count: Int)
    case visit(roomId: String)
    case talk(npcId: String)
    case reachLevel(level: Int)
    case learnSkill(skillId: String)
}

public struct QuestRewards: Codable, Sendable {
    public let gold: Int
    public let exp: Int
    public let items: [String]
    public let skillUnlock: String?

    public init(
        gold: Int = 0,
        exp: Int = 0,
        items: [String] = [],
        skillUnlock: String? = nil
    ) {
        self.gold = gold
        self.exp = exp
        self.items = items
        self.skillUnlock = skillUnlock
    }
}

public struct Quest: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let type: QuestType
    public let prerequisites: [String]    // Required quest IDs
    public let objectives: [QuestObjective]
    public let rewards: QuestRewards
    public let repeatCooldown: TimeInterval?
    public let giverNpcId: String?

    public init(
        id: String,
        name: String,
        description: String,
        type: QuestType,
        prerequisites: [String] = [],
        objectives: [QuestObjective],
        rewards: QuestRewards,
        repeatCooldown: TimeInterval? = nil,
        giverNpcId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.prerequisites = prerequisites
        self.objectives = objectives
        self.rewards = rewards
        self.repeatCooldown = repeatCooldown
        self.giverNpcId = giverNpcId
    }
}

public struct QuestProgress: Codable, Sendable {
    public let questId: String
    public var objectiveProgress: [Int]   // Progress for each objective
    public var isCompleted: Bool
    public var completedAt: Date?

    public init(questId: String, objectiveCount: Int) {
        self.questId = questId
        self.objectiveProgress = Array(repeating: 0, count: objectiveCount)
        self.isCompleted = false
        self.completedAt = nil
    }
}
```

**Step 7: 建立 Shop 模型**

```swift
// Sources/SwiftMUD/Models/Shop.swift
import Foundation

public struct ShopItem: Codable, Sendable {
    public let itemId: String
    public let price: Int
    public var stock: Int?  // nil = unlimited

    public init(itemId: String, price: Int, stock: Int? = nil) {
        self.itemId = itemId
        self.price = price
        self.stock = stock
    }
}

public struct Shop: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let roomId: String
    public var inventory: [ShopItem]
    public let buyRate: Double  // Rate for buying from players (e.g., 0.5 = 50%)

    public init(
        id: String,
        name: String,
        roomId: String,
        inventory: [ShopItem],
        buyRate: Double = 0.5
    ) {
        self.id = id
        self.name = name
        self.roomId = roomId
        self.inventory = inventory
        self.buyRate = buyRate
    }
}
```

**Step 8: 建立 Player 模型**

```swift
// Sources/SwiftMUD/Models/Player.swift
import Foundation

public struct Player: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var passwordHash: String

    // Level & Experience
    public var level: Int
    public var exp: Int
    public var gold: Int

    // Stats
    public var currentHP: Int
    public var maxHP: Int
    public var currentMP: Int
    public var maxMP: Int
    public var baseAttack: Int
    public var baseDefense: Int
    public var baseMagic: Int

    // Location
    public var currentRoomId: String

    // Inventory & Equipment
    public var inventory: [ItemInstance]
    public var equipment: [EquipmentSlot: String]  // slot -> itemId

    // Skills: skillId -> level
    public var skills: [String: Int]

    // Quests
    public var activeQuests: [QuestProgress]
    public var completedQuests: Set<String>

    // Admin
    public var adminTier: AdminTier

    // Timestamps
    public var createdAt: Date
    public var lastLoginAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        passwordHash: String,
        level: Int = 1,
        exp: Int = 0,
        gold: Int = 100,
        currentHP: Int = 100,
        maxHP: Int = 100,
        currentMP: Int = 50,
        maxMP: Int = 50,
        baseAttack: Int = 10,
        baseDefense: Int = 5,
        baseMagic: Int = 5,
        currentRoomId: String = "town_square",
        inventory: [ItemInstance] = [],
        equipment: [EquipmentSlot: String] = [:],
        skills: [String: Int] = [:],
        activeQuests: [QuestProgress] = [],
        completedQuests: Set<String> = [],
        adminTier: AdminTier = .none,
        createdAt: Date = Date(),
        lastLoginAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
        self.level = level
        self.exp = exp
        self.gold = gold
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.currentMP = currentMP
        self.maxMP = maxMP
        self.baseAttack = baseAttack
        self.baseDefense = baseDefense
        self.baseMagic = baseMagic
        self.currentRoomId = currentRoomId
        self.inventory = inventory
        self.equipment = equipment
        self.skills = skills
        self.activeQuests = activeQuests
        self.completedQuests = completedQuests
        self.adminTier = adminTier
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }

    public func expToNextLevel() -> Int {
        level * 100
    }
}
```

**Step 9: 建立模型測試**

```swift
// Tests/SwiftMUDTests/ModelsTests.swift
import XCTest
@testable import SwiftMUD

final class ModelsTests: XCTestCase {

    func testAdminTierComparison() {
        XCTAssertTrue(AdminTier.none < AdminTier.trainee)
        XCTAssertTrue(AdminTier.trainee < AdminTier.gm)
        XCTAssertTrue(AdminTier.gm < AdminTier.superGm)
        XCTAssertTrue(AdminTier.superGm < AdminTier.creator)
    }

    func testItemCreation() {
        let sword = Item(
            id: "iron_sword",
            name: "鐵劍",
            description: "一把鐵劍",
            itemType: .weapon,
            power: 15,
            price: 100,
            slot: .weapon
        )

        XCTAssertEqual(sword.id, "iron_sword")
        XCTAssertEqual(sword.itemType, .weapon)
        XCTAssertEqual(sword.power, 15)
    }

    func testPlayerExpToNextLevel() {
        var player = Player(name: "Test", passwordHash: "hash")
        XCTAssertEqual(player.expToNextLevel(), 100)

        player.level = 5
        XCTAssertEqual(player.expToNextLevel(), 500)
    }

    func testMonsterInstanceAlive() {
        var monster = MonsterInstance(monsterId: "wolf", currentHP: 30)
        XCTAssertTrue(monster.isAlive)

        monster.currentHP = 0
        XCTAssertFalse(monster.isAlive)
    }

    func testQuestProgress() {
        var progress = QuestProgress(questId: "quest1", objectiveCount: 3)
        XCTAssertEqual(progress.objectiveProgress.count, 3)
        XCTAssertFalse(progress.isCompleted)

        progress.objectiveProgress[0] = 5
        XCTAssertEqual(progress.objectiveProgress[0], 5)
    }
}
```

**Step 10: 執行測試**

Run: `swift test`
Expected: All tests pass

**Step 11: Commit**

```bash
git add Sources/SwiftMUD/Models/ Tests/SwiftMUDTests/ModelsTests.swift
git commit -m "feat: add core data models (Player, Item, Monster, Skill, Quest, Shop)"
```

---

### Task 3: 建立 SwiftNIO 伺服器基礎

**Files:**
- Create: `Sources/SwiftMUD/Server/MUDServer.swift`
- Create: `Sources/SwiftMUD/Server/ClientHandler.swift`
- Create: `Sources/SwiftMUD/Server/Session.swift`
- Modify: `Sources/SwiftMUD/main.swift`

**Step 1: 建立 Session 類別**

```swift
// Sources/SwiftMUD/Server/Session.swift
import NIO
import Foundation

public final class Session: Sendable {
    public let id: UUID
    public let channel: Channel
    public var playerName: String?
    public var playerId: UUID?
    public var isAuthenticated: Bool

    public init(channel: Channel) {
        self.id = UUID()
        self.channel = channel
        self.playerName = nil
        self.playerId = nil
        self.isAuthenticated = false
    }

    public func send(_ message: String) {
        let buffer = channel.allocator.buffer(string: message)
        channel.writeAndFlush(buffer, promise: nil)
    }

    public func sendLine(_ message: String) {
        send(message + "\n")
    }
}
```

**Step 2: 建立 ClientHandler**

```swift
// Sources/SwiftMUD/Server/ClientHandler.swift
import NIO
import Foundation

public final class ClientHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    private var session: Session?
    private weak var server: MUDServer?
    private var inputBuffer: String = ""

    public init(server: MUDServer) {
        self.server = server
    }

    public func channelActive(context: ChannelHandlerContext) {
        let session = Session(channel: context.channel)
        self.session = session
        server?.addSession(session)

        session.sendLine("歡迎來到 SwiftMUD 世界！")
        session.sendLine("請輸入你的名字：")
    }

    public func channelInactive(context: ChannelHandlerContext) {
        if let session = session {
            server?.removeSession(session)
        }
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        guard let received = buffer.readString(length: buffer.readableBytes) else {
            return
        }

        inputBuffer += received

        // Process complete lines
        while let newlineIndex = inputBuffer.firstIndex(of: "\n") {
            let line = String(inputBuffer[..<newlineIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            inputBuffer = String(inputBuffer[inputBuffer.index(after: newlineIndex)...])

            if !line.isEmpty {
                processLine(line)
            }
        }
    }

    private func processLine(_ line: String) {
        guard let session = session else { return }

        Task {
            await server?.processCommand(session: session, command: line)
        }
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Error: \(error)")
        context.close(promise: nil)
    }
}
```

**Step 3: 建立 MUDServer**

```swift
// Sources/SwiftMUD/Server/MUDServer.swift
import NIO
import Foundation

public actor MUDServer {
    private let group: MultiThreadedEventLoopGroup
    private var sessions: [UUID: Session] = [:]
    private var channel: Channel?

    public init(numberOfThreads: Int = System.coreCount) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: numberOfThreads)
    }

    public func start(host: String, port: Int) async throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self = self else {
                    return channel.eventLoop.makeFailedFuture(MUDError.serverNotAvailable)
                }
                let handler = ClientHandler(server: self)
                return channel.pipeline.addHandler(handler)
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try await bootstrap.bind(host: host, port: port).get()
        self.channel = channel

        print("SwiftMUD Server 啟動於 \(host):\(port)")
    }

    public func stop() async throws {
        try await channel?.close()
        try await group.shutdownGracefully()
    }

    public func addSession(_ session: Session) {
        sessions[session.id] = session
        print("新連線: \(session.id)")
    }

    public func removeSession(_ session: Session) {
        sessions.removeValue(forKey: session.id)
        if let name = session.playerName {
            broadcastToAll("【系統】\(name) 離開了世界")
        }
        print("斷線: \(session.id)")
    }

    public func processCommand(session: Session, command: String) async {
        // 基本指令處理 - 後續會擴充
        if !session.isAuthenticated {
            // 登入流程
            session.playerName = command
            session.isAuthenticated = true
            session.sendLine("歡迎，\(command)！")
            session.sendLine("輸入 help 查看指令說明。")
            broadcastToAll("【系統】\(command) 進入了世界")
        } else {
            // 處理遊戲指令
            session.sendLine("你輸入了：\(command)")
        }
    }

    public func broadcastToAll(_ message: String) {
        for session in sessions.values {
            session.sendLine(message)
        }
    }

    public func broadcastToRoom(_ roomId: String, _ message: String, exclude: UUID? = nil) {
        // TODO: 實作房間廣播
    }
}

public enum MUDError: Error {
    case serverNotAvailable
    case playerNotFound(name: String)
    case roomNotFound(id: String)
    case invalidCommand(command: String)
    case insufficientGold(required: Int, has: Int)
    case inventoryFull
    case notInCombat
    case skillOnCooldown(remaining: TimeInterval)
    case insufficientMP(required: Int, has: Int)
    case invalidTarget
    case permissionDenied(required: AdminTier)
    case targetHigherRank
}
```

**Step 4: 更新 main.swift**

```swift
// Sources/SwiftMUD/main.swift
import NIO
import ArgumentParser
import Foundation

@main
struct SwiftMUDApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftmud",
        abstract: "Swift MUD Game Server"
    )

    @Option(name: .shortAndLong, help: "Server port")
    var port: Int = 4000

    @Option(name: .shortAndLong, help: "Server host")
    var host: String = "localhost"

    func run() async throws {
        let server = MUDServer()

        // Handle shutdown signals
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler {
            print("\n正在關閉伺服器...")
            Task {
                try? await server.stop()
                exit(0)
            }
        }
        signalSource.resume()

        try await server.start(host: host, port: port)

        // Keep running
        try await Task.sleep(for: .seconds(.max))
    }
}
```

**Step 5: 編譯驗證**

Run: `swift build`
Expected: Build Succeeded

**Step 6: Commit**

```bash
git add Sources/SwiftMUD/
git commit -m "feat: add SwiftNIO server foundation (MUDServer, ClientHandler, Session)"
```

---

## Phase 2: 遊戲核心系統

### Task 4: 建立遊戲世界管理

**Files:**
- Create: `Sources/SwiftMUD/Game/World.swift`
- Create: `Sources/SwiftMUD/Game/GameData.swift`
- Create: `Resources/rooms.json`
- Create: `Resources/items.json`
- Create: `Resources/monsters.json`

**Step 1: 建立 GameData 資料載入器**

```swift
// Sources/SwiftMUD/Game/GameData.swift
import Foundation

public struct GameData: Sendable {
    public let items: [String: Item]
    public let monsters: [String: Monster]
    public let rooms: [String: Room]
    public let skills: [String: Skill]
    public let quests: [String: Quest]
    public let shops: [String: Shop]

    public init(
        items: [String: Item] = [:],
        monsters: [String: Monster] = [:],
        rooms: [String: Room] = [:],
        skills: [String: Skill] = [:],
        quests: [String: Quest] = [:],
        shops: [String: Shop] = [:]
    ) {
        self.items = items
        self.monsters = monsters
        self.rooms = rooms
        self.skills = skills
        self.quests = quests
        self.shops = shops
    }

    public static func loadDefault() -> GameData {
        // 預設遊戲資料
        let items: [String: Item] = [
            "rusty_sword": Item(
                id: "rusty_sword",
                name: "生鏽的劍",
                description: "一把佈滿鏽斑的舊劍，但還算鋒利。",
                itemType: .weapon,
                power: 5,
                price: 20,
                slot: .weapon
            ),
            "iron_sword": Item(
                id: "iron_sword",
                name: "鐵劍",
                description: "打造精良的鐵劍，握感很好。",
                itemType: .weapon,
                power: 15,
                price: 150,
                slot: .weapon
            ),
            "potion": Item(
                id: "potion",
                name: "紅色藥水",
                description: "散發著淡淡香氣的治療藥水。",
                itemType: .potion,
                power: 30,
                price: 25
            ),
            "mana_potion": Item(
                id: "mana_potion",
                name: "藍色藥水",
                description: "恢復魔力的藥水。",
                itemType: .potion,
                power: 20,
                price: 30
            ),
            "wolf_fang": Item(
                id: "wolf_fang",
                name: "狼牙",
                description: "鋒利的狼牙，可以賣給商人。",
                itemType: .misc,
                price: 10
            ),
            "goblin_ear": Item(
                id: "goblin_ear",
                name: "哥布林耳朵",
                description: "醜陋的哥布林耳朵，是討伐證明。",
                itemType: .misc,
                price: 15
            ),
            "gold_coin": Item(
                id: "gold_coin",
                name: "金幣",
                description: "閃閃發光的金幣。",
                itemType: .misc,
                price: 1
            ),
        ]

        let monsters: [String: Monster] = [
            "wolf": Monster(
                id: "wolf",
                name: "野狼",
                description: "一隻灰色的野狼，眼中閃爍著飢餓的光芒。",
                maxHP: 30,
                attack: 8,
                defense: 2,
                exp: 20,
                gold: 5,
                drops: ["wolf_fang"]
            ),
            "goblin": Monster(
                id: "goblin",
                name: "哥布林",
                description: "矮小醜陋的哥布林，手持一根木棒。",
                maxHP: 40,
                attack: 10,
                defense: 3,
                exp: 30,
                gold: 15,
                drops: ["goblin_ear", "gold_coin"]
            ),
            "forest_spider": Monster(
                id: "forest_spider",
                name: "森林蜘蛛",
                description: "巨大的黑色蜘蛛，八隻眼睛盯著你。",
                maxHP: 25,
                attack: 12,
                defense: 1,
                exp: 25,
                gold: 8,
                drops: ["potion"]
            ),
            "bandit": Monster(
                id: "bandit",
                name: "山賊",
                description: "一個兇惡的山賊，腰間別著一把匕首。",
                maxHP: 60,
                attack: 15,
                defense: 5,
                exp: 50,
                gold: 30,
                drops: ["gold_coin", "iron_sword"]
            ),
        ]

        let rooms: [String: Room] = [
            "town_square": Room(
                id: "town_square",
                name: "城鎮廣場",
                description: "你站在熱鬧的城鎮廣場中央。這裡是安全區，沒有怪物出沒。",
                exits: ["north": "temple", "south": "market", "east": "inn", "west": "forest_entrance"],
                items: ["rusty_sword"],
                isSafeZone: true
            ),
            "temple": Room(
                id: "temple",
                name: "古老神殿",
                description: "一座莊嚴的神殿。這裡可以治療傷勢。",
                exits: ["south": "town_square"],
                items: ["potion"],
                isSafeZone: true
            ),
            "market": Room(
                id: "market",
                name: "市集",
                description: "擁擠的市集，商販們叫賣著各種商品。",
                exits: ["north": "town_square"],
                shopId: "general_shop",
                isSafeZone: true
            ),
            "inn": Room(
                id: "inn",
                name: "旅人客棧",
                description: "溫暖的客棧，可以在這裡休息恢復體力。",
                exits: ["west": "town_square"],
                isSafeZone: true
            ),
            "forest_entrance": Room(
                id: "forest_entrance",
                name: "森林入口",
                description: "高聳的樹木遮蔽了陽光。你聽到草叢中有動靜...",
                exits: ["east": "town_square", "west": "deep_forest", "north": "forest_path"],
                monsterSpawns: ["wolf"]
            ),
            "forest_path": Room(
                id: "forest_path",
                name: "森林小徑",
                description: "蜿蜒的小徑穿過茂密的樹林。蜘蛛網隨處可見。",
                exits: ["south": "forest_entrance", "west": "spider_nest"],
                monsterSpawns: ["wolf", "forest_spider"]
            ),
            "spider_nest": Room(
                id: "spider_nest",
                name: "蜘蛛巢穴",
                description: "到處都是黏稠的蜘蛛絲。這裡是蜘蛛的地盤。",
                exits: ["east": "forest_path"],
                items: ["iron_sword"],
                monsterSpawns: ["forest_spider", "forest_spider"]
            ),
            "deep_forest": Room(
                id: "deep_forest",
                name: "森林深處",
                description: "你已經深入森林。一間破舊的小屋出現在前方。",
                exits: ["east": "forest_entrance", "west": "bandit_camp"],
                monsterSpawns: ["goblin"]
            ),
            "bandit_camp": Room(
                id: "bandit_camp",
                name: "山賊營地",
                description: "山賊的營地。營火旁散落著搶來的財物。",
                exits: ["east": "deep_forest"],
                items: ["gold_coin"],
                monsterSpawns: ["bandit", "goblin"]
            ),
        ]

        let shops: [String: Shop] = [
            "general_shop": Shop(
                id: "general_shop",
                name: "雜貨店",
                roomId: "market",
                inventory: [
                    ShopItem(itemId: "potion", price: 25),
                    ShopItem(itemId: "mana_potion", price: 30),
                    ShopItem(itemId: "rusty_sword", price: 50),
                    ShopItem(itemId: "iron_sword", price: 200),
                ],
                buyRate: 0.5
            )
        ]

        let skills: [String: Skill] = [
            "fireball": Skill(
                id: "fireball",
                name: "火球術",
                description: "向目標發射一顆火球。",
                type: .active,
                mpCost: 15,
                castTime: 1.5,
                cooldown: 8,
                effects: [Effect(type: .damage, value: 150)]
            ),
            "heal": Skill(
                id: "heal",
                name: "治療術",
                description: "恢復自身生命值。",
                type: .active,
                mpCost: 20,
                castTime: 2.0,
                cooldown: 15,
                effects: [Effect(type: .heal, value: 30)]
            ),
            "quick_slash": Skill(
                id: "quick_slash",
                name: "疾風斬",
                description: "快速的一擊。",
                type: .active,
                mpCost: 10,
                castTime: 0,
                cooldown: 5,
                effects: [Effect(type: .damage, value: 120)]
            ),
            "taunt": Skill(
                id: "taunt",
                name: "嘲諷",
                description: "強制目標攻擊自己。",
                type: .active,
                mpCost: 5,
                castTime: 0,
                cooldown: 20,
                effects: [Effect(type: .taunt, value: 1, duration: 10)]
            ),
            "strong_body_1": Skill(
                id: "strong_body_1",
                name: "強壯體魄 I",
                description: "增加最大生命值 10%。",
                type: .passive,
                statBonus: StatBonus(maxHP: 10)
            ),
            "strong_body_2": Skill(
                id: "strong_body_2",
                name: "強壯體魄 II",
                description: "增加最大生命值 20%。",
                type: .passive,
                prerequisites: ["strong_body_1": 1],
                statBonus: StatBonus(maxHP: 20)
            ),
            "sharp_1": Skill(
                id: "sharp_1",
                name: "銳利 I",
                description: "增加攻擊力 5%。",
                type: .passive,
                statBonus: StatBonus(attack: 5)
            ),
        ]

        let quests: [String: Quest] = [
            "explore_forest": Quest(
                id: "explore_forest",
                name: "初探森林",
                description: "前往森林入口一探究竟。",
                type: .single,
                objectives: [.visit(roomId: "forest_entrance")],
                rewards: QuestRewards(gold: 100, exp: 50)
            ),
            "wolf_hunt": Quest(
                id: "wolf_hunt",
                name: "狼患",
                description: "森林中的野狼威脅著旅人的安全，請消滅牠們。",
                type: .single,
                prerequisites: ["explore_forest"],
                objectives: [.kill(monsterId: "wolf", count: 5)],
                rewards: QuestRewards(gold: 200, exp: 100, items: ["potion"])
            ),
            "spider_nest_quest": Quest(
                id: "spider_nest_quest",
                name: "蜘蛛巢穴",
                description: "清理森林深處的蜘蛛巢穴。",
                type: .single,
                prerequisites: ["wolf_hunt"],
                objectives: [
                    .kill(monsterId: "forest_spider", count: 3),
                    .visit(roomId: "spider_nest")
                ],
                rewards: QuestRewards(gold: 500, exp: 200, skillUnlock: "quick_slash")
            ),
            "daily_hunt": Quest(
                id: "daily_hunt",
                name: "每日討伐",
                description: "消滅任意怪物獲得獎勵。",
                type: .repeatable,
                objectives: [.kill(monsterId: "wolf", count: 3)],
                rewards: QuestRewards(gold: 50, exp: 30),
                repeatCooldown: 86400  // 24 hours
            ),
        ]

        return GameData(
            items: items,
            monsters: monsters,
            rooms: rooms,
            skills: skills,
            quests: quests,
            shops: shops
        )
    }
}
```

**Step 2: 建立 World 類別**

```swift
// Sources/SwiftMUD/Game/World.swift
import Foundation

public actor World {
    public let gameData: GameData
    private var roomMonsters: [String: [MonsterInstance]] = [:]
    private var roomItems: [String: [String]] = [:]

    public init(gameData: GameData = .loadDefault()) {
        self.gameData = gameData
        initializeWorld()
    }

    private func initializeWorld() {
        // 初始化房間怪物
        for (roomId, room) in gameData.rooms {
            spawnMonstersInRoom(roomId)
            roomItems[roomId] = room.items
        }
    }

    public func spawnMonstersInRoom(_ roomId: String) {
        guard let room = gameData.rooms[roomId] else { return }

        var monsters: [MonsterInstance] = []
        for monsterId in room.monsterSpawns {
            if let template = gameData.monsters[monsterId] {
                monsters.append(MonsterInstance(monsterId: monsterId, currentHP: template.maxHP))
            }
        }
        roomMonsters[roomId] = monsters
    }

    public func getMonstersInRoom(_ roomId: String) -> [MonsterInstance] {
        roomMonsters[roomId] ?? []
    }

    public func getAliveMonsters(_ roomId: String) -> [MonsterInstance] {
        getMonstersInRoom(roomId).filter { $0.isAlive }
    }

    public func getItemsInRoom(_ roomId: String) -> [String] {
        roomItems[roomId] ?? []
    }

    public func addItemToRoom(_ roomId: String, itemId: String) {
        if roomItems[roomId] == nil {
            roomItems[roomId] = []
        }
        roomItems[roomId]?.append(itemId)
    }

    public func removeItemFromRoom(_ roomId: String, itemId: String) -> Bool {
        guard var items = roomItems[roomId],
              let index = items.firstIndex(of: itemId) else {
            return false
        }
        items.remove(at: index)
        roomItems[roomId] = items
        return true
    }

    public func getRoom(_ roomId: String) -> Room? {
        gameData.rooms[roomId]
    }

    public func getItem(_ itemId: String) -> Item? {
        gameData.items[itemId]
    }

    public func getMonster(_ monsterId: String) -> Monster? {
        gameData.monsters[monsterId]
    }

    public func getSkill(_ skillId: String) -> Skill? {
        gameData.skills[skillId]
    }

    public func getQuest(_ questId: String) -> Quest? {
        gameData.quests[questId]
    }

    public func getShop(_ shopId: String) -> Shop? {
        gameData.shops[shopId]
    }

    public func getShopInRoom(_ roomId: String) -> Shop? {
        guard let room = gameData.rooms[roomId],
              let shopId = room.shopId else {
            return nil
        }
        return gameData.shops[shopId]
    }
}
```

**Step 3: 建立測試**

```swift
// Tests/SwiftMUDTests/WorldTests.swift
import XCTest
@testable import SwiftMUD

final class WorldTests: XCTestCase {

    func testWorldInitialization() async {
        let world = World()

        let room = await world.getRoom("town_square")
        XCTAssertNotNil(room)
        XCTAssertEqual(room?.name, "城鎮廣場")
    }

    func testGetItem() async {
        let world = World()

        let sword = await world.getItem("iron_sword")
        XCTAssertNotNil(sword)
        XCTAssertEqual(sword?.power, 15)
    }

    func testGetMonstersInRoom() async {
        let world = World()

        let monsters = await world.getAliveMonsters("forest_entrance")
        XCTAssertEqual(monsters.count, 1)
        XCTAssertEqual(monsters.first?.monsterId, "wolf")
    }

    func testRoomItems() async {
        let world = World()

        let items = await world.getItemsInRoom("town_square")
        XCTAssertTrue(items.contains("rusty_sword"))

        await world.addItemToRoom("town_square", itemId: "potion")
        let updatedItems = await world.getItemsInRoom("town_square")
        XCTAssertTrue(updatedItems.contains("potion"))

        let removed = await world.removeItemFromRoom("town_square", itemId: "potion")
        XCTAssertTrue(removed)
    }

    func testGetShopInRoom() async {
        let world = World()

        let shop = await world.getShopInRoom("market")
        XCTAssertNotNil(shop)
        XCTAssertEqual(shop?.name, "雜貨店")
    }
}
```

**Step 4: 執行測試**

Run: `swift test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/SwiftMUD/Game/ Tests/SwiftMUDTests/WorldTests.swift
git commit -m "feat: add World and GameData for game state management"
```

---

### Task 5: 建立指令解析系統

**Files:**
- Create: `Sources/SwiftMUD/Commands/CommandParser.swift`
- Create: `Sources/SwiftMUD/Commands/CommandResult.swift`
- Create: `Tests/SwiftMUDTests/CommandParserTests.swift`

**Step 1: 建立 CommandResult**

```swift
// Sources/SwiftMUD/Commands/CommandResult.swift
import Foundation

public struct CommandResult: Sendable {
    public let message: String
    public let broadcastToRoom: String?
    public let broadcastToAll: String?

    public init(
        message: String,
        broadcastToRoom: String? = nil,
        broadcastToAll: String? = nil
    ) {
        self.message = message
        self.broadcastToRoom = broadcastToRoom
        self.broadcastToAll = broadcastToAll
    }

    public static func error(_ message: String) -> CommandResult {
        CommandResult(message: message)
    }

    public static func success(_ message: String) -> CommandResult {
        CommandResult(message: message)
    }
}
```

**Step 2: 建立 CommandParser**

```swift
// Sources/SwiftMUD/Commands/CommandParser.swift
import Foundation

public enum Command: Sendable {
    // Movement
    case move(direction: String)
    case look

    // Items
    case get(itemName: String)
    case drop(itemName: String)
    case inventory
    case use(itemName: String)
    case equip(itemName: String)

    // Combat
    case attack(target: String?)
    case cast(skillName: String)
    case flee

    // Status
    case status
    case skills

    // Quest
    case questList
    case questActive
    case questInfo(questName: String)
    case questAccept(questName: String)
    case questAbandon(questName: String)
    case questComplete

    // Shop
    case shop
    case buy(itemName: String, quantity: Int)
    case sell(itemName: String, quantity: Int)

    // Trade
    case trade(playerName: String)
    case tradeAccept
    case tradeAdd(itemName: String)
    case tradeGold(amount: Int)
    case tradeConfirm
    case tradeCancel

    // Social
    case say(message: String)
    case who

    // Special locations
    case rest
    case pray

    // Help
    case help

    // Admin commands (prefixed with @)
    case admin(subcommand: AdminCommand)

    // Unknown
    case unknown(input: String)
}

public enum AdminCommand: Sendable {
    // Trainee GM
    case who
    case info(playerName: String)
    case mute(playerName: String, minutes: Int)
    case unmute(playerName: String)
    case watch(playerName: String)

    // GM
    case kick(playerName: String, reason: String?)
    case teleport(playerName: String, roomId: String)
    case goto(roomId: String)
    case summon(playerName: String)
    case warn(playerName: String, message: String)
    case announce(message: String)

    // Super GM
    case spawn(monsterId: String, count: Int)
    case give(playerName: String, itemId: String, count: Int)
    case setGold(playerName: String, amount: Int)
    case setLevel(playerName: String, level: Int)
    case heal(playerName: String)
    case roomCreate(name: String)
    case roomEdit(property: String, value: String)
    case roomLink(direction: String, roomId: String)

    // Creator
    case promote(playerName: String, tier: Int)
    case demote(playerName: String)
    case ban(playerName: String, days: Int?)
    case unban(playerName: String)
    case config(setting: String, value: String)
    case shutdown(seconds: Int?)
    case reload

    case unknown(input: String)
}

public struct CommandParser {

    private static let directionAliases: [String: String] = [
        "n": "north", "s": "south", "e": "east", "w": "west",
        "北": "north", "南": "south", "東": "east", "西": "west",
        "上": "up", "下": "down", "u": "up", "d": "down"
    ]

    public static func parse(_ input: String) -> Command {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown(input: "") }

        // Check for admin commands
        if trimmed.hasPrefix("@") {
            return .admin(subcommand: parseAdminCommand(String(trimmed.dropFirst())))
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts[0].lowercased()
        let arg = parts.count > 1 ? parts[1] : ""

        // Resolve direction aliases
        let resolved = directionAliases[cmd] ?? cmd

        switch resolved {
        // Movement
        case "north", "south", "east", "west", "up", "down":
            return .move(direction: resolved)
        case "look", "l":
            return .look

        // Items
        case "get", "take", "pick":
            return arg.isEmpty ? .unknown(input: trimmed) : .get(itemName: arg)
        case "drop":
            return arg.isEmpty ? .unknown(input: trimmed) : .drop(itemName: arg)
        case "inventory", "inv", "i":
            return .inventory
        case "use":
            return arg.isEmpty ? .unknown(input: trimmed) : .use(itemName: arg)
        case "equip", "eq":
            return arg.isEmpty ? .unknown(input: trimmed) : .equip(itemName: arg)

        // Combat
        case "attack", "att", "a", "kill", "k":
            return .attack(target: arg.isEmpty ? nil : arg)
        case "cast", "c":
            return arg.isEmpty ? .unknown(input: trimmed) : .cast(skillName: arg)
        case "flee", "run", "逃":
            return .flee

        // Status
        case "status", "st", "stat":
            return .status
        case "skills", "sk":
            return .skills

        // Quest
        case "quest", "q":
            return parseQuestCommand(arg)

        // Shop
        case "shop":
            return arg.isEmpty ? .shop : parseShopCommand(arg)
        case "buy":
            return parseBuyCommand(arg)
        case "sell":
            return parseSellCommand(arg)

        // Trade
        case "trade":
            return parseTradeCommand(arg)

        // Social
        case "say", "'":
            return arg.isEmpty ? .unknown(input: trimmed) : .say(message: arg)
        case "who":
            return .who

        // Special locations
        case "rest":
            return .rest
        case "pray":
            return .pray

        // Help
        case "help", "h", "?":
            return .help

        default:
            return .unknown(input: trimmed)
        }
    }

    private static func parseQuestCommand(_ arg: String) -> Command {
        let parts = arg.split(separator: " ", maxSplits: 1).map(String.init)
        let subCmd = parts.first?.lowercased() ?? ""
        let questArg = parts.count > 1 ? parts[1] : ""

        switch subCmd {
        case "list", "l", "":
            return .questList
        case "active", "a":
            return .questActive
        case "info", "i":
            return questArg.isEmpty ? .questList : .questInfo(questName: questArg)
        case "accept":
            return questArg.isEmpty ? .questList : .questAccept(questName: questArg)
        case "abandon":
            return questArg.isEmpty ? .questActive : .questAbandon(questName: questArg)
        case "complete", "c":
            return .questComplete
        default:
            return .questInfo(questName: subCmd)
        }
    }

    private static func parseShopCommand(_ arg: String) -> Command {
        let parts = arg.split(separator: " ", maxSplits: 1).map(String.init)
        let subCmd = parts.first?.lowercased() ?? ""

        switch subCmd {
        case "list", "l":
            return .shop
        default:
            return .shop
        }
    }

    private static func parseBuyCommand(_ arg: String) -> Command {
        let parts = arg.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return .shop }

        let quantity = parts.count > 1 ? Int(parts.last!) ?? 1 : 1
        let itemName = parts.count > 1 ? parts.dropLast().joined(separator: " ") : parts[0]

        return .buy(itemName: itemName, quantity: quantity)
    }

    private static func parseSellCommand(_ arg: String) -> Command {
        let parts = arg.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return .shop }

        let quantity = parts.count > 1 ? Int(parts.last!) ?? 1 : 1
        let itemName = parts.count > 1 ? parts.dropLast().joined(separator: " ") : parts[0]

        return .sell(itemName: itemName, quantity: quantity)
    }

    private static func parseTradeCommand(_ arg: String) -> Command {
        let parts = arg.split(separator: " ", maxSplits: 1).map(String.init)
        let subCmd = parts.first?.lowercased() ?? ""
        let tradeArg = parts.count > 1 ? parts[1] : ""

        switch subCmd {
        case "accept":
            return .tradeAccept
        case "add":
            return tradeArg.isEmpty ? .unknown(input: "trade add") : .tradeAdd(itemName: tradeArg)
        case "gold":
            guard let amount = Int(tradeArg) else { return .unknown(input: "trade gold") }
            return .tradeGold(amount: amount)
        case "confirm":
            return .tradeConfirm
        case "cancel":
            return .tradeCancel
        case "":
            return .unknown(input: "trade")
        default:
            return .trade(playerName: subCmd)
        }
    }

    private static func parseAdminCommand(_ input: String) -> AdminCommand {
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first?.lowercased() ?? ""
        let arg = parts.count > 1 ? parts[1] : ""

        switch cmd {
        // Trainee GM
        case "who":
            return .who
        case "info":
            return arg.isEmpty ? .unknown(input: input) : .info(playerName: arg)
        case "mute":
            let muteParts = arg.split(separator: " ").map(String.init)
            guard muteParts.count >= 2, let minutes = Int(muteParts[1]) else {
                return .unknown(input: input)
            }
            return .mute(playerName: muteParts[0], minutes: minutes)
        case "unmute":
            return arg.isEmpty ? .unknown(input: input) : .unmute(playerName: arg)
        case "watch":
            return arg.isEmpty ? .unknown(input: input) : .watch(playerName: arg)

        // GM
        case "kick":
            let kickParts = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard !kickParts.isEmpty else { return .unknown(input: input) }
            let reason = kickParts.count > 1 ? kickParts[1] : nil
            return .kick(playerName: kickParts[0], reason: reason)
        case "teleport":
            let tpParts = arg.split(separator: " ").map(String.init)
            guard tpParts.count >= 2 else { return .unknown(input: input) }
            return .teleport(playerName: tpParts[0], roomId: tpParts[1])
        case "goto":
            return arg.isEmpty ? .unknown(input: input) : .goto(roomId: arg)
        case "summon":
            return arg.isEmpty ? .unknown(input: input) : .summon(playerName: arg)
        case "warn":
            let warnParts = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard warnParts.count >= 2 else { return .unknown(input: input) }
            return .warn(playerName: warnParts[0], message: warnParts[1])
        case "announce":
            return arg.isEmpty ? .unknown(input: input) : .announce(message: arg)

        // Super GM
        case "spawn":
            let spawnParts = arg.split(separator: " ").map(String.init)
            guard !spawnParts.isEmpty else { return .unknown(input: input) }
            let count = spawnParts.count > 1 ? Int(spawnParts[1]) ?? 1 : 1
            return .spawn(monsterId: spawnParts[0], count: count)
        case "give":
            let giveParts = arg.split(separator: " ").map(String.init)
            guard giveParts.count >= 2 else { return .unknown(input: input) }
            let count = giveParts.count > 2 ? Int(giveParts[2]) ?? 1 : 1
            return .give(playerName: giveParts[0], itemId: giveParts[1], count: count)
        case "setgold":
            let goldParts = arg.split(separator: " ").map(String.init)
            guard goldParts.count >= 2, let amount = Int(goldParts[1]) else {
                return .unknown(input: input)
            }
            return .setGold(playerName: goldParts[0], amount: amount)
        case "setlevel":
            let levelParts = arg.split(separator: " ").map(String.init)
            guard levelParts.count >= 2, let level = Int(levelParts[1]) else {
                return .unknown(input: input)
            }
            return .setLevel(playerName: levelParts[0], level: level)
        case "heal":
            return arg.isEmpty ? .unknown(input: input) : .heal(playerName: arg)

        // Creator
        case "promote":
            let promParts = arg.split(separator: " ").map(String.init)
            guard promParts.count >= 2, let tier = Int(promParts[1]) else {
                return .unknown(input: input)
            }
            return .promote(playerName: promParts[0], tier: tier)
        case "demote":
            return arg.isEmpty ? .unknown(input: input) : .demote(playerName: arg)
        case "ban":
            let banParts = arg.split(separator: " ").map(String.init)
            guard !banParts.isEmpty else { return .unknown(input: input) }
            let days = banParts.count > 1 ? Int(banParts[1]) : nil
            return .ban(playerName: banParts[0], days: days)
        case "unban":
            return arg.isEmpty ? .unknown(input: input) : .unban(playerName: arg)
        case "config":
            let configParts = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard configParts.count >= 2 else { return .unknown(input: input) }
            return .config(setting: configParts[0], value: configParts[1])
        case "shutdown":
            let seconds = arg.isEmpty ? nil : Int(arg)
            return .shutdown(seconds: seconds)
        case "reload":
            return .reload

        default:
            return .unknown(input: input)
        }
    }
}
```

**Step 3: 建立測試**

```swift
// Tests/SwiftMUDTests/CommandParserTests.swift
import XCTest
@testable import SwiftMUD

final class CommandParserTests: XCTestCase {

    func testMoveCommands() {
        if case .move(let dir) = CommandParser.parse("north") {
            XCTAssertEqual(dir, "north")
        } else {
            XCTFail("Expected move command")
        }

        if case .move(let dir) = CommandParser.parse("n") {
            XCTAssertEqual(dir, "north")
        } else {
            XCTFail("Expected move command with alias")
        }

        if case .move(let dir) = CommandParser.parse("東") {
            XCTAssertEqual(dir, "east")
        } else {
            XCTFail("Expected move command with Chinese alias")
        }
    }

    func testItemCommands() {
        if case .get(let item) = CommandParser.parse("get sword") {
            XCTAssertEqual(item, "sword")
        } else {
            XCTFail("Expected get command")
        }

        if case .inventory = CommandParser.parse("inv") {
            // Pass
        } else {
            XCTFail("Expected inventory command")
        }
    }

    func testCombatCommands() {
        if case .attack(let target) = CommandParser.parse("attack wolf") {
            XCTAssertEqual(target, "wolf")
        } else {
            XCTFail("Expected attack command")
        }

        if case .attack(let target) = CommandParser.parse("a") {
            XCTAssertNil(target)
        } else {
            XCTFail("Expected attack command without target")
        }

        if case .flee = CommandParser.parse("flee") {
            // Pass
        } else {
            XCTFail("Expected flee command")
        }
    }

    func testQuestCommands() {
        if case .questList = CommandParser.parse("quest list") {
            // Pass
        } else {
            XCTFail("Expected quest list command")
        }

        if case .questAccept(let name) = CommandParser.parse("quest accept wolf_hunt") {
            XCTAssertEqual(name, "wolf_hunt")
        } else {
            XCTFail("Expected quest accept command")
        }
    }

    func testShopCommands() {
        if case .shop = CommandParser.parse("shop") {
            // Pass
        } else {
            XCTFail("Expected shop command")
        }

        if case .buy(let item, let qty) = CommandParser.parse("buy potion 5") {
            XCTAssertEqual(item, "potion")
            XCTAssertEqual(qty, 5)
        } else {
            XCTFail("Expected buy command")
        }
    }

    func testAdminCommands() {
        if case .admin(let sub) = CommandParser.parse("@kick player reason") {
            if case .kick(let name, let reason) = sub {
                XCTAssertEqual(name, "player")
                XCTAssertEqual(reason, "reason")
            } else {
                XCTFail("Expected kick subcommand")
            }
        } else {
            XCTFail("Expected admin command")
        }

        if case .admin(let sub) = CommandParser.parse("@announce Hello World") {
            if case .announce(let msg) = sub {
                XCTAssertEqual(msg, "Hello World")
            } else {
                XCTFail("Expected announce subcommand")
            }
        } else {
            XCTFail("Expected admin command")
        }
    }
}
```

**Step 4: 執行測試**

Run: `swift test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/SwiftMUD/Commands/ Tests/SwiftMUDTests/CommandParserTests.swift
git commit -m "feat: add command parser with player, combat, quest, shop, and admin commands"
```

---

## Phase 3: 戰鬥系統

### Task 6: 建立即時戰鬥引擎

**Files:**
- Create: `Sources/SwiftMUD/Combat/CombatEngine.swift`
- Create: `Sources/SwiftMUD/Combat/CombatState.swift`
- Create: `Sources/SwiftMUD/Combat/DamageCalculator.swift`
- Create: `Tests/SwiftMUDTests/CombatTests.swift`

（由於篇幅限制，以下 Task 6-15 的詳細步驟結構相同，包含：戰鬥引擎、技能系統、任務系統、商店系統、交易系統、管理系統、資料庫層、完整整合）

---

## Phase 4: 系統整合與測試

### Task 14: 整合所有系統

### Task 15: 端對端測試

---

## 執行檢查清單

- [ ] Task 1: Swift Package 初始化
- [ ] Task 2: 資料模型
- [ ] Task 3: SwiftNIO 伺服器
- [ ] Task 4: 遊戲世界管理
- [ ] Task 5: 指令解析
- [ ] Task 6: 戰鬥引擎
- [ ] Task 7: 技能系統
- [ ] Task 8: 任務系統
- [ ] Task 9: 商店系統
- [ ] Task 10: 交易系統
- [ ] Task 11: 管理系統
- [ ] Task 12: 資料庫抽象層
- [ ] Task 13: 整合指令處理
- [ ] Task 14: 系統整合
- [ ] Task 15: 端對端測試
