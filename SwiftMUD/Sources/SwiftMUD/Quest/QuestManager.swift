import Foundation
import Logging

/// 任務管理器
final class QuestManager {
    static let shared = QuestManager()

    /// 所有任務定義 (questId -> Quest)
    private(set) var quests: [String: Quest] = [:]

    /// 玩家的任務進度 (playerId -> [questId -> QuestProgress])
    private var playerQuests: [UUID: [String: QuestProgress]] = [:]

    /// 玩家已完成的任務 (playerId -> Set<questId>)
    private var completedQuests: [UUID: Set<String>] = [:]

    /// 可重複任務的冷卻 (playerId -> [questId -> nextAvailableTime])
    private var questCooldowns: [UUID: [String: Date]] = [:]

    private let lock = NSLock()
    private var logger = Logger(label: "com.swiftmud.quest")

    private init() {
        loadInitialQuests()
    }

    // MARK: - Quest Registry

    func registerQuest(_ quest: Quest) {
        lock.lock()
        defer { lock.unlock() }
        quests[quest.id] = quest
    }

    func getQuest(_ questId: String) -> Quest? {
        lock.lock()
        defer { lock.unlock() }
        return quests[questId]
    }

    // MARK: - Player Quest Operations

    /// 取得玩家可接取的任務列表
    func getAvailableQuests(for player: Player) -> [Quest] {
        lock.lock()
        defer { lock.unlock() }

        let activeQuestIds: Set<String>
        if let keys = playerQuests[player.id]?.keys {
            activeQuestIds = Set(keys)
        } else {
            activeQuestIds = []
        }
        let completed = completedQuests[player.id] ?? []
        let cooldowns = questCooldowns[player.id] ?? [:]

        return quests.values.filter { quest in
            // 檢查等級需求
            guard player.level >= quest.levelRequired else { return false }

            // 檢查是否已接取
            guard !activeQuestIds.contains(quest.id) else { return false }

            // 檢查前置任務
            guard quest.prerequisites.allSatisfy({ completed.contains($0) }) else { return false }

            // 檢查是否可重複
            if quest.type == .single && completed.contains(quest.id) {
                return false
            }

            // 檢查冷卻
            if let cooldownEnd = cooldowns[quest.id], Date() < cooldownEnd {
                return false
            }

            return true
        }
    }

    /// 取得玩家進行中的任務列表
    func getActiveQuests(for playerId: UUID) -> [QuestProgress] {
        lock.lock()
        defer { lock.unlock() }
        if let values = playerQuests[playerId]?.values {
            return Array(values)
        } else {
            return []
        }
    }

    /// 取得玩家特定任務的進度
    func getQuestProgress(playerId: UUID, questId: String) -> QuestProgress? {
        lock.lock()
        defer { lock.unlock() }
        return playerQuests[playerId]?[questId]
    }

    /// 接受任務
    func acceptQuest(playerId: UUID, questId: String, player: Player) -> Result<QuestProgress, MUDError> {
        lock.lock()
        defer { lock.unlock() }

        guard let quest = quests[questId] else {
            return .failure(.questNotFound(id: questId))
        }

        // 檢查等級
        guard player.level >= quest.levelRequired else {
            return .failure(.levelTooLow(required: quest.levelRequired, has: player.level))
        }

        // 檢查是否已接取
        if playerQuests[playerId]?[questId] != nil {
            return .failure(.questAlreadyActive(id: questId))
        }

        // 檢查前置任務
        let completed = completedQuests[playerId] ?? []
        for prereq in quest.prerequisites {
            if !completed.contains(prereq) {
                return .failure(.questPrerequisiteNotMet(required: prereq))
            }
        }

        // 檢查冷卻
        if let cooldownEnd = questCooldowns[playerId]?[questId], Date() < cooldownEnd {
            let remaining = cooldownEnd.timeIntervalSinceNow
            return .failure(.questOnCooldown(remaining: remaining))
        }

        // 建立任務進度
        let progress = QuestProgress(quest: quest)

        if playerQuests[playerId] == nil {
            playerQuests[playerId] = [:]
        }
        playerQuests[playerId]?[questId] = progress

        logger.info("Player \(playerId) accepted quest: \(questId)")
        return .success(progress)
    }

