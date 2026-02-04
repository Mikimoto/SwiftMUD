import Foundation

/// 販賣物品指令
final class SellCommand: Command {
    static let name = "sell"
    static let aliases = ["販賣", "賣"]
    static let description = "向商店販賣物品"
    static let usage = "sell <物品名稱> [數量]"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "物品名稱"))
        }

        let player = context.player

        // 尋找房間內的商店
        guard let shop = ShopManager.shared.getShopInRoom(player.currentRoomId) else {
            context.session.send("這裡沒有商店。")
            return .success(message: nil)
        }

        // 解析物品名稱和數量
        var itemName = context.args[0].lowercased()
        var count = 1

        if context.args.count > 1, let parsedCount = Int(context.args.last!) {
            count = max(1, parsedCount)
            itemName = context.args.dropLast().joined(separator: " ").lowercased()
        }

        // 尋找背包中的物品
        var foundItemId: String?
        for item in player.inventory.items {
            if let template = World.shared.itemTemplates[item.templateId],
               template.name.lowercased().contains(itemName) || item.templateId.lowercased().contains(itemName) {
                foundItemId = item.templateId
                break
            }
        }

        guard let itemId = foundItemId else {
            context.session.send("你沒有這個物品。")
            return .success(message: nil)
        }

        // 檢查商店是否收購
        guard shop.buys(itemId) else {
            context.session.send("商店不收購這個物品。")
            return .success(message: nil)
        }

        let result = ShopManager.shared.sellItem(
            playerId: context.playerId,
            itemId: itemId,
            count: count,
            shopId: shop.id
        )

        switch result {
        case .success(let (item, totalEarned)):
            var message = "販賣了 \(item.name)"
            if count > 1 {
                message += " x\(count)"
            }
            message += "，獲得 \(totalEarned) 金幣。"
            context.session.send(message)

        case .failure(let error):
            return .failure(error: error)
        }

        return .success(message: nil)
    }
}
