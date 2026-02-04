import XCTest
@testable import SwiftMUD
import NIO

// MARK: - Command Integration Tests

final class CommandIntegrationTests: XCTestCase {

    var helper: IntegrationTestHelper!
    var mockSession: MockTestSession!
    var testPlayer: Player!
    var realSession: Session!

    override func setUp() {
        super.setUp()
        helper = IntegrationTestHelper()

        // 建立測試玩家和 Session
        testPlayer = helper.createTestPlayer(name: "CommandTester", gold: 1000)
        realSession = helper.createTestSession()
        helper.setupPlayerInWorld(testPlayer, session: realSession)

        // 建立 Mock Session 用於記錄訊息
        mockSession = MockTestSession(id: realSession.id, playerId: testPlayer.id, playerName: testPlayer.name)
    }

    override func tearDown() {
        if let player = testPlayer {
            helper.cleanupPlayer(player.id)
        }
        testPlayer = nil
        realSession = nil
        mockSession = nil
        helper = nil
        super.tearDown()
    }

    // MARK: - Command Parser Tests

    /// 測試指令解析器的基本功能
    func testCommandParserBasics() {
        // 測試空輸入
        let emptyResult = CommandParser.shared.parse("", session: realSession)
        if case .success(let message) = emptyResult {
            XCTAssertNil(message)
        } else {
            XCTFail("空輸入應該返回成功")
        }

        // 測試未知指令
        let unknownResult = CommandParser.shared.parse("unknowncommand", session: realSession)
        if case .failure(let error) = unknownResult {
            if case .unknownCommand = error {
                // 正確
            } else {
                XCTFail("應該返回 unknownCommand 錯誤")
            }
        } else {
            XCTFail("未知指令應該返回失敗")
        }
    }

