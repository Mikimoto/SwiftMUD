import XCTest
@testable import SwiftMUD
import NIO
import NIOEmbedded

// MARK: - Integration Test Helper

/// 整合測試的輔助類別，提供測試環境設置
final class IntegrationTestHelper {

    init() {}

    /// 建立測試用玩家
    func createTestPlayer(
        name: String = "TestPlayer",
        level: Int = 1,
        gold: Int = 1000,
        adminLevel: AdminTier = .player,
        roomId: String = "town_square"
    ) -> Player {
        var player = Player.create(name: name, passwordHash: "testhash", startingRoom: roomId)
        player.level = level
        player.gold = gold
        player.adminLevel = adminLevel
        return player
    }

    /// 建立測試用的 Session（使用 EmbeddedChannel 進行測試）
    func createTestSession() -> Session {
        let channel = EmbeddedChannel()
        return Session(channel: channel)
    }

    /// 設置玩家並加入世界
    func setupPlayerInWorld(_ player: Player, session: Session) {
        World.shared.addPlayer(player)
        session.playerId = player.id
        session.playerName = player.name
        session.state = .playing
    }

    /// 清理測試玩家
    func cleanupPlayer(_ playerId: UUID) {
        World.shared.removePlayer(playerId)
        CombatManager.shared.leaveCombat(playerId)
    }
}

// MARK: - Integration Tests

final class IntegrationTests: XCTestCase {

    var helper: IntegrationTestHelper!

    override func setUp() {
        super.setUp()
        helper = IntegrationTestHelper()
    }

    override func tearDown() {
        helper = nil
        super.tearDown()
    }

    // MARK: - Complete Game Flow Tests

    /// 測試完整遊戲流程：建立玩家 -> 添加到世界 -> 移動 -> 戰鬥 -> 獲得獎勵
    func testCompleteGameFlow() {
        // 建立玩家
        var player = helper.createTestPlayer(name: "GameFlowTester", level: 5, gold: 100)
        let session = helper.createTestSession()

        // 添加到世界
        helper.setupPlayerInWorld(player, session: session)

        // 驗證玩家已添加
        let fetchedPlayer = World.shared.getPlayer(byId: player.id)
        XCTAssertNotNil(fetchedPlayer)
        XCTAssertEqual(fetchedPlayer?.name, "GameFlowTester")
        XCTAssertEqual(fetchedPlayer?.currentRoomId, "town_square")

        // 測試移動到南門
        let southGate = World.shared.getRoom("south_gate")
        XCTAssertNotNil(southGate)

        World.shared.movePlayer(player.id, from: "town_square", to: "south_gate")
        player.currentRoomId = "south_gate"

        let movedPlayer = World.shared.getPlayer(byId: player.id)
        XCTAssertEqual(movedPlayer?.currentRoomId, "south_gate")

        // 繼續移動到平原
        World.shared.movePlayer(player.id, from: "south_gate", to: "plains")
        player.currentRoomId = "plains"

        let plainPlayer = World.shared.getPlayer(byId: player.id)
        XCTAssertEqual(plainPlayer?.currentRoomId, "plains")

        // 檢查平原是否有怪物
        let monstersInPlains = World.shared.getMonstersInRoom("plains")
        XCTAssertGreaterThan(monstersInPlains.count, 0, "平原應該有怪物")

        // 模擬戰鬥獎勵（直接給予經驗和金幣）
        let initialExp = player.exp
        let initialGold = player.gold
        let initialLevel = player.level

        let expGained = 50
        let goldGained = 20

        let leveledUp = player.gainExp(expGained)
        player.gold += goldGained

        XCTAssertEqual(player.exp - initialExp + (leveledUp ? player.expToNextLevel() : 0), expGained - (leveledUp ? 100 : 0) + (leveledUp ? player.expToNextLevel() : 0))
        XCTAssertEqual(player.gold, initialGold + goldGained)

        if leveledUp {
            XCTAssertEqual(player.level, initialLevel + 1)
        }

        World.shared.updatePlayer(player)

        // 清理
        helper.cleanupPlayer(player.id)
    }

