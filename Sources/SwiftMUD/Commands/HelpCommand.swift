import Foundation

final class HelpCommand: Command {
    static let name = "help"
    static let aliases = ["h", "?", "幫助"]
    static let description = "顯示指令說明"
    static let usage = "help [指令名稱]"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        if let commandName = context.args.first {
            // 顯示特定指令的說明
            showCommandHelp(commandName: commandName, context: context)
        } else {
            // 顯示所有指令列表
            showAllCommands(context: context)
        }

        return .success(message: nil)
    }

    private func showAllCommands(context: CommandContext) {
        let commands = CommandParser.shared.getAllCommands()

        var lines: [String] = []
        lines.append("===== 可用指令 =====")

        for cmd in commands {
            lines.append("  \(cmd.name) - \(cmd.description)")
        }

        lines.append("")
        lines.append("輸入 help <指令名稱> 查看詳細用法")
        lines.append("====================")

        context.session.sendLines(lines)
    }

    private func showCommandHelp(commandName: String, context: CommandContext) {
        let commands = CommandParser.shared.getAllCommands()

        if let cmd = commands.first(where: { $0.name.lowercased() == commandName.lowercased() }) {
            var lines: [String] = []
            lines.append("===== \(cmd.name) =====")
            lines.append("說明：\(cmd.description)")
            lines.append("用法：\(cmd.usage)")
            lines.append("====================")
            context.session.sendLines(lines)
        } else {
            context.session.send("找不到指令：\(commandName)")
        }
    }
}
