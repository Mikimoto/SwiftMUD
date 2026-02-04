import Foundation

struct Room: Codable, Identifiable {
    let id: String
    var name: String
    var description: String

    // 連接的房間 (方向 -> 房間ID)
    var exits: [Direction: String]

    // 房間屬性
    var isSafeZone: Bool
    var canPvP: Bool
    var respawnPoint: Bool

    // 房間內的實體 ID
    var playerIds: Set<String>
    var monsterIds: Set<String>
    var itemIds: Set<String>
    var npcIds: Set<String>
    var shopId: String?

    init(
        id: String,
        name: String,
        description: String,
        exits: [Direction: String] = [:],
        isSafeZone: Bool = false,
        canPvP: Bool = true,
        respawnPoint: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.exits = exits
        self.isSafeZone = isSafeZone
        self.canPvP = canPvP
        self.respawnPoint = respawnPoint
        self.playerIds = []
        self.monsterIds = []
        self.itemIds = []
        self.npcIds = []
        self.shopId = nil
    }

    // 取得可用出口的描述
    func exitsDescription() -> String {
        guard !exits.isEmpty else {
            return "這裡沒有明顯的出口。"
        }
        let exitList = exits.keys.map { $0.displayName }.sorted().joined(separator: "、")
        return "出口：\(exitList)"
    }

    // 完整的房間描述
    func fullDescription(playerNames: [String], monsterNames: [String]) -> String {
        var lines: [String] = []
        lines.append("【\(name)】")
        lines.append(description)
        lines.append("")
        lines.append(exitsDescription())

        if !playerNames.isEmpty {
            lines.append("玩家：\(playerNames.joined(separator: "、"))")
        }
        if !monsterNames.isEmpty {
            lines.append("怪物：\(monsterNames.joined(separator: "、"))")
        }

        return lines.joined(separator: "\n")
    }
}
