import Foundation
import Logging

/// 商店管理器
///
/// This type is marked as `@unchecked Sendable` because Swift cannot statically
/// verify the thread-safety of its stored properties. Concurrency safety is
/// instead guaranteed at runtime by `lock`, an `NSLock` that must be held
/// whenever accessing or mutating shared mutable state such as `shops` and `npcs`.
/// As long as all access to these properties goes through `ShopManager`'s
/// methods (which correctly acquire and release `lock`), instances of this type
/// can be safely used across concurrency domains.
final class ShopManager: @unchecked Sendable {
    static let shared = ShopManager()

    /// 所有商店 (shopId -> Shop)
    private(set) var shops: [String: Shop] = [:]

    /// 所有 NPC (npcId -> NPC)
    private(set) var npcs: [String: NPC] = [:]

    private let lock = NSLock()
    private var logger = Logger(label: "com.swiftmud.shop")

    private init() {
        loadInitialData()
    }

    // MARK: - Shop Operations

    func getShop(_ shopId: String) -> Shop? {
        lock.lock()
        defer { lock.unlock() }
        return shops[shopId]
    }

    func getShopInRoom(_ roomId: String) -> Shop? {
        lock.lock()
        defer { lock.unlock() }

        // 找到房間內的商店 NPC，按 ID 排序確保結果確定
        let sortedNpcs = npcs.values.sorted { $0.id < $1.id }
        guard let npc = sortedNpcs.first(where: { $0.roomId == roomId && $0.shopId != nil }),
              let shopId = npc.shopId else {
            return nil
        }
        return shops[shopId]
    }

    func getNPCInRoom(_ roomId: String, type: NPCType? = nil) -> NPC? {
        lock.lock()
        defer { lock.unlock() }

        return npcs.values.first { npc in
            npc.roomId == roomId && (type == nil || npc.type == type)
        }
    }

    func getNPCsInRoom(_ roomId: String) -> [NPC] {
        lock.lock()
        defer { lock.unlock() }

        return npcs.values.filter { $0.roomId == roomId }
    }

    // MARK: - Transaction

    func buyItem(playerId: UUID, itemId: String, count: Int = 1, shopId: String) -> Result<(item: ItemTemplate, totalCost: Int), MUDError> {
        lock.lock()
        defer { lock.unlock() }

        guard let shop = shops[shopId] else {
            return .failure(.itemNotFound(id: shopId))
        }

        guard shop.sells(itemId) else {
            return .failure(.itemNotFound(id: itemId))
        }

        guard let item = World.shared.itemTemplates[itemId] else {
            return .failure(.itemNotFound(id: itemId))
        }

        guard var player = World.shared.getPlayer(byId: playerId) else {
            return .failure(.playerNotFound(name: "unknown"))
        }

        let totalCost = shop.buyPrice(for: item) * count

        guard player.gold >= totalCost else {
            return .failure(.insufficientGold(required: totalCost, has: player.gold))
        }

        // 扣除金幣
        player.gold -= totalCost

        // 加入物品到背包
        let added = player.inventory.addItem(itemId, count: count, stackable: item.stackable)
        guard added else {
            return .failure(.inventoryFull)
        }

        World.shared.updatePlayer(player)
        logger.info("Player \(playerId) bought \(count)x \(itemId) for \(totalCost) gold")

        return .success((item, totalCost))
    }

    func sellItem(playerId: UUID, itemId: String, count: Int = 1, shopId: String) -> Result<(item: ItemTemplate, totalEarned: Int), MUDError> {
        lock.lock()
        defer { lock.unlock() }

        guard let shop = shops[shopId] else {
            return .failure(.itemNotFound(id: shopId))
        }

        guard shop.buys(itemId) else {
            return .failure(.itemNotFound(id: itemId))
        }

        guard let item = World.shared.itemTemplates[itemId] else {
            return .failure(.itemNotFound(id: itemId))
        }

        guard var player = World.shared.getPlayer(byId: playerId) else {
            return .failure(.playerNotFound(name: "unknown"))
        }

        // 檢查玩家是否有足夠的物品
        let playerCount = player.inventory.countOf(itemId)
        guard playerCount >= count else {
            return .failure(.itemNotFound(id: itemId))
        }

        let totalEarned = shop.sellPrice(for: item) * count

        // 移除物品
        _ = player.inventory.removeItem(itemId, count: count)

        // 增加金幣
        player.gold += totalEarned

        World.shared.updatePlayer(player)
        logger.info("Player \(playerId) sold \(count)x \(itemId) for \(totalEarned) gold")

        return .success((item, totalEarned))
    }

    // MARK: - Initial Data

    private func loadInitialData() {
        // 雜貨店
        let generalStore = Shop(
            id: "general_store",
            name: "雜貨店",
            description: "販售各種日常用品和冒險補給",
            itemIds: ["health_potion", "mana_potion"],
            buyRate: 1.2,
            sellRate: 0.4
        )

        // 武器店
        let weaponShop = Shop(
            id: "weapon_shop",
            name: "鐵匠鋪",
            description: "提供各式武器和防具",
            itemIds: ["iron_sword", "leather_armor"],
            buyRate: 1.0,
            sellRate: 0.5,
            buyAllItems: false
        )

        shops = [
            generalStore.id: generalStore,
            weaponShop.id: weaponShop
        ]

        // 雜貨店老闆
        let merchantNPC = NPC(
            id: "merchant_chen",
            name: "陳老闆",
            description: "一位和藹的中年商人，經營這間雜貨店已有二十年。",
            type: .shopkeeper,
            roomId: "market",
            shopId: "general_store",
            dialogues: [
                "歡迎光臨！需要什麼嗎？",
                "今天的藥水特別新鮮！",
                "冒險者啊，記得帶夠補給品！"
            ]
        )

        // 鐵匠
        let blacksmithNPC = NPC(
            id: "blacksmith_wang",
            name: "王鐵匠",
            description: "一位肌肉發達的鐵匠，正在打鐵。",
            type: .shopkeeper,
            roomId: "market",
            shopId: "weapon_shop",
            dialogues: [
                "這把劍是我的得意之作！",
                "好武器需要好材料，也需要好手藝。",
                "需要修理裝備嗎？"
            ]
        )

        npcs = [
            merchantNPC.id: merchantNPC,
            blacksmithNPC.id: blacksmithNPC
        ]
    }
}