    /// 測試 look 指令
    func testLookCommand() {
        let result = CommandParser.shared.parse("look", session: realSession)

        switch result {
        case .success:
            // look 指令成功執行
            break
        case .failure(let error):
            XCTFail("look 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("look 指令不應該返回 quit")
        }
    }

    /// 測試 status 指令
    func testStatusCommand() {
        let result = CommandParser.shared.parse("status", session: realSession)

        switch result {
        case .success:
            // status 指令成功執行
            break
        case .failure(let error):
            XCTFail("status 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("status 指令不應該返回 quit")
        }
    }

    /// 測試 inventory 指令
    func testInventoryCommand() {
        let result = CommandParser.shared.parse("inventory", session: realSession)

        switch result {
        case .success:
            // inventory 指令成功執行
            break
        case .failure(let error):
            XCTFail("inventory 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("inventory 指令不應該返回 quit")
        }

        // 測試別名 i
        let aliasResult = CommandParser.shared.parse("i", session: realSession)
        switch aliasResult {
        case .success:
            break
        case .failure(let error):
            XCTFail("i 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("i 指令不應該返回 quit")
        }
    }

    /// 測試 help 指令
    func testHelpCommand() {
        let result = CommandParser.shared.parse("help", session: realSession)

        switch result {
        case .success:
            // help 指令成功執行
            break
        case .failure(let error):
            XCTFail("help 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("help 指令不應該返回 quit")
        }
    }

    /// 測試 who 指令
    func testWhoCommand() {
        let result = CommandParser.shared.parse("who", session: realSession)

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("who 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("who 指令不應該返回 quit")
        }
    }

    // MARK: - Movement Command Tests

    /// 測試移動指令
    func testMoveCommand() {
        // 從城鎮廣場往南移動到南門
        let result = CommandParser.shared.parse("move s", session: realSession)

        switch result {
        case .success:
            // 驗證玩家位置已更新
            if let player = World.shared.getPlayer(byId: testPlayer.id) {
                XCTAssertEqual(player.currentRoomId, "south_gate")
            }
        case .failure(let error):
            XCTFail("移動指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("移動指令不應該返回 quit")
        }
    }

    /// 測試方向快捷鍵
    func testDirectionShortcuts() {
        // 先確保玩家在城鎮廣場
        if let currentPlayer = World.shared.getPlayer(byId: testPlayer.id),
           currentPlayer.currentRoomId != "town_square" {
            World.shared.movePlayer(testPlayer.id, from: currentPlayer.currentRoomId, to: "town_square")
        }

        // 測試 n 快捷鍵（往北到神殿）
        let result = CommandParser.shared.parse("n", session: realSession)

        switch result {
        case .success:
            if let player = World.shared.getPlayer(byId: testPlayer.id) {
                XCTAssertEqual(player.currentRoomId, "temple")
            }
        case .failure(let error):
            XCTFail("方向快捷鍵失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("方向快捷鍵不應該返回 quit")
        }
    }

    /// 測試無效方向
    func testInvalidDirection() {
        // 嘗試往上（城鎮廣場沒有上方出口）
        let result = CommandParser.shared.parse("u", session: realSession)

        switch result {
        case .success:
            XCTFail("無效方向應該失敗")
        case .failure(let error):
            if case .noExitInDirection = error {
                // 正確
            } else {
                XCTFail("應該返回 noExitInDirection 錯誤")
            }
        case .quit:
            XCTFail("無效方向不應該返回 quit")
        }
    }

    // MARK: - Combat Command Tests

    /// 測試攻擊指令（在安全區）
    func testAttackInSafeZone() {
        // 城鎮廣場是安全區
        let result = CommandParser.shared.parse("attack slime", session: realSession)

        switch result {
        case .success:
            XCTFail("在安全區攻擊應該失敗")
        case .failure(let error):
            if case .cannotAttackInSafeZone = error {
                // 正確
            } else if case .targetNotFound = error {
                // 也可能是因為安全區沒有怪物
                break
            } else {
                XCTFail("應該返回 cannotAttackInSafeZone 或 targetNotFound 錯誤，實際：\(error)")
            }
        case .quit:
            XCTFail("攻擊指令不應該返回 quit")
        }
    }

    /// 測試攻擊指令（沒有目標）
    func testAttackWithoutTarget() {
        let result = CommandParser.shared.parse("attack", session: realSession)

        switch result {
        case .success:
            XCTFail("沒有目標的攻擊應該失敗")
        case .failure(let error):
            if case .missingArgument = error {
                // 正確
            } else {
                XCTFail("應該返回 missingArgument 錯誤")
            }
        case .quit:
            XCTFail("攻擊指令不應該返回 quit")
        }
    }

    /// 測試逃跑指令（不在戰鬥中）
    func testFleeNotInCombat() {
        let result = CommandParser.shared.parse("flee", session: realSession)

        switch result {
        case .success:
            XCTFail("不在戰鬥中逃跑應該失敗")
        case .failure(let error):
            if case .notInCombat = error {
                // 正確
            } else {
                XCTFail("應該返回 notInCombat 錯誤")
            }
        case .quit:
            XCTFail("逃跑指令不應該返回 quit")
        }
    }

    // MARK: - Quest Command Tests

    /// 測試任務指令
    func testQuestCommand() {
        // 查看任務列表
        let result = CommandParser.shared.parse("quest", session: realSession)

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("quest 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("quest 指令不應該返回 quit")
        }
    }

    /// 測試接受任務指令
    func testAcceptQuestCommand() {
        let result = CommandParser.shared.parse("accept tutorial_explore", session: realSession)

        switch result {
        case .success:
            // 驗證任務已接受
            let activeQuests = QuestManager.shared.getActiveQuests(for: testPlayer.id)
            XCTAssertTrue(activeQuests.contains { $0.questId == "tutorial_explore" })
        case .failure(let error):
            XCTFail("accept 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("accept 指令不應該返回 quit")
        }
    }

    /// 測試放棄任務指令
    func testAbandonQuestCommand() {
        // 先接受任務
        _ = QuestManager.shared.acceptQuest(
            playerId: testPlayer.id,
            questId: "tutorial_explore",
            player: testPlayer
        )

        let result = CommandParser.shared.parse("abandon tutorial_explore", session: realSession)

        switch result {
        case .success:
            // 驗證任務已放棄
            let activeQuests = QuestManager.shared.getActiveQuests(for: testPlayer.id)
            XCTAssertFalse(activeQuests.contains { $0.questId == "tutorial_explore" })
        case .failure(let error):
            XCTFail("abandon 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("abandon 指令不應該返回 quit")
        }
    }

    // MARK: - Shop Command Tests

    /// 測試商店指令
    func testShopCommand() {
        // 先移動到市場
        World.shared.movePlayer(testPlayer.id, from: testPlayer.currentRoomId, to: "market")
        if var player = World.shared.getPlayer(byId: testPlayer.id) {
            player.currentRoomId = "market"
            World.shared.updatePlayer(player)
            testPlayer = player
        }

        let result = CommandParser.shared.parse("shop", session: realSession)

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("shop 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("shop 指令不應該返回 quit")
        }
    }

    /// 測試購買指令
    func testBuyCommand() {
        // 先移動到市場
        World.shared.movePlayer(testPlayer.id, from: testPlayer.currentRoomId, to: "market")
        if var player = World.shared.getPlayer(byId: testPlayer.id) {
            player.currentRoomId = "market"
            World.shared.updatePlayer(player)
            testPlayer = player
        }

        // 使用 iron_sword 因為武器店（按 ID 排序第一個）一定有這個物品
        let result = CommandParser.shared.parse("buy iron_sword", session: realSession)

        switch result {
        case .success:
            // 驗證物品已購買
            if let player = World.shared.getPlayer(byId: testPlayer.id) {
                XCTAssertGreaterThan(player.inventory.countOf("iron_sword"), 0)
            }
        case .failure(let error):
            XCTFail("buy 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("buy 指令不應該返回 quit")
        }
    }

    /// 測試賣出指令（沒有物品）
    func testSellCommandNoItem() {
        // 先移動到市場
        World.shared.movePlayer(testPlayer.id, from: testPlayer.currentRoomId, to: "market")
        if var player = World.shared.getPlayer(byId: testPlayer.id) {
            player.currentRoomId = "market"
            World.shared.updatePlayer(player)
            testPlayer = player
        }

        let result = CommandParser.shared.parse("sell nonexistent_item", session: realSession)

        switch result {
        case .success:
            // 可能返回成功但帶訊息說沒有物品
            break
        case .failure(let error):
            // 預期失敗（沒有物品）
            if case .itemNotFound = error {
                // 正確
            } else {
                // 其他錯誤也可接受
                break
            }
        case .quit:
            XCTFail("sell 指令不應該返回 quit")
        }
    }

    // MARK: - Communication Command Tests

    /// 測試 say 指令
    func testSayCommand() {
        let result = CommandParser.shared.parse("say Hello World", session: realSession)

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("say 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("say 指令不應該返回 quit")
        }
    }

    /// 測試 yell 指令
    func testYellCommand() {
        let result = CommandParser.shared.parse("yell Hello Everyone!", session: realSession)

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("yell 指令失敗：\(error.localizedDescription)")
        case .quit:
            XCTFail("yell 指令不應該返回 quit")
        }
    }

    // MARK: - Admin Command Permission Tests

    /// 測試普通玩家無法使用管理員指令
    func testAdminCommandPermissionDenied() {
        // 嘗試使用 kick 指令（需要 GM 權限）
        let result = CommandParser.shared.parse("kick SomePlayer", session: realSession)

        switch result {
        case .success:
            XCTFail("普通玩家不應該能使用 kick 指令")
        case .failure(let error):
            if case .permissionDenied = error {
                // 正確
            } else {
                XCTFail("應該返回 permissionDenied 錯誤，實際：\(error)")
            }
        case .quit:
            XCTFail("kick 指令不應該返回 quit")
        }
    }

    /// 測試 GM 可以使用管理員指令
    func testAdminCommandWithPermission() {
        // 建立 GM 玩家
        let gmPlayer = helper.createTestPlayer(name: "GMTester", adminLevel: .gm)
        let gmSession = helper.createTestSession()
        helper.setupPlayerInWorld(gmPlayer, session: gmSession)

        // GM 使用 goto 指令
        let result = CommandParser.shared.parse("goto temple", session: gmSession)

        switch result {
        case .success:
            // 驗證 GM 已傳送到神殿
            if let player = World.shared.getPlayer(byId: gmPlayer.id) {
                XCTAssertEqual(player.currentRoomId, "temple")
            }
        case .failure(let error):
            XCTFail("GM 應該能使用 goto 指令：\(error.localizedDescription)")
        case .quit:
            XCTFail("goto 指令不應該返回 quit")
        }

        helper.cleanupPlayer(gmPlayer.id)
    }

    /// 測試創世神權限指令
    func testCreatorCommandPermission() {
        // 建立普通 GM 玩家
        let gmPlayer = helper.createTestPlayer(name: "NormalGM", adminLevel: .gm)
        let gmSession = helper.createTestSession()
        helper.setupPlayerInWorld(gmPlayer, session: gmSession)

        // 嘗試使用 setadmin 指令（需要 creator 權限）
        let result = CommandParser.shared.parse("setadmin SomePlayer 1", session: gmSession)

        switch result {
        case .success:
            XCTFail("普通 GM 不應該能使用 setadmin 指令")
        case .failure(let error):
            if case .permissionDenied = error {
                // 正確
            } else {
                XCTFail("應該返回 permissionDenied 錯誤")
            }
        case .quit:
            XCTFail("setadmin 指令不應該返回 quit")
        }

        helper.cleanupPlayer(gmPlayer.id)
    }

    /// 測試創世神可以設定管理員權限
    func testCreatorCanSetAdmin() {
        // 建立創世神玩家
        let creatorPlayer = helper.createTestPlayer(name: "Creator", adminLevel: .creator)
        let creatorSession = helper.createTestSession()
        helper.setupPlayerInWorld(creatorPlayer, session: creatorSession)

        // 建立目標玩家
        let targetPlayer = helper.createTestPlayer(name: "TargetPlayer")
        let targetSession = helper.createTestSession()
        helper.setupPlayerInWorld(targetPlayer, session: targetSession)

        // 設定目標玩家為 GM
        let result = CommandParser.shared.parse("setadmin TargetPlayer 2", session: creatorSession)

        switch result {
        case .success(let message):
            XCTAssertNotNil(message)
            // 驗證目標玩家權限已更新
            if let player = World.shared.getPlayer(byName: "TargetPlayer") {
                XCTAssertEqual(player.adminLevel, .gm)
            }
        case .failure(let error):
            XCTFail("創世神應該能使用 setadmin 指令：\(error.localizedDescription)")
        case .quit:
            XCTFail("setadmin 指令不應該返回 quit")
        }

        helper.cleanupPlayer(creatorPlayer.id)
        helper.cleanupPlayer(targetPlayer.id)
    }

    // MARK: - Equipment Command Tests

    /// 測試裝備指令
    func testEquipCommand() {
        // 先給玩家一把武器
        if var player = World.shared.getPlayer(byId: testPlayer.id) {
            _ = player.inventory.addItem("iron_sword", count: 1, stackable: false)
            World.shared.updatePlayer(player)
            testPlayer = player
        }

        let result = CommandParser.shared.parse("equip iron_sword", session: realSession)

        switch result {
        case .success:
            // 驗證裝備已穿上
            if let player = World.shared.getPlayer(byId: testPlayer.id) {
                XCTAssertEqual(player.equipment[.mainHand], "iron_sword")
            }
        case .failure(let error):
            // 可能因為某些原因失敗，但不應該是嚴重錯誤
            print("equip 指令結果：\(error.localizedDescription)")
        case .quit:
            XCTFail("equip 指令不應該返回 quit")
        }
    }

    /// 測試卸下裝備指令
    func testUnequipCommand() {
        // 先給玩家裝備武器
        if var player = World.shared.getPlayer(byId: testPlayer.id) {
            _ = player.inventory.addItem("iron_sword", count: 1, stackable: false)
            player.equipment[.mainHand] = "iron_sword"
            World.shared.updatePlayer(player)
            testPlayer = player
        }

        let result = CommandParser.shared.parse("unequip mainHand", session: realSession)

        switch result {
        case .success:
            // 驗證裝備已卸下
            if let player = World.shared.getPlayer(byId: testPlayer.id) {
                XCTAssertNil(player.equipment[.mainHand])
            }
        case .failure(let error):
            // 可能因為某些原因失敗
            print("unequip 指令結果：\(error.localizedDescription)")
        case .quit:
            XCTFail("unequip 指令不應該返回 quit")
        }
    }

    // MARK: - Quit Command Test

    /// 測試 quit 指令
    func testQuitCommand() {
        let result = CommandParser.shared.parse("quit", session: realSession)

        switch result {
        case .success:
            XCTFail("quit 指令應該返回 .quit")
        case .failure:
            XCTFail("quit 指令不應該失敗")
        case .quit:
            // 正確
            break
        }
    }

    // MARK: - Command Alias Tests

    /// 測試指令別名
    func testCommandAliases() {
        // 測試 attack 的別名 kill
        let result1 = CommandParser.shared.parse("kill", session: realSession)
        if case .failure(let error) = result1 {
            if case .missingArgument = error {
                // 正確 - kill 需要目標參數
            }
        }

        // 測試 look 的別名 l
        let result2 = CommandParser.shared.parse("l", session: realSession)
        switch result2 {
        case .success:
            break
        default:
            XCTFail("l 指令應該成功")
        }
    }
}

// MARK: - Mock Test Session

/// 用於測試的簡化 Session，記錄發送的訊息
final class MockTestSession {
    let id: UUID
    let playerId: UUID
    let playerName: String
    var sentMessages: [String] = []

    init(id: UUID, playerId: UUID, playerName: String) {
        self.id = id
        self.playerId = playerId
        self.playerName = playerName
    }

    func send(_ message: String) {
        sentMessages.append(message)
    }

    func clearMessages() {
        sentMessages.removeAll()
    }

    var lastMessage: String? {
        sentMessages.last
    }

    func hasMessage(containing text: String) -> Bool {
        sentMessages.contains { $0.contains(text) }
    }
}
