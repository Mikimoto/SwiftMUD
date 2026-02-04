import Foundation

/// 使用物品指令
final class UseCommand: Command {
    static let name = "use"
    static let aliases = ["使用", "consume"]
    static let description = "使用消耗品"
    static let usage = "use <物品名稱>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "物品名稱"))
        }

        let itemName = context.args.joined(separator: " ").lowercased()

        guard var player = World.shared.getPlayer(byId: context.playerId) else {
            return .failure(error: .playerNotFound(name: "unknown"))
        }

        // 尋找物品
        var foundItemId: String?
        for item in player.inventory.items {
            if let template = World.shared.itemTemplates[item.templateId],
               template.name.lowercased().contains(itemName) || item.templateId.lowercased().contains(itemName) {
                foundItemId = item.templateId
                break
            }
        }

        guard let itemId = foundItemId,
              let template = World.shared.itemTemplates[itemId] else {
            return .failure(error: .itemNotFound(id: itemName))
        }

        // 檢查是否是消耗品
        guard template.type == .consumable else {
            context.session.send("這個物品無法使用。")
            return .success(message: nil)
        }

        // 移除物品
        guard player.inventory.removeItem(itemId) else {
            return .failure(error: .itemNotFound(id: itemId))
        }

        // 套用效果
        var message = "你使用了 \(template.name)。"

        // 根據物品 ID 套用效果
        switch itemId {
        case "health_potion":
            let healAmount = 50
            player.heal(healAmount)
            message += " 恢復了 \(healAmount) HP！"
        case "mana_potion":
            let manaAmount = 30
            player.currentMP = min(player.currentMP + manaAmount, player.maxMP)
            message += " 恢復了 \(manaAmount) MP！"
        default:
            message += " （效果未定義）"
        }

        World.shared.updatePlayer(player)
        context.session.send(message)

        return .success(message: nil)
    }
}
