import Foundation

final class SayCommand: Command {
    static let name = "say"
    static let aliases = ["說", "'"]
    static let description = "在房間內說話"
    static let usage = "say <訊息>"

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

        // 廣播給房間內其他玩家
        SessionManager.shared.broadcast(
            "\(player.name) 說：「\(message)」",
            inRoom: player.currentRoomId,
            except: player.id
        )

        // 發送確認給自己
        context.session.send("你說：「\(message)」")

        return .success(message: nil)
    }
}
