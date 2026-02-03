import Foundation

/// 遊戲世界的中央狀態容器，管理所有遊戲實體
final class World {
    // 單例模式
    static let shared = World()

    // 玩家狀態 (UUID -> Player)
    private(set) var players: [UUID: Player] = [:]

    // 房間狀態 (roomId -> Room)
    private(set) var rooms: [String: Room] = [:]

    // 怪物狀態 (UUID -> Monster)
    private(set) var monsters: [UUID: Monster] = [:]

    // 物品模板 (templateId -> ItemTemplate)
    private(set) var itemTemplates: [String: ItemTemplate] = [:]

    // 怪物模板 (templateId -> MonsterTemplate)
    private(set) var monsterTemplates: [String: MonsterTemplate] = [:]

    // 技能定義 (skillId -> Skill)
    private(set) var skills: [String: Skill] = [:]

    // 線程安全鎖
    private let lock = NSLock()

    private init() {
        loadInitialData()
    }

    // MARK: - Player Operations

    func addPlayer(_ player: Player) {
        lock.lock()
        defer { lock.unlock() }
        players[player.id] = player

        // 將玩家加入房間
        if var room = rooms[player.currentRoomId] {
            room.playerIds.insert(player.id.uuidString)
            rooms[player.currentRoomId] = room
        }
    }

    func removePlayer(_ playerId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let player = players[playerId] else { return }

        // 從房間移除玩家
        if var room = rooms[player.currentRoomId] {
            room.playerIds.remove(playerId.uuidString)
            rooms[player.currentRoomId] = room
        }

        players.removeValue(forKey: playerId)
    }

    func updatePlayer(_ player: Player) {
        lock.lock()
        defer { lock.unlock() }
        players[player.id] = player
    }

    func getPlayer(byId id: UUID) -> Player? {
        lock.lock()
        defer { lock.unlock() }
        return players[id]
    }