    /// 測試商店購買/出售流程
    func testShopBuySellFlow() {
        // 建立有足夠金幣的玩家
        var player = helper.createTestPlayer(name: "ShopTester", gold: 500)
        player.currentRoomId = "market" // 市場有商店
        let session = helper.createTestSession()

        helper.setupPlayerInWorld(player, session: session)

        // 驗證市場有商店
        let shop = ShopManager.shared.getShopInRoom("market")
        XCTAssertNotNil(shop, "市場應該有商店")

        guard let shopId = shop?.id else {
            XCTFail("無法取得商店 ID")
            helper.cleanupPlayer(player.id)
            return
        }

        // 測試購買藥水
        let buyResult = ShopManager.shared.buyItem(
            playerId: player.id,
            itemId: "health_potion",
            count: 2,
            shopId: shopId
        )

        switch buyResult {
        case .success(let (item, totalCost)):
            XCTAssertEqual(item.name, "治療藥水")
            XCTAssertGreaterThan(totalCost, 0)

            // 驗證玩家背包有藥水
            if let updatedPlayer = World.shared.getPlayer(byId: player.id) {
                let potionCount = updatedPlayer.inventory.countOf("health_potion")
                XCTAssertEqual(potionCount, 2)
                // 驗證金幣減少
                XCTAssertEqual(updatedPlayer.gold, 500 - totalCost)
                player = updatedPlayer
            }
        case .failure(let error):
            XCTFail("購買失敗：\(error.localizedDescription)")
        }

        // 測試賣出藥水
        let sellResult = ShopManager.shared.sellItem(
            playerId: player.id,
            itemId: "health_potion",
            count: 1,
            shopId: shopId
        )

        switch sellResult {
        case .success(let (item, totalEarned)):
            XCTAssertEqual(item.name, "治療藥水")
            XCTAssertGreaterThan(totalEarned, 0)

            // 驗證玩家背包藥水數量減少
            if let updatedPlayer = World.shared.getPlayer(byId: player.id) {
                let potionCount = updatedPlayer.inventory.countOf("health_potion")
                XCTAssertEqual(potionCount, 1)
            }
        case .failure(let error):
            XCTFail("賣出失敗：\(error.localizedDescription)")
        }

        // 清理
        helper.cleanupPlayer(player.id)
    }

    /// 測試任務接受/完成流程
    func testQuestAcceptCompleteFlow() {
        // 建立玩家
        let player = helper.createTestPlayer(name: "QuestTester", level: 1)
        let session = helper.createTestSession()

        helper.setupPlayerInWorld(player, session: session)

        // 取得可用任務
        let availableQuests = QuestManager.shared.getAvailableQuests(for: player)
        XCTAssertGreaterThan(availableQuests.count, 0, "應該有可用任務")

        // 接受探索任務（tutorial_explore）
        let acceptResult = QuestManager.shared.acceptQuest(
            playerId: player.id,
            questId: "tutorial_explore",
            player: player
        )

        switch acceptResult {
        case .success(let progress):
            XCTAssertEqual(progress.questId, "tutorial_explore")
            XCTAssertEqual(progress.status, .active)
            XCTAssertGreaterThan(progress.objectives.count, 0)
        case .failure(let error):
            XCTFail("接受任務失敗：\(error.localizedDescription)")
        }

        // 驗證任務進行中
        let activeQuests = QuestManager.shared.getActiveQuests(for: player.id)
        XCTAssertTrue(activeQuests.contains { $0.questId == "tutorial_explore" })

        // 模擬完成目標（訪問市場和酒館）
        QuestManager.shared.updateVisitProgress(playerId: player.id, roomId: "market")
        QuestManager.shared.updateVisitProgress(playerId: player.id, roomId: "tavern")

        // 檢查任務進度是否完成
        if let progress = QuestManager.shared.getQuestProgress(playerId: player.id, questId: "tutorial_explore") {
            XCTAssertTrue(progress.allObjectivesComplete, "所有目標應該已完成")
        }

        // 完成任務並領取獎勵
        let completeResult = QuestManager.shared.completeQuest(playerId: player.id, questId: "tutorial_explore")

        switch completeResult {
        case .success(let rewards):
            XCTAssertGreaterThan(rewards.exp, 0)
            XCTAssertGreaterThan(rewards.gold, 0)
        case .failure(let error):
            XCTFail("完成任務失敗：\(error.localizedDescription)")
        }

        // 驗證任務不再進行中
        let remainingQuests = QuestManager.shared.getActiveQuests(for: player.id)
        XCTAssertFalse(remainingQuests.contains { $0.questId == "tutorial_explore" })

        // 清理
        helper.cleanupPlayer(player.id)
    }

