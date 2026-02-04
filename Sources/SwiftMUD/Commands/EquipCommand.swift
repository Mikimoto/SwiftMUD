import Foundation

/// 裝備物品指令
final class EquipCommand: Command {
    static let name = "equip"
    static let aliases = ["裝備", "wear", "wield"]
    static let description = "裝備物品"
    static let usage = "equip <物品名稱>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            // 顯示目前裝備
            return showEquipment(context: context)
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

        // 檢查是否可裝備
        guard let slot = template.equipSlot else {
            context.session.send("這個物品無法裝備。")
            return .success(message: nil)
        }

        // 檢查等級需求
        guard player.level >= template.levelRequired else {
            return .failure(error: .levelTooLow(required: template.levelRequired, has: player.level))
        }

        // 從背包移除
        guard player.inventory.removeItem(itemId) else {
            return .failure(error: .itemNotFound(id: itemId))
        }

        // 如果該欄位已有裝備，放回背包
        if let previousItemId = player.equip(itemId: itemId, slot: slot) {
            if let prevTemplate = World.shared.itemTemplates[previousItemId] {
                _ = player.inventory.addItem(previousItemId, stackable: prevTemplate.stackable)
                context.session.send("卸下了 \(prevTemplate.name)。")
            }
        }

        World.shared.updatePlayer(player)
        context.session.send("裝備了 \(template.name)。")

        return .success(message: nil)
    }

    private func showEquipment(context: CommandContext) -> CommandResult {
        let player = context.player

        var lines = ["===== 裝備 ====="]

        for slot in EquipmentSlot.allCases {
            let slotName = slotDisplayName(slot)
            if let itemId = player.equipment[slot],
               let template = World.shared.itemTemplates[itemId] {
                lines.append("  \(slotName): \(template.name)")
            } else {
                lines.append("  \(slotName): （空）")
            }
        }

        lines.append("")
        lines.append("總攻擊力: \(player.totalAttack())  總防禦力: \(player.totalDefense())")
        lines.append("================")

        context.session.sendLines(lines)
        return .success(message: nil)
    }

    private func slotDisplayName(_ slot: EquipmentSlot) -> String {
        switch slot {
        case .head: return "頭部"
        case .body: return "身體"
        case .hands: return "手部"
        case .legs: return "腿部"
        case .feet: return "腳部"
        case .mainHand: return "主手"
        case .offHand: return "副手"
        case .accessory1: return "飾品1"
        case .accessory2: return "飾品2"
        }
    }
}
