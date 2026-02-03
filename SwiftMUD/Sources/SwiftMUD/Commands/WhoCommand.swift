import Foundation

final class WhoCommand: Command {
    static let name = "who"
    static let aliases = ["在線", "online"]
    static let description = "查看在線玩家列表"
    static let usage = "who"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let onlineCount = SessionManager.shared.onlinePlayerCount

        var lines: [String] = []
        lines.append("===== 在線玩家 =====")
        lines.append("目前在線人數：\(onlineCount)")
        lines.append("====================")

        context.session.sendLines(lines)
        return .success(message: nil)
    }
}
