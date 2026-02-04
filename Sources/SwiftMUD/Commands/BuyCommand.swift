import Foundation

/// 購買物品指令
final class BuyCommand: Command {
    static let name = "buy"
    static let aliases = ["購買", "買"]
    static let description = "從商店購買物品"
    static let usage = "buy <物品名稱> [數量]"

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

        // 尋找物品
        var foundItemId: String?
        for itemId in shop.itemIds {
            if let template = World.shared.itemTemplates[itemId],
               template.name.lowercased().contains(itemName) || itemId.lowercased().contains(itemName) {
                foundItemId = itemId
                break
            }
        }

        guard let itemId = foundItemId else {
            context.session.send("商店沒有販售這個物品。")
            return .success(message: nil)
        }

        let result = ShopManager.shared.buyItem(
            playerId: context.playerId,
            itemId: itemId,
            count: count,
            shopId: shop.id
        )

        switch result {
        case .success(let (item, totalCost)):
            var message = "購買了 \(item.name)"
            if count > 1 {
                message += " x\(count)"
            }
            message += "，花費 \(totalCost) 金幣。"
            context.session.send(message)

        case .failure(let error):
            return .failure(error: error)
        }

        return .success(message: nil)
    }
}
