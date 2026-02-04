import Foundation

/// 系統公告指令
final class AnnounceCommand: Command {
    static let name = "announce"
    static let aliases = ["公告", "broadcast"]
    static let description = "發送系統公告給所有玩家"
    static let usage = "announce <訊息>"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .invalidArguments(expected: "announce <訊息>"))
        }

        let message = context.args.joined(separator: " ")
        let announcement = """

        ╔══════════════════════════════════════╗
        ║          【 系統公告 】              ║
        ╠══════════════════════════════════════╣
        ║ \(message)
        ╚══════════════════════════════════════╝

        """

        SessionManager.shared.broadcast(announcement)

        return .success(message: "公告已發送: \(message)")
    }
}
