import Foundation

/// NPC 類型
enum NPCType: String, Codable {
    case shopkeeper   // 商店老闆
    case questGiver   // 任務發布者
    case trainer      // 技能訓練師
    case guard_       // 守衛
    case villager     // 村民
}

/// NPC 定義
struct NPC: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: NPCType

    /// NPC 所在房間
    let roomId: String

    /// 關聯的商店 ID（如果是商店老闆）
    let shopId: String?

    /// 關聯的任務 ID 列表（如果是任務發布者）
    let questIds: [String]

    /// 對話內容
    let dialogues: [String]

    init(
        id: String,
        name: String,
        description: String,
        type: NPCType,
        roomId: String,
        shopId: String? = nil,
        questIds: [String] = [],
        dialogues: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.roomId = roomId
        self.shopId = shopId
        self.questIds = questIds
        self.dialogues = dialogues
    }

    /// 取得隨機對話
    func randomDialogue() -> String? {
        dialogues.randomElement()
    }
}
