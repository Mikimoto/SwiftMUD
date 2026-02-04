import Foundation

/// 列出所有管理員指令
final class AdminListCommand: Command {
    static let name = "adminlist"
    static let aliases = ["管理員列表", "admins"]
    static let description = "列出所有在線管理員"
    static let usage = "adminlist"
    static let requiredAdminLevel: AdminTier = .trainee

    func execute(context: CommandContext) -> CommandResult {
        let allPlayers = World.shared.players.values
        let admins = allPlayers.filter { $0.adminLevel > .player }.sorted { $0.adminLevel > $1.adminLevel }

        if admins.isEmpty {
            return .success(message: "目前沒有管理員在線上。")
        }

        var lines = ["=== 在線管理員 ==="]
        for admin in admins {
            let status = admin.isAFK ? "[AFK]" : ""
            lines.append("[\(admin.adminLevel)] \(admin.name) \(status)")
        }
        lines.append("===================")
        lines.append("共 \(admins.count) 位管理員在線")

        return .success(message: lines.joined(separator: "\n"))
    }
}
