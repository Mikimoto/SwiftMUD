import Foundation

/// 任務狀態
enum QuestStatus: String, Codable {
    case available    // 可接取
    case active       // 進行中
    case completed    // 已完成（可交付）
    case turnedIn     // 已交付（獲得獎勵）
    case failed       // 失敗
}

/// 單個目標的進度
struct ObjectiveProgress: Codable {
    let objective: QuestObjective
    var currentCount: Int

    var isComplete: Bool {
        switch objective {
        case .kill(_, let count), .collect(_, let count), .useItem(_, let count):
            return currentCount >= count
        case .visit, .talkTo:
            return currentCount >= 1
        case .reachLevel(let level):
            return currentCount >= level
        case .learnSkill:
            return currentCount >= 1
        }
    }

    var requiredCount: Int {
        switch objective {
        case .kill(_, let count), .collect(_, let count), .useItem(_, let count):
            return count
        case .visit, .talkTo, .learnSkill:
            return 1
        case .reachLevel(let level):
            return level
        }
    }

    var progressDescription: String {
        switch objective {
        case .kill(let monsterId, let count):
            return "擊殺 \(monsterId) (\(currentCount)/\(count))"
        case .collect(let itemId, let count):
            return "收集 \(itemId) (\(currentCount)/\(count))"
        case .visit(let roomId):
            let status = isComplete ? "✓" : "○"
            return "\(status) 前往 \(roomId)"
        case .talkTo(let npcId):
            let status = isComplete ? "✓" : "○"
            return "\(status) 與 \(npcId) 對話"
        case .useItem(let itemId, let count):
            return "使用 \(itemId) (\(currentCount)/\(count))"
        case .reachLevel(let level):
            return "達到等級 \(level) (\(currentCount)/\(level))"
        case .learnSkill(let skillId):
            let status = isComplete ? "✓" : "○"
            return "\(status) 學習技能 \(skillId)"
        }
    }

    init(objective: QuestObjective, currentCount: Int = 0) {
        self.objective = objective
        self.currentCount = currentCount
    }
}

/// 玩家的任務進度
struct QuestProgress: Codable {
    let questId: String
    var status: QuestStatus
    var objectives: [ObjectiveProgress]
    let acceptedAt: Date
    var completedAt: Date?
    var turnedInAt: Date?

    /// 檢查所有目標是否完成
    var allObjectivesComplete: Bool {
        objectives.allSatisfy { $0.isComplete }
    }

    init(quest: Quest) {
        self.questId = quest.id
        self.status = .active
        self.objectives = quest.objectives.map { ObjectiveProgress(objective: $0) }
        self.acceptedAt = Date()
        self.completedAt = nil
        self.turnedInAt = nil
    }

    /// 更新擊殺目標進度
    mutating func updateKillProgress(monsterId: String, count: Int = 1) {
        for i in objectives.indices {
            if case .kill(let targetId, _) = objectives[i].objective,
               targetId == monsterId {
                objectives[i].currentCount += count
            }
        }
        checkCompletion()
    }

    /// 更新收集目標進度
    mutating func updateCollectProgress(itemId: String, count: Int = 1) {
        for i in objectives.indices {
            if case .collect(let targetId, _) = objectives[i].objective,
               targetId == itemId {
                objectives[i].currentCount += count
            }
        }
        checkCompletion()
    }

    /// 更新訪問目標進度
    mutating func updateVisitProgress(roomId: String) {
        for i in objectives.indices {
            if case .visit(let targetId) = objectives[i].objective,
               targetId == roomId {
                objectives[i].currentCount = 1
            }
        }
        checkCompletion()
    }

    /// 更新對話目標進度
    mutating func updateTalkProgress(npcId: String) {
        for i in objectives.indices {
            if case .talkTo(let targetId) = objectives[i].objective,
               targetId == npcId {
                objectives[i].currentCount = 1
            }
        }
        checkCompletion()
    }

    /// 更新使用物品目標進度
    mutating func updateUseItemProgress(itemId: String, count: Int = 1) {
        for i in objectives.indices {
            if case .useItem(let targetId, _) = objectives[i].objective,
               targetId == itemId {
                objectives[i].currentCount += count
            }
        }
        checkCompletion()
    }

    /// 更新等級目標進度
    mutating func updateLevelProgress(level: Int) {
        for i in objectives.indices {
            if case .reachLevel = objectives[i].objective {
                objectives[i].currentCount = level
            }
        }
        checkCompletion()
    }

    /// 更新技能學習目標進度
    mutating func updateSkillProgress(skillId: String) {
        for i in objectives.indices {
            if case .learnSkill(let targetId) = objectives[i].objective,
               targetId == skillId {
                objectives[i].currentCount = 1
            }
        }
        checkCompletion()
    }

    /// 檢查是否完成
    private mutating func checkCompletion() {
        if allObjectivesComplete && status == .active {
            status = .completed
            completedAt = Date()
        }
    }
}
