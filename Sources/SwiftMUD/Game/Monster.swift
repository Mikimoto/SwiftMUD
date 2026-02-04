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
