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
