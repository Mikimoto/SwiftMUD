import Foundation

/// 商店查看指令
final class ShopCommand: Command {
    static let name = "shop"
    static let aliases = ["商店", "store", "list"]
    static let description = "查看商店物品"
    static let usage = "shop"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player

        // 尋找房間內的商店
        guard let shop = ShopManager.shared.getShopInRoom(player.currentRoomId) else {
            context.session.send("這裡沒有商店。")
            return .success(message: nil)
        }

        var lines = ["===== \(shop.name) ====="]
        lines.append(shop.description)
        lines.append("")
        lines.append("【販售物品】")

        for itemId in shop.itemIds {
            if let item = World.shared.itemTemplates[itemId] {
                let price = shop.buyPrice(for: item)
                lines.append("  \(item.name) - \(price) 金幣")
            }
        }

        lines.append("")
        lines.append("你的金幣：\(player.gold)")
        lines.append("========================")
        lines.append("輸入 buy <物品名稱> 購買")
        lines.append("輸入 sell <物品名稱> 販賣")

        context.session.sendLines(lines)
        return .success(message: nil)
    }
}
