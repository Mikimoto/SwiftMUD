import Foundation

/// 放棄任務指令
final class AbandonCommand: Command {
    static let name = "abandon"
    static let aliases = ["放棄", "取消任務"]
    static let description = "放棄進行中的任務"
    static let usage = "abandon <任務ID>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "任務ID"))
        }

        let questId = context.args[0]

        let result = QuestManager.shared.abandonQuest(
            playerId: context.playerId,
            questId: questId
        )

        switch result {
        case .success:
            guard let quest = QuestManager.shared.getQuest(questId) else {
                context.session.send("已放棄任務。")
                return .success(message: nil)
            }

            context.session.send("已放棄任務：\(quest.name)")
            return .success(message: nil)

        case .failure(let error):
            return .failure(error: error)
        }
    }
}
