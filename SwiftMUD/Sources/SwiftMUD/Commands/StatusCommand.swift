import Foundation

final class StatusCommand: Command {
    static let name = "status"
    static let aliases = ["stat", "狀態", "st"]
    static let description = "查看自己的狀態"
    static let usage = "status"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player
        let lines = [
            "===== \(player.name) 的狀態 =====",
            "等級: \(player.level)  經驗: \(player.exp)/\(player.expToNextLevel())",
            "HP: \(player.currentHP)/\(player.maxHP)  MP: \(player.currentMP)/\(player.maxMP)",
            "攻擊: \(player.baseAttack)  防禦: \(player.baseDefense)  魔力: \(player.baseMagic)",
            "金幣: \(player.gold)",
            "========================="
        ]
        context.session.sendLines(lines)
        return .success(message: nil)
    }
}
