import Foundation

/// 卸下裝備指令
final class UnequipCommand: Command {
    static let name = "unequip"
    static let aliases = ["卸下", "remove"]
    static let description = "卸下裝備"
    static let usage = "unequip <裝備欄位>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "裝備欄位"))
        }

        let slotName = context.args[0].lowercased()

        guard let slot = parseSlot(slotName) else {
            context.session.send("無效的裝備欄位。可用：head, body, hands, legs, feet, mainhand, offhand, accessory1, accessory2")
            return .success(message: nil)
        }

        guard var player = World.shared.getPlayer(byId: context.playerId) else {
            return .failure(error: .playerNotFound(name: "unknown"))
        }

        guard let itemId = player.unequip(slot: slot) else {
            context.session.send("該欄位沒有裝備。")
            return .success(message: nil)
        }

        // 放回背包
        if let template = World.shared.itemTemplates[itemId] {
            if player.inventory.addItem(itemId, stackable: template.stackable) {
                context.session.send("卸下了 \(template.name)，放入背包。")
            } else {
                // 背包滿了，重新裝備
                _ = player.equip(itemId: itemId, slot: slot)
                context.session.send("背包已滿，無法卸下裝備。")
                return .success(message: nil)
            }
        }

        World.shared.updatePlayer(player)
        return .success(message: nil)
    }

    private func parseSlot(_ input: String) -> EquipmentSlot? {
        switch input {
        case "head", "頭", "頭部": return .head
        case "body", "身體", "軀幹": return .body
        case "hands", "手", "手部": return .hands
        case "legs", "腿", "腿部": return .legs
        case "feet", "腳", "腳部": return .feet
        case "mainhand", "main", "主手": return .mainHand
        case "offhand", "off", "副手": return .offHand
        case "accessory1", "acc1", "飾品1": return .accessory1
        case "accessory2", "acc2", "飾品2": return .accessory2
        default: return nil
        }
    }
}
