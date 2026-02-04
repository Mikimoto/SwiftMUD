import Foundation

// 物品模板（定義）
struct ItemTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: ItemType

    // 裝備屬性
    let equipSlot: EquipmentSlot?
    let statBonus: [Stat: Int]
    let levelRequired: Int

    // 經濟屬性
    let basePrice: Int
    let stackable: Bool
    let maxStack: Int

    init(
        id: String,
        name: String,
        description: String,
        type: ItemType,
        equipSlot: EquipmentSlot? = nil,
        statBonus: [Stat: Int] = [:],
        levelRequired: Int = 1,
        basePrice: Int = 0,
        stackable: Bool = false,
        maxStack: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.equipSlot = equipSlot
        self.statBonus = statBonus
        self.levelRequired = levelRequired
        self.basePrice = basePrice
        self.stackable = stackable
        self.maxStack = maxStack
    }
}

enum ItemType: String, Codable {
    case weapon
    case armor
    case accessory
    case consumable
    case material
    case quest
    case misc
}

// 物品實例（玩家擁有的）
struct ItemInstance: Codable, Identifiable {
    let id: UUID
    let templateId: String
    var count: Int

    init(templateId: String, count: Int = 1) {
        self.id = UUID()
        self.templateId = templateId
        self.count = count
    }
}

// 背包系統
struct Inventory: Codable {
    var items: [ItemInstance]
    let maxSlots: Int

    init(maxSlots: Int = 20) {
        self.items = []
        self.maxSlots = maxSlots
    }

    var usedSlots: Int {
        items.count
    }

    var isFull: Bool {
        usedSlots >= maxSlots
    }

    // Note: maxStack enforcement is the caller's responsibility.
    // The caller has access to ItemTemplate and should check maxStack before calling addItem.
    mutating func addItem(_ templateId: String, count: Int = 1, stackable: Bool) -> Bool {
        if stackable, let index = items.firstIndex(where: { $0.templateId == templateId }) {
            items[index].count += count
            return true
        }

        guard !isFull else { return false }
        items.append(ItemInstance(templateId: templateId, count: count))
        return true
    }

    mutating func removeItem(_ templateId: String, count: Int = 1) -> Bool {
        guard let index = items.firstIndex(where: { $0.templateId == templateId }) else {
            return false
        }

        // Fail if trying to remove more than available
        guard items[index].count >= count else {
            return false
        }

        if items[index].count > count {
            items[index].count -= count
        } else {
            items.remove(at: index)
        }
        return true
    }

    func countOf(_ templateId: String) -> Int {
        items.filter { $0.templateId == templateId }.reduce(0) { $0 + $1.count }
    }
}
