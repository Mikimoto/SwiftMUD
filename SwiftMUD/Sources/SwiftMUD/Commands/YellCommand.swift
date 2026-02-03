import Foundation

final class YellCommand: Command {
    static let name = "yell"
    static let aliases = ["喊", "shout"]
    static let description = "全服廣播喊話"
    static let usage = "yell <訊息>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "訊息"))
        }

        let player = context.player

        // 檢查是否被禁言
        if player.isMuted {
            if let mutedUntil = player.mutedUntil, mutedUntil > Date() {
                return .failure(error: .accountMuted(until: mutedUntil))
            } else if player.mutedUntil == nil {
                return .failure(error: .accountMuted(until: nil))
            }
        }

        let message = context.args.joined(separator: " ")

        // 全服廣播
        SessionManager.shared.broadcastGlobal(
            "【全服】\(player.name) 大喊：「\(message)」",
            except: player.id
        )

        // 發送確認給自己
        context.session.send("你大喊：「\(message)」")

        return .success(message: nil)
    }
}
