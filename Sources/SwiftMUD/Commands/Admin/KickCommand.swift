import Foundation

/// 踢除玩家指令 - 強制中斷玩家連線
final class KickCommand: Command {
    static let name = "kick"
    static let aliases = ["踢除"]
    static let description = "踢除指定玩家"
    static let usage = "kick <玩家名稱> [原因]"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 1 else {
            return .failure(error: .invalidArguments(expected: "kick <玩家名稱> [原因]"))
        }

        let targetName = context.args[0]
        let reason = context.args.count > 1 ? context.args.dropFirst().joined(separator: " ") : "違規行為"

        guard let targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        // 不能踢除比自己權限高的玩家
        if targetPlayer.adminLevel >= context.player.adminLevel {
            return .failure(error: .permissionDenied(required: targetPlayer.adminLevel))
        }

        // 找到目標玩家的 Session 並斷開連線
        if let targetSession = SessionManager.shared.getSession(byPlayerId: targetPlayer.id) {
            targetSession.send("你被管理員 \(context.player.name) 踢出遊戲。原因: \(reason)")
            targetSession.close()
        }

        // 從世界移除玩家
        World.shared.removePlayer(targetPlayer.id)

        // 廣播訊息
        SessionManager.shared.broadcast("【系統公告】玩家 \(targetName) 已被踢出遊戲。")

        return .success(message: "已踢除玩家 \(targetName)。原因: \(reason)")
    }
}
