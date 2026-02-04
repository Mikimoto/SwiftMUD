import Foundation

/// 商店定義
struct Shop: Codable, Identifiable {
    let id: String
    let name: String
    let description: String

    /// 販售的物品 ID 列表
    let itemIds: [String]

    /// 購買價格倍率（1.0 = 原價）
    let buyRate: Double

    /// 販賣價格倍率（0.5 = 半價收購）
    let sellRate: Double

    /// 是否收購所有物品
    let buyAllItems: Bool

    /// 營業時間（可選，nil 表示 24 小時營業）
    let openHour: Int?
    let closeHour: Int?

    init(
        id: String,
        name: String,
        description: String,
        itemIds: [String],
        buyRate: Double = 1.0,
        sellRate: Double = 0.5,
        buyAllItems: Bool = true,
        openHour: Int? = nil,
        closeHour: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.itemIds = itemIds
        self.buyRate = buyRate
        self.sellRate = sellRate
        self.buyAllItems = buyAllItems
        self.openHour = openHour
        self.closeHour = closeHour
    }

    /// 計算物品購買價格
    func buyPrice(for item: ItemTemplate) -> Int {
        Int(Double(item.basePrice) * buyRate)
    }

    /// 計算物品販賣價格
    func sellPrice(for item: ItemTemplate) -> Int {
        Int(Double(item.basePrice) * sellRate)
    }

    /// 檢查商店是否有販售此物品
    func sells(_ itemId: String) -> Bool {
        itemIds.contains(itemId)
    }

    /// 檢查商店是否收購此物品
    func buys(_ itemId: String) -> Bool {
        buyAllItems || itemIds.contains(itemId)
    }
}
