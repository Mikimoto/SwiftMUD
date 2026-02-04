import Foundation

/// 禁言玩家指令
final class MuteCommand: Command {
    static let name = "mute"
    static let aliases = ["禁言"]
    static let description = "禁止玩家發言"
    static let usage = "mute <玩家名稱> [時長(分鐘)]"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 1 else {
            return .failure(error: .invalidArguments(expected: "mute <玩家名稱> [時長]"))
        }

        let targetName = context.args[0]
        let duration = context.args.count > 1 ? Int(context.args[1]) : nil

        guard var targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        // 不能禁言比自己權限高的玩家
        if targetPlayer.adminLevel >= context.player.adminLevel {
            return .failure(error: .permissionDenied(required: targetPlayer.adminLevel))
        }

        // 設定禁言狀態
        targetPlayer.isMuted = true
        if let minutes = duration {
            targetPlayer.muteExpiry = Date().addingTimeInterval(TimeInterval(minutes * 60))
        } else {
            targetPlayer.muteExpiry = nil
        }
        World.shared.updatePlayer(targetPlayer)

        // 通知目標玩家
        if let targetSession = SessionManager.shared.getSession(byPlayerId: targetPlayer.id) {
            let durationText = duration.map { "\($0) 分鐘" } ?? "無限期"
            targetSession.send("你已被管理員 \(context.player.name) 禁言。時長: \(durationText)")
        }

        let durationText = duration.map { "\($0) 分鐘" } ?? "無限期"
        return .success(message: "已禁言玩家 \(targetName)。時長: \(durationText)")
    }
}

/// 解除禁言指令
final class UnmuteCommand: Command {
    static let name = "unmute"
    static let aliases = ["解除禁言"]
    static let description = "解除玩家禁言"
    static let usage = "unmute <玩家名稱>"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 1 else {
            return .failure(error: .invalidArguments(expected: "unmute <玩家名稱>"))
        }

        let targetName = context.args[0]

        guard var targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        if !targetPlayer.isMuted {
            return .failure(error: .custom("玩家 \(targetName) 未被禁言"))
        }

        targetPlayer.isMuted = false
        targetPlayer.muteExpiry = nil
        World.shared.updatePlayer(targetPlayer)

        // 通知目標玩家
        if let targetSession = SessionManager.shared.getSession(byPlayerId: targetPlayer.id) {
            targetSession.send("你的禁言已被解除。")
        }

        return .success(message: "已解除玩家 \(targetName) 的禁言。")
    }
}
