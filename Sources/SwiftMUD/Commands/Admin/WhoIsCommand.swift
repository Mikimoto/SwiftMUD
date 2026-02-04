import Foundation

/// 查詢玩家詳細資訊指令
final class WhoIsCommand: Command {
    static let name = "whois"
    static let aliases = ["查詢", "playerinfo"]
    static let description = "查詢玩家詳細資訊"
    static let usage = "whois <玩家名稱>"
    static let requiredAdminLevel: AdminTier = .trainee

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 1 else {
            return .failure(error: .invalidArguments(expected: "whois <玩家名稱>"))
        }

        let targetName = context.args[0]

        guard let targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        guard let targetRoom = World.shared.getRoom(targetPlayer.currentRoomId) else {
            return .failure(error: .roomNotFound(id: targetPlayer.currentRoomId))
        }

        var info = [
            "=== 玩家資訊: \(targetPlayer.name) ===",
            "ID: \(targetPlayer.id)",
            "等級: \(targetPlayer.level)",
            "職業: \(targetPlayer.playerClass)",
            "管理員等級: \(targetPlayer.adminLevel)",
            "",
            "--- 狀態 ---",
            "HP: \(targetPlayer.currentHP)/\(targetPlayer.maxHP)",
            "MP: \(targetPlayer.currentMP)/\(targetPlayer.maxMP)",
            "",
            "--- 位置 ---",
            "房間: \(targetRoom.name)（\(targetPlayer.currentRoomId)）",
            "",
            "--- 其他 ---",
            "金幣: \(targetPlayer.gold)",
            "經驗: \(targetPlayer.experience)"
        ]

        if targetPlayer.isMuted {
            let expiry = targetPlayer.muteExpiry.map { "到 \($0)" } ?? "永久"
            info.append("禁言狀態: 是（\(expiry)）")
        }

        if targetPlayer.isBanned {
            let expiry = targetPlayer.banExpiry.map { "到 \($0)" } ?? "永久"
            info.append("封禁狀態: 是（\(expiry)）")
            if let reason = targetPlayer.banReason {
                info.append("封禁原因: \(reason)")
            }
        }

        info.append("==============================")

        return .success(message: info.joined(separator: "\n"))
    }
}
