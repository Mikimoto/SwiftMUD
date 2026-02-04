import Foundation

/// 生成怪物或物品指令
final class SpawnCommand: Command {
    static let name = "spawn"
    static let aliases = ["生成", "創建"]
    static let description = "在當前房間生成怪物或物品"
    static let usage = "spawn monster <怪物模板ID> [數量] | spawn item <物品模板ID> [數量]"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 2 else {
            return .failure(error: .invalidArguments(expected: "spawn <monster|item> <模板ID> [數量]"))
        }

        let type = context.args[0].lowercased()
        let templateId = context.args[1]
        let count = context.args.count > 2 ? (Int(context.args[2]) ?? 1) : 1

        guard count > 0 && count <= 10 else {
            return .failure(error: .custom("生成數量必須在 1-10 之間"))
        }

        switch type {
        case "monster", "m", "怪物":
            return spawnMonster(templateId: templateId, count: count, context: context)
        case "item", "i", "物品":
            return spawnItem(templateId: templateId, count: count, context: context)
        default:
            return .failure(error: .invalidArguments(expected: "類型必須是 monster 或 item"))
        }
    }

    private func spawnMonster(templateId: String, count: Int, context: CommandContext) -> CommandResult {
        guard let template = World.shared.monsterTemplates[templateId] else {
            let availableIds = World.shared.monsterTemplates.keys.joined(separator: ", ")
            return .failure(error: .custom("找不到怪物模板: \(templateId)。可用模板: \(availableIds)"))
        }

        var spawnedMonsters: [Monster] = []
        for _ in 0..<count {
            let monster = Monster(from: template, roomId: context.player.currentRoomId)
            World.shared.addMonster(monster)
            spawnedMonsters.append(monster)
        }

        // 通知房間內的玩家
        for player in World.shared.getPlayersInRoom(context.player.currentRoomId) where player.id != context.player.id {
            if let session = SessionManager.shared.getSession(byPlayerId: player.id) {
                session.send("一陣魔法波動，\(count) 隻 \(template.name) 出現了！")
            }
        }

        return .success(message: "已生成 \(count) 隻 \(template.name)（\(templateId)）")
    }

    private func spawnItem(templateId: String, count: Int, context: CommandContext) -> CommandResult {
        guard let template = World.shared.itemTemplates[templateId] else {
            let availableIds = World.shared.itemTemplates.keys.joined(separator: ", ")
            return .failure(error: .custom("找不到物品模板: \(templateId)。可用模板: \(availableIds)"))
        }

        // 將物品添加到管理員的背包
        var updatedPlayer = context.player
        let success = updatedPlayer.inventory.addItem(templateId, count: count, stackable: template.stackable)
        if !success {
            return .failure(error: .inventoryFull)
        }
        World.shared.updatePlayer(updatedPlayer)

        return .success(message: "已將 \(count) 個 \(template.name)（\(templateId)）添加到你的背包")
    }
}
