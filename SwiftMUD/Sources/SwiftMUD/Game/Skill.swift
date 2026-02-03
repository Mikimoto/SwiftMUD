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
