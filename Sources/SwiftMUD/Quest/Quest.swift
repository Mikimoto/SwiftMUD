import Foundation

/// 任務獎勵
struct QuestRewards: Codable, Equatable {
    let exp: Int
    let gold: Int
    let items: [String: Int]  // itemId -> count
    let skillPoints: Int

    init(exp: Int = 0, gold: Int = 0, items: [String: Int] = [:], skillPoints: Int = 0) {
        self.exp = exp
        self.gold = gold
        self.items = items
        self.skillPoints = skillPoints
    }

    func description() -> String {
        var parts: [String] = []
        if exp > 0 { parts.append("\(exp) 經驗") }
        if gold > 0 { parts.append("\(gold) 金幣") }
        if skillPoints > 0 { parts.append("\(skillPoints) 技能點") }
        if !items.isEmpty {
            let itemList = items.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            parts.append(itemList)
        }
        return parts.isEmpty ? "無" : parts.joined(separator: "、")
    }
}

/// 任務定義
struct Quest: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: QuestType

    /// 任務目標列表
    let objectives: [QuestObjective]

    /// 完成獎勵
    let rewards: QuestRewards

    /// 前置任務 ID（需要先完成這些任務）
    let prerequisites: [String]

    /// 最低等級需求
    let levelRequired: Int

    /// 可重複任務的冷卻時間（秒）
    let cooldown: TimeInterval?

    /// 任務給予者 NPC ID
    let giverNpcId: String?

    /// 任務完成地點 NPC ID
    let turnInNpcId: String?

    init(
        id: String,
        name: String,
        description: String,
        type: QuestType = .single,
        objectives: [QuestObjective],
        rewards: QuestRewards,
        prerequisites: [String] = [],
        levelRequired: Int = 1,
        cooldown: TimeInterval? = nil,
        giverNpcId: String? = nil,
        turnInNpcId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.objectives = objectives
        self.rewards = rewards
        self.prerequisites = prerequisites
        self.levelRequired = levelRequired
        self.cooldown = cooldown
        self.giverNpcId = giverNpcId
        self.turnInNpcId = turnInNpcId
    }
}