    // MARK: - Multi-System Interaction Tests

    /// 測試多個系統之間的互動：任務進度更新在擊殺怪物時
    func testCombatQuestInteraction() {
        // 建立玩家
        var player = helper.createTestPlayer(name: "CombatQuestTester", level: 1)
        let session = helper.createTestSession()

        helper.setupPlayerInWorld(player, session: session)

        // 接受探索任務
        let exploreResult = QuestManager.shared.acceptQuest(
            playerId: player.id,
            questId: "tutorial_explore",
            player: player
        )

        guard case .success = exploreResult else {
            XCTFail("無法接受探索任務")
            helper.cleanupPlayer(player.id)
            return
        }

        // 完成探索任務目標（訪問市場和酒館）
        QuestManager.shared.updateVisitProgress(playerId: player.id, roomId: "market")
        QuestManager.shared.updateVisitProgress(playerId: player.id, roomId: "tavern")

        // 完成探索任務並領取獎勵
        let completeExploreResult = QuestManager.shared.completeQuest(playerId: player.id, questId: "tutorial_explore")
        guard case .success = completeExploreResult else {
            XCTFail("無法完成探索任務")
            helper.cleanupPlayer(player.id)
            return
        }

        // 更新玩家資訊
        if let updatedPlayer = World.shared.getPlayer(byId: player.id) {
            player = updatedPlayer
        }

        // 接受戰鬥任務
        let acceptResult = QuestManager.shared.acceptQuest(
            playerId: player.id,
            questId: "tutorial_combat",
            player: player
        )

        guard case .success = acceptResult else {
            XCTFail("無法接受戰鬥任務")
            helper.cleanupPlayer(player.id)
            return
        }

        // 模擬擊殺史萊姆 3 次
        for _ in 0..<3 {
            QuestManager.shared.updateKillProgress(playerId: player.id, monsterId: "slime")
        }

        // 檢查任務進度
        if let progress = QuestManager.shared.getQuestProgress(playerId: player.id, questId: "tutorial_combat") {
            XCTAssertTrue(progress.allObjectivesComplete, "擊殺目標應該完成")
        }

        // 清理
        helper.cleanupPlayer(player.id)
    }

    /// 測試玩家狀態變更的連鎖效應
    func testPlayerStateChain() {
        // 建立玩家
        var player = helper.createTestPlayer(name: "StateTester", level: 1, gold: 100)
        let session = helper.createTestSession()

        helper.setupPlayerInWorld(player, session: session)

        // 測試經驗獲取和升級
        let initialStats = (
            maxHP: player.maxHP,
            maxMP: player.maxMP,
            attack: player.baseAttack,
            defense: player.baseDefense
        )

        // 獲取足夠升級的經驗
        let leveledUp = player.gainExp(100)
        XCTAssertTrue(leveledUp)
        XCTAssertEqual(player.level, 2)

        // 驗證升級後屬性提升
        XCTAssertEqual(player.maxHP, initialStats.maxHP + 10)
        XCTAssertEqual(player.maxMP, initialStats.maxMP + 5)
        XCTAssertEqual(player.baseAttack, initialStats.attack + 2)
        XCTAssertEqual(player.baseDefense, initialStats.defense + 1)

        // 更新世界中的玩家
        World.shared.updatePlayer(player)

        // 驗證世界中的玩家資料已更新
        if let worldPlayer = World.shared.getPlayer(byId: player.id) {
            XCTAssertEqual(worldPlayer.level, 2)
            XCTAssertEqual(worldPlayer.maxHP, initialStats.maxHP + 10)
        }

        // 清理
        helper.cleanupPlayer(player.id)
    }

