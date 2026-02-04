import Foundation

/// 設定玩家管理員等級指令
final class SetAdminCommand: Command {
    static let name = "setadmin"
    static let aliases = ["設定權限", "授權"]
    static let description = "設定玩家的管理員等級"
    static let usage = "setadmin <玩家名稱> <等級>"
    static let requiredAdminLevel: AdminTier = .creator

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 2 else {
            let levels = AdminTier.allCases.map { "\($0.rawValue): \($0)" }.joined(separator: ", ")
            return .failure(error: .invalidArguments(expected: "setadmin <玩家名稱> <等級>\n可用等級: \(levels)"))
        }

        let targetName = context.args[0]
        let levelString = context.args[1]

        guard var targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        // 解析等級
        guard let level = parseAdminLevel(levelString) else {
            let levels = AdminTier.allCases.map { "\($0.rawValue): \($0)" }.joined(separator: ", ")
            return .failure(error: .custom("無效的管理員等級。可用等級: \(levels)"))
        }

        // 不能設定比自己高的等級
        if level > context.player.adminLevel {
            return .failure(error: .permissionDenied(required: level))
        }

        // 不能修改比自己等級高或相同的玩家（除非是自己）
        if targetPlayer.id != context.player.id && targetPlayer.adminLevel >= context.player.adminLevel {
            return .failure(error: .permissionDenied(required: targetPlayer.adminLevel))
        }

        let oldLevel = targetPlayer.adminLevel
        targetPlayer.adminLevel = level
        World.shared.updatePlayer(targetPlayer)

        // 通知目標玩家
        if let targetSession = SessionManager.shared.getSession(byPlayerId: targetPlayer.id) {
            targetSession.send("你的管理員等級已被設定為: \(level)")
        }

        return .success(message: "已將玩家 \(targetName) 的管理員等級從 \(oldLevel) 設定為 \(level)")
    }

    private func parseAdminLevel(_ string: String) -> AdminTier? {
        // 先嘗試用 rawValue 解析
        if let rawValue = Int(string), let level = AdminTier(rawValue: rawValue) {
            return level
        }
        // 再嘗試用名稱解析
        let lowercased = string.lowercased()
        return AdminTier.allCases.first { "\($0)".lowercased() == lowercased }
    }
}
