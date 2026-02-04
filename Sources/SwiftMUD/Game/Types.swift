import Foundation

// MARK: - 管理權限層級
enum AdminTier: Int, Codable, Comparable, CaseIterable {
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
    case daily       // 每日任務
    case weekly      // 每週任務
    case chain       // 任務鏈
}

// MARK: - 任務目標
enum QuestObjective: Codable, Equatable {
    case kill(monsterId: String, count: Int)
    case collect(itemId: String, count: Int)
    case visit(roomId: String)
    case talkTo(npcId: String)
    case useItem(itemId: String, count: Int)
    case reachLevel(level: Int)
    case learnSkill(skillId: String)

    var description: String {
        switch self {
        case .kill(let monsterId, let count):
            return "擊殺 \(monsterId) x\(count)"
        case .collect(let itemId, let count):
            return "收集 \(itemId) x\(count)"
        case .visit(let roomId):
            return "前往 \(roomId)"
        case .talkTo(let npcId):
            return "與 \(npcId) 對話"
        case .useItem(let itemId, let count):
            return "使用 \(itemId) x\(count)"
        case .reachLevel(let level):
            return "達到 \(level) 級"
        case .learnSkill(let skillId):
            return "學習技能 \(skillId)"
        }
    }
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
