import Foundation

/// 封禁玩家指令 - 禁止玩家登入
final class BanCommand: Command {
    static let name = "ban"
    static let aliases = ["封禁", "封鎖"]
    static let description = "封禁指定玩家"
    static let usage = "ban <玩家名稱> [時長(分鐘)] [原因]"
    static let requiredAdminLevel: AdminTier = .superGM

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 1 else {
            return .failure(error: .invalidArguments(expected: "ban <玩家名稱> [時長] [原因]"))
        }

        let targetName = context.args[0]
        var duration: Int? = nil
        var reasonParts: [String] = []

        // 解析參數
        if context.args.count > 1 {
            if let minutes = Int(context.args[1]) {
                duration = minutes
                if context.args.count > 2 {
                    reasonParts = Array(context.args.dropFirst(2))
                }
            } else {
                reasonParts = Array(context.args.dropFirst())
            }
        }

        let reason = reasonParts.isEmpty ? "違規行為" : reasonParts.joined(separator: " ")

        guard let targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        // 不能封禁比自己權限高的玩家
        if targetPlayer.adminLevel >= context.player.adminLevel {
            return .failure(error: .permissionDenied(required: targetPlayer.adminLevel))
        }

        // 設定封禁狀態
        var updatedPlayer = targetPlayer
        updatedPlayer.isBanned = true
        if let minutes = duration {
            updatedPlayer.banExpiry = Date().addingTimeInterval(TimeInterval(minutes * 60))
        } else {
            updatedPlayer.banExpiry = nil  // 永久封禁
        }
        updatedPlayer.banReason = reason
        World.shared.updatePlayer(updatedPlayer)

        // 如果玩家在線上，踢除他
        if let targetSession = SessionManager.shared.getSession(byPlayerId: targetPlayer.id) {
            let durationText = duration.map { "\($0) 分鐘" } ?? "永久"
            targetSession.send("你已被封禁。時長: \(durationText)，原因: \(reason)")
            targetSession.close()
        }

        World.shared.removePlayer(targetPlayer.id)

        let durationText = duration.map { "\($0) 分鐘" } ?? "永久"
        SessionManager.shared.broadcast("【系統公告】玩家 \(targetName) 已被封禁（\(durationText)）。")

        return .success(message: "已封禁玩家 \(targetName)。時長: \(durationText)，原因: \(reason)")
    }
}
