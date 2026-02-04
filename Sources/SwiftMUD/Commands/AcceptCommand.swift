import Foundation

/// 接受任務指令
final class AcceptCommand: Command {
    static let name = "accept"
    static let aliases = ["接受", "接取"]
    static let description = "接受任務"
    static let usage = "accept <任務ID>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "任務ID"))
        }

        let questId = context.args[0]
        let player = context.player

        let result = QuestManager.shared.acceptQuest(
            playerId: context.playerId,
            questId: questId,
            player: player
        )

        switch result {
        case .success(let progress):
            guard let quest = QuestManager.shared.getQuest(questId) else {
                return .failure(error: .questNotFound(id: questId))
            }

            var lines = ["接受任務：\(quest.name)"]
            lines.append("")
            lines.append("【目標】")
            for objProgress in progress.objectives {
                lines.append("  \(objProgress.progressDescription)")
            }
            lines.append("")
            lines.append("輸入 quest \(questId) 查看詳細進度")

            context.session.sendLines(lines)

            // 廣播給同房間的玩家
            SessionManager.shared.broadcast(
                "\(player.name) 接受了任務「\(quest.name)」",
                inRoom: player.currentRoomId,
                except: player.id
            )

            return .success(message: nil)

        case .failure(let error):
            return .failure(error: error)
        }
    }
}
