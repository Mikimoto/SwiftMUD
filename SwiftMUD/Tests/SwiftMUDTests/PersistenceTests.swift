import XCTest
@testable import SwiftMUD

final class PersistenceTests: XCTestCase {
    var tempDirectory: URL!
    var storage: JSONFileStorage!
    var playerRepository: JSONPlayerRepository!

    override func setUp() {
        super.setUp()

        // 建立臨時目錄
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftMUDTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        storage = JSONFileStorage(baseDirectory: tempDirectory)
        playerRepository = JSONPlayerRepository(storage: storage)
    }

    override func tearDown() {
        // 清理臨時目錄
        try? FileManager.default.removeItem(at: tempDirectory)

        tempDirectory = nil
        storage = nil
        playerRepository = nil

        super.tearDown()
    }

    // MARK: - JSON 編碼/解碼測試

    func testPlayerJSONEncodeDecode() throws {
        let player = Player.create(name: "TestPlayer", passwordHash: "hash123")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(player)
        XCTAssertFalse(data.isEmpty, "編碼後的資料不應為空")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decodedPlayer = try decoder.decode(Player.self, from: data)

        XCTAssertEqual(decodedPlayer.id, player.id)
        XCTAssertEqual(decodedPlayer.name, player.name)
        XCTAssertEqual(decodedPlayer.passwordHash, player.passwordHash)
        XCTAssertEqual(decodedPlayer.level, player.level)
        XCTAssertEqual(decodedPlayer.gold, player.gold)
        XCTAssertEqual(decodedPlayer.currentHP, player.currentHP)
        XCTAssertEqual(decodedPlayer.maxHP, player.maxHP)
        XCTAssertEqual(decodedPlayer.currentRoomId, player.currentRoomId)
        XCTAssertEqual(decodedPlayer.adminLevel, player.adminLevel)
    }

    func testPlayerWithEquipmentEncodeDecode() throws {
        var player = Player.create(name: "EquippedPlayer", passwordHash: "hash456")
        player.equipment[.mainHand] = "iron_sword"
        player.equipment[.body] = "leather_armor"
        _ = player.inventory.addItem("health_potion", count: 5, stackable: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(player)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedPlayer = try decoder.decode(Player.self, from: data)

        XCTAssertEqual(decodedPlayer.equipment[.mainHand], "iron_sword")
        XCTAssertEqual(decodedPlayer.equipment[.body], "leather_armor")
        XCTAssertEqual(decodedPlayer.inventory.countOf("health_potion"), 5)
    }

    // MARK: - JSONFileStorage 測試

    func testStorageSaveAndLoad() throws {
        let player = Player.create(name: "StorageTest", passwordHash: "testhash")

        try storage.save(player, to: "test/player.json")

        let loaded = try storage.load(Player.self, from: "test/player.json")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, player.id)
        XCTAssertEqual(loaded?.name, player.name)
    }

    func testStorageLoadNonExistent() throws {
        let result = try storage.load(Player.self, from: "nonexistent/file.json")
        XCTAssertNil(result)
    }

    func testStorageDelete() throws {
        let player = Player.create(name: "DeleteTest", passwordHash: "hash")

        try storage.save(player, to: "delete/player.json")
        XCTAssertTrue(storage.exists(filePath: "delete/player.json"))

        try storage.delete(filePath: "delete/player.json")
        XCTAssertFalse(storage.exists(filePath: "delete/player.json"))
    }

