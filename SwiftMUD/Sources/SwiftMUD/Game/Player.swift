import Foundation

struct Player: Codable, Identifiable {
    let id: UUID
    var name: String
    var passwordHash: String

    // 等級與經驗
    var level: Int
    var exp: Int
    var gold: Int

    // 屬性
    var currentHP: Int
    var maxHP: Int
    var currentMP: Int
    var maxMP: Int
    var baseAttack: Int
    var baseDefense: Int
    var baseMagic: Int

    // 位置
    var currentRoomId: String

    // 技能 (技能ID -> 等級)
    var skills: [String: Int]

    // 背包
    var inventory: Inventory

    // 裝備欄位 (slot -> itemTemplateId)
    var equipment: [EquipmentSlot: String]

    // 管理權限
    var adminLevel: AdminTier

    // 狀態
    var isMuted: Bool
    var muteExpiry: Date?
    var isBanned: Bool
    var banExpiry: Date?
    var banReason: String?
    var isAFK: Bool

    // 職業
    var playerClass: String

    // 建立新玩家
    static func create(name: String, passwordHash: String, startingRoom: String = "town_square") -> Player {
        Player(
            id: UUID(),
            name: name,
            passwordHash: passwordHash,
            level: 1,
            exp: 0,
            gold: 100,
            currentHP: 100,
            maxHP: 100,
            currentMP: 50,
            maxMP: 50,
            baseAttack: 10,
            baseDefense: 5,
            baseMagic: 5,
            currentRoomId: startingRoom,
            skills: [:],
            inventory: Inventory(maxSlots: 20),
            equipment: [:],
            adminLevel: .player,
            isMuted: false,
            muteExpiry: nil,
            isBanned: false,
            banExpiry: nil,
            banReason: nil,
            isAFK: false,
            playerClass: "冒險者"
        )
    }

    // 計算升級所需經驗
    func expToNextLevel() -> Int {
        level * 100
    }

    // 經驗別名
    var experience: Int {
        get { exp }
        set { exp = newValue }
    }

    // 是否存活
    var isAlive: Bool {
        currentHP > 0
    }

    // 治療
    mutating func heal(_ amount: Int) {
        currentHP = min(currentHP + amount, maxHP)
    }

    // 受傷
    mutating func takeDamage(_ amount: Int) {
        currentHP = max(currentHP - amount, 0)
    }

    // 增加經驗
    mutating func gainExp(_ amount: Int) -> Bool {
        exp += amount
        var leveledUp = false
        while exp >= expToNextLevel() {
            exp -= expToNextLevel()
            level += 1
            leveledUp = true
            onLevelUp()
        }
        return leveledUp
    }

    private mutating func onLevelUp() {
        maxHP += 10
        maxMP += 5
        baseAttack += 2
        baseDefense += 1
        baseMagic += 1
        currentHP = maxHP
        currentMP = maxMP
    }

    /// 裝備物品
    mutating func equip(itemId: String, slot: EquipmentSlot) -> String? {
        let previousItem = equipment[slot]
        equipment[slot] = itemId
        return previousItem
    }

    /// 卸下裝備
    mutating func unequip(slot: EquipmentSlot) -> String? {
        let item = equipment[slot]
        equipment[slot] = nil
        return item
    }

    /// 計算裝備加成後的總攻擊力
    func totalAttack() -> Int {
        var total = baseAttack
        for (_, itemId) in equipment {
            if let item = World.shared.itemTemplates[itemId] {
                total += item.statBonus[.attack] ?? 0
            }
        }
        return total
    }

    /// 計算裝備加成後的總防禦力
    func totalDefense() -> Int {
        var total = baseDefense
        for (_, itemId) in equipment {
            if let item = World.shared.itemTemplates[itemId] {
                total += item.statBonus[.defense] ?? 0
            }
        }
        return total
    }
}