    func getPlayer(byName name: String) -> Player? {
        lock.lock()
        defer { lock.unlock() }
        return players.values.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Room Operations

    func getRoom(_ roomId: String) -> Room? {
        lock.lock()
        defer { lock.unlock() }
        return rooms[roomId]
    }

    func updateRoom(_ room: Room) {
        lock.lock()
        defer { lock.unlock() }
        rooms[room.id] = room
    }

    func movePlayer(_ playerId: UUID, from oldRoomId: String, to newRoomId: String) {
        lock.lock()
        defer { lock.unlock() }

        // 從舊房間移除
        if var oldRoom = rooms[oldRoomId] {
            oldRoom.playerIds.remove(playerId.uuidString)
            rooms[oldRoomId] = oldRoom
        }

        // 加入新房間
        if var newRoom = rooms[newRoomId] {
            newRoom.playerIds.insert(playerId.uuidString)
            rooms[newRoomId] = newRoom
        }

        // 更新玩家位置
        if var player = players[playerId] {
            player.currentRoomId = newRoomId
            players[playerId] = player
        }
    }

    func getPlayersInRoom(_ roomId: String) -> [Player] {
        lock.lock()
        defer { lock.unlock() }

        guard let room = rooms[roomId] else { return [] }
        return room.playerIds.compactMap { UUID(uuidString: $0) }.compactMap { players[$0] }
    }

    func getMonstersInRoom(_ roomId: String) -> [Monster] {
        lock.lock()
        defer { lock.unlock() }

        guard let room = rooms[roomId] else { return [] }
        return room.monsterIds.compactMap { UUID(uuidString: $0) }.compactMap { monsters[$0] }
    }

    // MARK: - Monster Operations

    func addMonster(_ monster: Monster) {
        lock.lock()
        defer { lock.unlock() }
        monsters[monster.id] = monster

        if var room = rooms[monster.currentRoomId] {
            room.monsterIds.insert(monster.id.uuidString)
            rooms[monster.currentRoomId] = room
        }
    }

    func getMonster(_ monsterId: UUID) -> Monster? {
        lock.lock()
        defer { lock.unlock() }
        return monsters[monsterId]
    }

    func updateMonster(_ monster: Monster) {
        lock.lock()
        defer { lock.unlock() }
        monsters[monster.id] = monster
    }

    func removeMonster(_ monsterId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let monster = monsters[monsterId] else { return }

        if var room = rooms[monster.currentRoomId] {
            room.monsterIds.remove(monsterId.uuidString)
            rooms[monster.currentRoomId] = room
        }

        monsters.removeValue(forKey: monsterId)
    }

    // MARK: - Initial Data Loading

    private func loadInitialData() {
        // 載入起始房間
        let townSquare = Room(
            id: "town_square",
            name: "城鎮廣場",
            description: "這是一個繁忙的城鎮廣場，四周圍繞著商店和民宅。中央有一座噴水池，旅人們在此休息聊天。",
            exits: [.north: "temple", .east: "market", .south: "south_gate", .west: "tavern"],
            isSafeZone: true,
            respawnPoint: true
        )

        let temple = Room(
            id: "temple",
            name: "神殿",
            description: "一座莊嚴的神殿，供奉著守護這片土地的神明。祭司們在此為旅人提供治療和祝福。",
            exits: [.south: "town_square"],
            isSafeZone: true
        )

        let market = Room(
            id: "market",
            name: "市場",
            description: "熱鬧的市場，攤販們叫賣著各種商品。空氣中瀰漫著香料和食物的氣味。",
            exits: [.west: "town_square", .east: "east_road"],
            isSafeZone: true
        )

        let tavern = Room(
            id: "tavern",
            name: "酒館",
            description: "「醉夢軒」酒館，冒險者們最愛的聚會場所。吧台後方的老闆正在擦拭酒杯。",
            exits: [.east: "town_square"],
            isSafeZone: true
        )

        let southGate = Room(
            id: "south_gate",
            name: "南門",
            description: "城鎮的南門，通往廣闘的平原。守衛在此巡邏，保護城鎮免受怪物侵襲。",
            exits: [.north: "town_square", .south: "plains"]
        )

        let plains = Room(
            id: "plains",
            name: "平原",
            description: "一望無際的草原，偶爾可見野生動物出沒。這裡是新手冒險者練功的好地方。",
            exits: [.north: "south_gate", .south: "forest_entrance"],
            canPvP: true
        )

        let forestEntrance = Room(
            id: "forest_entrance",
            name: "森林入口",
            description: "茂密森林的入口，樹木遮天蔽日。傳說森林深處住著強大的怪物。",
            exits: [.north: "plains", .south: "deep_forest"],
            canPvP: true
        )

        let eastRoad = Room(
            id: "east_road",
            name: "東方道路",
            description: "通往東方城鎮的道路，路旁偶有旅人經過。",
            exits: [.west: "market"]
        )

        let deepForest = Room(
            id: "deep_forest",
            name: "森林深處",
            description: "幽暗的森林深處，陽光幾乎無法穿透樹冠。四周傳來不明生物的低吼聲。",
            exits: [.north: "forest_entrance"],
            canPvP: true
        )

        rooms = [
            townSquare.id: townSquare,
            temple.id: temple,
            market.id: market,
            tavern.id: tavern,
            southGate.id: southGate,
            plains.id: plains,
            forestEntrance.id: forestEntrance,
            eastRoad.id: eastRoad,
            deepForest.id: deepForest
        ]

        // 載入怪物模板
        monsterTemplates = [
            "slime": MonsterTemplate(
                id: "slime",
                name: "史萊姆",
                description: "一團黏糊糊的生物",
                level: 1,
                maxHP: 30,
                attack: 5,
                defense: 2,
                magic: 0,
                expReward: 10,
                goldReward: 2...5,
                lootTable: [],
                aggressive: false,
                respawnTime: 30
            ),
            "wolf": MonsterTemplate(
                id: "wolf",
                name: "野狼",
                description: "一隻凶猛的野狼",
                level: 3,
                maxHP: 50,
                attack: 8,
                defense: 3,
                magic: 0,
                expReward: 30,
                goldReward: 5...15,
                lootTable: [
                    LootEntry(itemId: "wolf_pelt", chance: 0.5, countRange: 1...1),
                    LootEntry(itemId: "wolf_fang", chance: 0.2, countRange: 1...2)
                ],
                aggressive: true,
                respawnTime: 60
            ),
            "goblin": MonsterTemplate(
                id: "goblin",
                name: "哥布林",
                description: "一隻狡猾的哥布林",
                level: 5,
                maxHP: 80,
                attack: 12,
                defense: 5,
                magic: 3,
                expReward: 50,
                goldReward: 10...30,
                lootTable: [
                    LootEntry(itemId: "goblin_ear", chance: 0.3, countRange: 1...2)
                ],
                aggressive: true,
                respawnTime: 120
            )
        ]

        // 生成初始怪物
        spawnInitialMonsters()

        // 載入物品模板
        itemTemplates = [
            "health_potion": ItemTemplate(
                id: "health_potion",
                name: "治療藥水",
                description: "恢復 50 HP",
                type: .consumable,
                basePrice: 50,
                stackable: true,
                maxStack: 99
            ),
            "mana_potion": ItemTemplate(
                id: "mana_potion",
                name: "魔力藥水",
                description: "恢復 30 MP",
                type: .consumable,
                basePrice: 40,
                stackable: true,
                maxStack: 99
            ),
            "iron_sword": ItemTemplate(
                id: "iron_sword",
                name: "鐵劍",
                description: "一把普通的鐵劍",
                type: .weapon,
                equipSlot: .mainHand,
                statBonus: [.attack: 10],
                levelRequired: 1,
                basePrice: 100
            ),
            "leather_armor": ItemTemplate(
                id: "leather_armor",
                name: "皮甲",
                description: "基本的皮革護甲",
                type: .armor,
                equipSlot: .body,
                statBonus: [.defense: 5, .maxHP: 20],
                levelRequired: 1,
                basePrice: 150
            )
        ]

        // 載入技能
        skills = [
            "slash": Skill(
                id: "slash",
                name: "斬擊",
                description: "對敵人造成物理傷害",
                type: .active,
                mpCost: 10,
                cooldown: 3,
                effects: [.damage(base: 20, scaling: 1.2, stat: .attack)],
                maxLevel: 5
            ),
            "heal": Skill(
                id: "heal",
                name: "治療術",
                description: "恢復自身生命值",
                type: .active,
                mpCost: 15,
                cooldown: 5,
                effects: [.heal(base: 30, scaling: 1.0)],
                maxLevel: 5
            ),
            "fireball": Skill(
                id: "fireball",
                name: "火球術",
                description: "發射火球造成魔法傷害",
                type: .active,
                mpCost: 25,
                castTime: 1.5,
                cooldown: 8,
                effects: [.damage(base: 50, scaling: 1.5, stat: .magic)],
                maxLevel: 5
            ),
            "toughness": Skill(
                id: "toughness",
                name: "強壯體魄",
                description: "永久提升最大生命值",
                type: .passive,
                statBonus: [.maxHP: 20],
                maxLevel: 3
            )
        ]
    }

    private func spawnInitialMonsters() {
        // 在平原生成史萊姆
        if let template = monsterTemplates["slime"] {
            for _ in 0..<3 {
                let monster = Monster(from: template, roomId: "plains")
                addMonsterInternal(monster)
            }
        }

        // 在森林入口生成野狼
        if let template = monsterTemplates["wolf"] {
            for _ in 0..<2 {
                let monster = Monster(from: template, roomId: "forest_entrance")
                addMonsterInternal(monster)
            }
        }

        // 在森林深處生成哥布林
        if let template = monsterTemplates["goblin"] {
            for _ in 0..<2 {
                let monster = Monster(from: template, roomId: "deep_forest")
                addMonsterInternal(monster)
            }
        }
    }

    // 內部使用，不加鎖（因為在初始化時調用，此時還沒有並發問題）
    private func addMonsterInternal(_ monster: Monster) {
        monsters[monster.id] = monster

        if var room = rooms[monster.currentRoomId] {
            room.monsterIds.insert(monster.id.uuidString)
            rooms[monster.currentRoomId] = room
        }
    }
}
