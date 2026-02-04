import Foundation

/// 背包查看指令
final class InventoryCommand: Command {
    static let name = "inventory"
    static let aliases = ["inv", "i", "背包", "物品"]
    static let description = "查看背包內容"
    static let usage = "inventory"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player
        let inventory = player.inventory

        var lines = ["===== 背包 (\(inventory.usedSlots)/\(inventory.maxSlots)) ====="]

        if inventory.items.isEmpty {
            lines.append("背包是空的。")
        } else {
            for item in inventory.items {
                if let template = World.shared.itemTemplates[item.templateId] {
                    var itemLine = "\(template.name)"
                    if item.count > 1 {
                        itemLine += " x\(item.count)"
                    }
                    lines.append("  \(itemLine)")
                } else {
                    lines.append("  \(item.templateId) x\(item.count)")
                }
            }
        }

        lines.append("")
        lines.append("金幣：\(player.gold)")
        lines.append("=============================")

        context.session.sendLines(lines)
        return .success(message: nil)
    }
}