    /// 完成任務並領取獎勵
    func completeQuest(playerId: UUID, questId: String) -> Result<QuestRewards, MUDError> {
        lock.lock()
        defer { lock.unlock() }

        guard let quest = quests[questId] else {
            return .failure(.questNotFound(id: questId))
        }

        guard var progress = playerQuests[playerId]?[questId] else {
            return .failure(.questNotActive(id: questId))
        }

        guard progress.allObjectivesComplete else {
            return .failure(.questObjectiveNotComplete)
        }

        // 更新狀態
        progress.status = .turnedIn
        progress.turnedInAt = Date()

        // 從進行中移除
        playerQuests[playerId]?.removeValue(forKey: questId)

        // 加入已完成列表
        if completedQuests[playerId] == nil {
            completedQuests[playerId] = []
        }
        completedQuests[playerId]?.insert(questId)

        // 設定冷卻（如果是可重複任務）
        if quest.type == .repeatable, let cooldown = quest.cooldown {
            if questCooldowns[playerId] == nil {
                questCooldowns[playerId] = [:]
            }
            questCooldowns[playerId]?[questId] = Date().addingTimeInterval(cooldown)
        }

        logger.info("Player \(playerId) completed quest: \(questId)")
        return .success(quest.rewards)
    }

    /// 放棄任務
    func abandonQuest(playerId: UUID, questId: String) -> Result<Void, MUDError> {
        lock.lock()
        defer { lock.unlock() }

        guard playerQuests[playerId]?[questId] != nil else {
            return .failure(.questNotActive(id: questId))
        }

        playerQuests[playerId]?.removeValue(forKey: questId)
        logger.info("Player \(playerId) abandoned quest: \(questId)")
        return .success(())
    }

    // MARK: - Progress Updates

    /// 更新玩家的擊殺進度
    func updateKillProgress(playerId: UUID, monsterId: String) {
        lock.lock()
        defer { lock.unlock() }

        guard var quests = playerQuests[playerId] else { return }

        for (questId, var progress) in quests {
            progress.updateKillProgress(monsterId: monsterId)
            quests[questId] = progress
        }

        playerQuests[playerId] = quests
    }

    /// 更新玩家的收集進度
    func updateCollectProgress(playerId: UUID, itemId: String) {
        lock.lock()
        defer { lock.unlock() }

        guard var quests = playerQuests[playerId] else { return }

        for (questId, var progress) in quests {
            progress.updateCollectProgress(itemId: itemId)
            quests[questId] = progress
        }

        playerQuests[playerId] = quests
    }

    /// 更新玩家的訪問進度
    func updateVisitProgress(playerId: UUID, roomId: String) {
        lock.lock()
        defer { lock.unlock() }

        guard var quests = playerQuests[playerId] else { return }

        for (questId, var progress) in quests {
            progress.updateVisitProgress(roomId: roomId)
            quests[questId] = progress
        }

        playerQuests[playerId] = quests
    }

    // MARK: - Initial Data

    private func loadInitialQuests() {
        // 新手任務
        let tutorial1 = Quest(
            id: "tutorial_explore",
            name: "探索城鎮",
            description: "熟悉一下這個城鎮吧！去市場和酒館看看。",
            objectives: [
                .visit(roomId: "market"),
                .visit(roomId: "tavern")
            ],
            rewards: QuestRewards(exp: 20, gold: 50)
        )

        let tutorial2 = Quest(
            id: "tutorial_combat",
            name: "初次戰鬥",
            description: "是時候學習戰鬥了！去城外的平原消滅幾隻史萊姆。",
            objectives: [
                .kill(monsterId: "slime", count: 3)
            ],
            rewards: QuestRewards(exp: 50, gold: 100, items: ["health_potion": 3]),
            prerequisites: ["tutorial_explore"]
        )

        // 主線任務
        let mainQuest1 = Quest(
            id: "wolf_threat",
            name: "野狼威脅",
            description: "森林入口的野狼數量增加了，獵人公會希望你幫忙清理一下。",
            objectives: [
                .kill(monsterId: "wolf", count: 5),
                .collect(itemId: "wolf_pelt", count: 2)
            ],
            rewards: QuestRewards(exp: 150, gold: 200, items: ["iron_sword": 1]),
            prerequisites: ["tutorial_combat"],
            levelRequired: 2
        )

        // 可重複任務
        let dailySlime = Quest(
            id: "daily_slime",
            name: "【日常】清理史萊姆",
            description: "史萊姆又來了！每天都有新的史萊姆冒出來。",
            type: .repeatable,
            objectives: [
                .kill(monsterId: "slime", count: 5)
            ],
            rewards: QuestRewards(exp: 30, gold: 50),
            prerequisites: ["tutorial_combat"],
            cooldown: 86400 // 24 小時
        )

        quests = [
            tutorial1.id: tutorial1,
            tutorial2.id: tutorial2,
            mainQuest1.id: mainQuest1,
            dailySlime.id: dailySlime
        ]
    }
}