    func testStorageListFiles() throws {
        let player1 = Player.create(name: "ListTest1", passwordHash: "hash1")
        let player2 = Player.create(name: "ListTest2", passwordHash: "hash2")

        try storage.save(player1, to: "list/player1.json")
        try storage.save(player2, to: "list/player2.json")

        let files = try storage.listFiles(in: "list")
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains("player1.json"))
        XCTAssertTrue(files.contains("player2.json"))
    }

    // MARK: - JSONPlayerRepository 測試

    func testRepositorySaveAndLoadById() async throws {
        let player = Player.create(name: "RepoTest", passwordHash: "repohash")

        try await playerRepository.save(player)

        let loaded = try await playerRepository.load(id: player.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, player.id)
        XCTAssertEqual(loaded?.name, player.name)
    }

    func testRepositoryLoadByName() async throws {
        let player = Player.create(name: "NameTest", passwordHash: "namehash")

        try await playerRepository.save(player)

        let loaded = try await playerRepository.loadByName("NameTest")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, player.id)

        // 測試不區分大小寫
        let loadedLower = try await playerRepository.loadByName("nametest")
        XCTAssertNotNil(loadedLower)
        XCTAssertEqual(loadedLower?.id, player.id)
    }

    func testRepositoryLoadNonExistent() async throws {
        let result = try await playerRepository.loadByName("NonExistent")
        XCTAssertNil(result)
    }

    func testRepositoryDelete() async throws {
        let player = Player.create(name: "DeleteRepoTest", passwordHash: "hash")

        try await playerRepository.save(player)

        let beforeDelete = try await playerRepository.load(id: player.id)
        XCTAssertNotNil(beforeDelete)

        try await playerRepository.delete(id: player.id)

        let afterDelete = try await playerRepository.load(id: player.id)
        XCTAssertNil(afterDelete)

        let afterDeleteByName = try await playerRepository.loadByName("DeleteRepoTest")
        XCTAssertNil(afterDeleteByName)
    }

    func testRepositoryLoadAll() async throws {
        let player1 = Player.create(name: "LoadAll1", passwordHash: "hash1")
        let player2 = Player.create(name: "LoadAll2", passwordHash: "hash2")
        let player3 = Player.create(name: "LoadAll3", passwordHash: "hash3")

        try await playerRepository.save(player1)
        try await playerRepository.save(player2)
        try await playerRepository.save(player3)

        let allPlayers = try await playerRepository.loadAll()
        XCTAssertEqual(allPlayers.count, 3)

        let names = Set(allPlayers.map { $0.name })
        XCTAssertTrue(names.contains("LoadAll1"))
        XCTAssertTrue(names.contains("LoadAll2"))
        XCTAssertTrue(names.contains("LoadAll3"))
    }

    func testRepositorySyncMethods() throws {
        let player = Player.create(name: "SyncTest", passwordHash: "synchash")

        try playerRepository.saveSync(player)

        let loadedById = try playerRepository.loadSync(id: player.id)
        XCTAssertNotNil(loadedById)
        XCTAssertEqual(loadedById?.name, "SyncTest")

        let loadedByName = try playerRepository.loadByNameSync("SyncTest")
        XCTAssertNotNil(loadedByName)
        XCTAssertEqual(loadedByName?.id, player.id)
    }

    // MARK: - World 整合測試

    func testWorldPlayerPersistence() throws {
        // 設定 World 的 playerRepository
        World.shared.setPlayerRepository(playerRepository)

        // 建立並添加玩家
        let player = Player.create(name: "WorldTest", passwordHash: "worldhash")
        World.shared.addPlayer(player)

        // 驗證資料已儲存
        let savedPlayer = try playerRepository.loadByNameSync("WorldTest")
        XCTAssertNotNil(savedPlayer)
        XCTAssertEqual(savedPlayer?.id, player.id)

        // 清理
        World.shared.removePlayer(player.id)
    }

    func testWorldLoadPlayerFromStorage() throws {
        // 先儲存玩家到 repository
        let player = Player.create(name: "LoadFromStorage", passwordHash: "storagehash")
        try playerRepository.saveSync(player)

        // 設定 World 的 playerRepository
        World.shared.setPlayerRepository(playerRepository)

        // 從 storage 載入玩家
        let loadedPlayer = World.shared.loadPlayerFromStorage(byName: "LoadFromStorage")
        XCTAssertNotNil(loadedPlayer)
        XCTAssertEqual(loadedPlayer?.id, player.id)
        XCTAssertEqual(loadedPlayer?.name, "LoadFromStorage")
    }

    func testWorldUpdatePlayerPersistence() throws {
        World.shared.setPlayerRepository(playerRepository)

        var player = Player.create(name: "UpdateTest", passwordHash: "updatehash")
        World.shared.addPlayer(player)

        // 更新玩家資料
        player.gold = 500
        player.level = 5
        World.shared.updatePlayer(player)

        // 驗證更新已儲存
        let savedPlayer = try playerRepository.loadByNameSync("UpdateTest")
        XCTAssertNotNil(savedPlayer)
        XCTAssertEqual(savedPlayer?.gold, 500)
        XCTAssertEqual(savedPlayer?.level, 5)

        // 清理
        World.shared.removePlayer(player.id)
    }
}