    /// 測試物品系統與玩家互動
    func testInventoryItemInteraction() {
        var player = helper.createTestPlayer(name: "InventoryTester", gold: 1000)
        let session = helper.createTestSession()

        helper.setupPlayerInWorld(player, session: session)

        // 添加物品到背包
        let added = player.inventory.addItem("health_potion", count: 5, stackable: true)
        XCTAssertTrue(added)
        XCTAssertEqual(player.inventory.countOf("health_potion"), 5)

        // 添加裝備
        let weaponAdded = player.inventory.addItem("iron_sword", count: 1, stackable: false)
        XCTAssertTrue(weaponAdded)
        XCTAssertEqual(player.inventory.countOf("iron_sword"), 1)

        // 裝備武器
        let previousWeapon = player.equip(itemId: "iron_sword", slot: .mainHand)
        XCTAssertNil(previousWeapon)
        XCTAssertEqual(player.equipment[.mainHand], "iron_sword")

        // 測試裝備加成
        let totalAttack = player.totalAttack()
        XCTAssertEqual(totalAttack, player.baseAttack + 10) // iron_sword 加 10 攻擊

        // 卸下裝備
        let unequipped = player.unequip(slot: .mainHand)
        XCTAssertEqual(unequipped, "iron_sword")
        XCTAssertNil(player.equipment[.mainHand])

        // 移除物品
        let removed = player.inventory.removeItem("health_potion", count: 3)
        XCTAssertTrue(removed)
        XCTAssertEqual(player.inventory.countOf("health_potion"), 2)

        World.shared.updatePlayer(player)

        // 清理
        helper.cleanupPlayer(player.id)
    }

    /// 測試房間系統與玩家移動的互動
    func testRoomPlayerMovement() {
        let player1 = helper.createTestPlayer(name: "Mover1")
        let player2 = helper.createTestPlayer(name: "Mover2")
        let session1 = helper.createTestSession()
        let session2 = helper.createTestSession()

        helper.setupPlayerInWorld(player1, session: session1)
        helper.setupPlayerInWorld(player2, session: session2)

        // 驗證兩位玩家都在城鎮廣場
        var playersInTownSquare = World.shared.getPlayersInRoom("town_square")
        XCTAssertTrue(playersInTownSquare.contains { $0.id == player1.id })
        XCTAssertTrue(playersInTownSquare.contains { $0.id == player2.id })

        // 玩家1移動到市場
        World.shared.movePlayer(player1.id, from: "town_square", to: "market")

        // 驗證玩家位置
        playersInTownSquare = World.shared.getPlayersInRoom("town_square")
        let playersInMarket = World.shared.getPlayersInRoom("market")

        XCTAssertFalse(playersInTownSquare.contains { $0.id == player1.id })
        XCTAssertTrue(playersInMarket.contains { $0.id == player1.id })
        XCTAssertTrue(playersInTownSquare.contains { $0.id == player2.id })

        // 清理
        helper.cleanupPlayer(player1.id)
        helper.cleanupPlayer(player2.id)
    }

    /// 測試戰鬥系統傷害計算
    func testCombatDamageCalculation() {
        let attackerStats = CombatStats(attack: 20, defense: 5, magic: 10, speed: 10)
        let defenderStats = CombatStats(attack: 10, defense: 10, magic: 5, speed: 8)

        // 普通攻擊傷害計算
        let damage = CombatManager.shared.calculateDamage(
            attacker: attackerStats,
            defender: defenderStats,
            skill: nil
        )

        // 傷害應該大於 0 且有防禦減免
        XCTAssertGreaterThan(damage, 0)
        XCTAssertLessThan(damage, attackerStats.attack) // 有防禦減免

        // 測試高防禦情況
        let highDefenseStats = CombatStats(attack: 10, defense: 100, magic: 5, speed: 8)
        let reducedDamage = CombatManager.shared.calculateDamage(
            attacker: attackerStats,
            defender: highDefenseStats,
            skill: nil
        )

        XCTAssertGreaterThanOrEqual(reducedDamage, 1) // 最少 1 點傷害
        XCTAssertLessThan(reducedDamage, damage) // 高防禦傷害更少
    }

    /// 測試商店價格計算
    func testShopPriceCalculation() {
        guard let shop = ShopManager.shared.getShop("general_store"),
              let item = World.shared.itemTemplates["health_potion"] else {
            XCTFail("無法取得商店或物品")
            return
        }

        let buyPrice = shop.buyPrice(for: item)
        let sellPrice = shop.sellPrice(for: item)

        // 購買價格應該高於或等於基礎價格
        XCTAssertGreaterThanOrEqual(buyPrice, item.basePrice)

        // 賣出價格應該低於購買價格
        XCTAssertLessThan(sellPrice, buyPrice)

        // 賣出價格應該大於 0
        XCTAssertGreaterThan(sellPrice, 0)
    }
}
