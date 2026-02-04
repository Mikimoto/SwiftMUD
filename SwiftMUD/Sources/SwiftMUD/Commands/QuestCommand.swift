import Foundation

/// 任務查看指令
final class QuestCommand: Command {
    static let name = "quest"
    static let aliases = ["任務", "quests", "q"]
    static let description = "查看任務列表和進度"
    static let usage = "quest [active|available|<任務ID>]"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player

        if context.args.isEmpty {
            // 顯示進行中的任務
            return showActiveQuests(context: context)
        }

        let subcommand = context.args[0].lowercased()

        switch subcommand {
        case "active", "進行中":
            return showActiveQuests(context: context)
        case "available", "可接取", "list":
            return showAvailableQuests(context: context, player: player)
        default:
            // 顯示特定任務詳情
            return showQuestDetail(context: context, questId: context.args[0])
        }
    }

    private func showActiveQuests(context: CommandContext) -> CommandResult {
        let activeQuests = QuestManager.shared.getActiveQuests(for: context.playerId)

        if activeQuests.isEmpty {
            context.session.send("你目前沒有進行中的任務。輸入 quest available 查看可接取的任務。")
            return .success(message: nil)
        }

        var lines = ["===== 進行中的任務 ====="]

        for progress in activeQuests {
            guard let quest = QuestManager.shared.getQuest(progress.questId) else { continue }

            let statusIcon = progress.allObjectivesComplete ? "✓" : "○"
            lines.append("\(statusIcon) [\(quest.id)] \(quest.name)")

            // 顯示目標進度
            for objProgress in progress.objectives {
                lines.append("   \(objProgress.progressDescription)")
            }
        }

        lines.append("=========================")
        lines.append("輸入 quest <任務ID> 查看詳情")

        context.session.sendLines(lines)
        return .success(message: nil)
    }

    private func showAvailableQuests(context: CommandContext, player: Player) -> CommandResult {
        let availableQuests = QuestManager.shared.getAvailableQuests(for: player)

        if availableQuests.isEmpty {
            context.session.send("目前沒有可接取的任務。")
            return .success(message: nil)
        }

        var lines = ["===== 可接取的任務 ====="]

        for quest in availableQuests {
            var info = "[\(quest.id)] \(quest.name)"
            if quest.levelRequired > 1 {
                info += " (需要等級 \(quest.levelRequired))"
            }
            lines.append(info)
        }

        lines.append("=========================")
        lines.append("輸入 accept <任務ID> 接取任務")

        context.session.sendLines(lines)
        return .success(message: nil)
    }

    private func showQuestDetail(context: CommandContext, questId: String) -> CommandResult {
        // 先檢查是否是進行中的任務
        if let progress = QuestManager.shared.getQuestProgress(playerId: context.playerId, questId: questId),
           let quest = QuestManager.shared.getQuest(questId) {
            var lines = ["===== \(quest.name) ====="]
            lines.append(quest.description)
            lines.append("")
            lines.append("【目標】")
            for objProgress in progress.objectives {
                lines.append("  \(objProgress.progressDescription)")
            }
            lines.append("")
            lines.append("【獎勵】\(quest.rewards.description())")

            if progress.allObjectivesComplete {
                lines.append("")
                lines.append("✓ 任務目標已完成！輸入 complete \(questId) 領取獎勵。")
            }

            context.session.sendLines(lines)
            return .success(message: nil)
        }

        // 檢查是否是可接取的任務
        if let quest = QuestManager.shared.getQuest(questId) {
            var lines = ["===== \(quest.name) ====="]
            lines.append(quest.description)
            lines.append("")
            lines.append("【目標】")
            for objective in quest.objectives {
                lines.append("  \(objective.description)")
            }
            lines.append("")
            lines.append("【獎勵】\(quest.rewards.description())")
            if quest.levelRequired > 1 {
                lines.append("【需求等級】\(quest.levelRequired)")
            }
            if !quest.prerequisites.isEmpty {
                lines.append("【前置任務】\(quest.prerequisites.joined(separator: ", "))")
            }
            lines.append("")
            lines.append("輸入 accept \(questId) 接取此任務")

            context.session.sendLines(lines)
            return .success(message: nil)
        }

        return .failure(error: .questNotFound(id: questId))
    }
}
