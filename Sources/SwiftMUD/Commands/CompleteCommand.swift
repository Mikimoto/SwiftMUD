import Foundation

/// 完成任務指令
final class CompleteCommand: Command {
    static let name = "complete"
    static let aliases = ["完成", "交付", "turnin"]
    static let description = "完成任務並領取獎勵"
    static let usage = "complete <任務ID>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "任務ID"))
        }

        let questId = context.args[0]

        let result = QuestManager.shared.completeQuest(
            playerId: context.playerId,
            questId: questId
        )

        switch result {
        case .success(let rewards):
            guard let quest = QuestManager.shared.getQuest(questId) else {
                return .failure(error: .questNotFound(id: questId))
            }

            // 發放獎勵
            if var player = World.shared.getPlayer(byId: context.playerId) {
                // 經驗值
                let leveledUp = player.gainExp(rewards.exp)

                // 金幣
                player.gold += rewards.gold

                World.shared.updatePlayer(player)

                var lines = ["===== 任務完成 ====="]
                lines.append("完成任務：\(quest.name)")
                lines.append("")
                lines.append("【獲得獎勵】")
                if rewards.exp > 0 {
                    lines.append("  經驗值 +\(rewards.exp)")
                }
                if rewards.gold > 0 {
                    lines.append("  金幣 +\(rewards.gold)")
                }
                for (itemId, count) in rewards.items {
                    lines.append("  \(itemId) x\(count)")
                    // TODO: 加入物品到背包
                }
                if rewards.skillPoints > 0 {
                    lines.append("  技能點 +\(rewards.skillPoints)")
                }

                if leveledUp {
                    lines.append("")
                    lines.append("恭喜！你升級了！目前等級：\(player.level)")
                }

                lines.append("====================")

                context.session.sendLines(lines)

                // 廣播
                SessionManager.shared.broadcast(
                    "\(context.player.name) 完成了任務「\(quest.name)」！",
                    inRoom: context.player.currentRoomId,
                    except: context.playerId
                )
            }

            return .success(message: nil)

        case .failure(let error):
            return .failure(error: error)
        }
    }
}
