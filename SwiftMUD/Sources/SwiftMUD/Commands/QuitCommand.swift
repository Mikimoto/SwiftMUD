import Foundation

final class QuitCommand: Command {
    static let name = "quit"
    static let aliases = ["exit", "logout", "登出", "離開"]
    static let description = "離開遊戲"
    static let usage = "quit"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player

        // 通知房間內其他玩家
        SessionManager.shared.broadcast(
            "\(player.name) 離開了遊戲。",
            inRoom: player.currentRoomId,
            except: player.id
        )

        // 從世界移除玩家
        World.shared.removePlayer(player.id)

        // 發送告別訊息
        context.session.send("再見！歡迎下次再來！")

        return .quit
    }
}
