import Foundation

/// 基於 JSON 檔案的玩家資料儲存庫實作
/// 將玩家資料儲存為 JSON 檔案，檔名使用玩家的 UUID
final class JSONPlayerRepository: PlayerRepository {
    typealias Entity = Player

    /// 玩家資料儲存子目錄
    private static let playersDirectory = "players"

    /// JSON 檔案儲存服務
    private let storage: JSONFileStorage

    /// 玩家名稱索引快取 (名稱小寫 -> UUID)
    private var nameIndex: [String: UUID] = [:]

    /// 名稱索引鎖
    private let indexLock = NSLock()

    /// 初始化 JSON 玩家儲存庫
    /// - Parameter storage: JSON 檔案儲存服務
    init(storage: JSONFileStorage) {
        self.storage = storage
        buildNameIndex()
    }

    /// 便利初始化器：使用目錄路徑
    /// - Parameter baseDirectory: 儲存目錄的根路徑
    convenience init(baseDirectory: URL) {
        self.init(storage: JSONFileStorage(baseDirectory: baseDirectory))
    }

    // MARK: - Repository Protocol

    func save(_ entity: Player) async throws {
        let filePath = Self.filePath(for: entity.id)
        try storage.save(entity, to: filePath)

        // 更新名稱索引
        indexLock.withLock {
            nameIndex[entity.name.lowercased()] = entity.id
        }
    }

    func load(id: UUID) async throws -> Player? {
        let filePath = Self.filePath(for: id)
        return try storage.load(Player.self, from: filePath)
    }

    func delete(id: UUID) async throws {
        // 先載入玩家資料以更新索引
        if let player = try await load(id: id) {
            indexLock.withLock {
                _ = nameIndex.removeValue(forKey: player.name.lowercased())
            }
        }

        let filePath = Self.filePath(for: id)
        try storage.delete(filePath: filePath)
    }

    func loadAll() async throws -> [Player] {
        let files = try storage.listFiles(in: Self.playersDirectory)
        var players: [Player] = []

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(Self.playersDirectory)/\(file)"
            if let player = try storage.load(Player.self, from: filePath) {
                players.append(player)
            }
        }

        return players
    }

    // MARK: - PlayerRepository Protocol

    func loadByName(_ name: String) async throws -> Player? {
        let playerId = indexLock.withLock {
            nameIndex[name.lowercased()]
        }

        guard let id = playerId else {
            return nil
        }

        return try await load(id: id)
    }

    // MARK: - Synchronous Methods (for World integration)

    /// 同步儲存玩家資料
    /// - Parameter player: 要儲存的玩家
    /// - Throws: 儲存失敗時拋出錯誤
    func saveSync(_ player: Player) throws {
        let filePath = Self.filePath(for: player.id)
        try storage.save(player, to: filePath)

        indexLock.lock()
        nameIndex[player.name.lowercased()] = player.id
        indexLock.unlock()
    }

    /// 同步根據 ID 載入玩家資料
    /// - Parameter id: 玩家 UUID
    /// - Returns: 玩家資料，若不存在則返回 nil
    /// - Throws: 載入失敗時拋出錯誤
    func loadSync(id: UUID) throws -> Player? {
        let filePath = Self.filePath(for: id)
        return try storage.load(Player.self, from: filePath)
    }

    /// 同步根據名稱載入玩家資料
    /// - Parameter name: 玩家名稱
    /// - Returns: 玩家資料，若不存在則返回 nil
    /// - Throws: 載入失敗時拋出錯誤
    func loadByNameSync(_ name: String) throws -> Player? {
        indexLock.lock()
        let playerId = nameIndex[name.lowercased()]
        indexLock.unlock()

        guard let id = playerId else {
            return nil
        }

        return try loadSync(id: id)
    }

    // MARK: - Private Helpers

    /// 計算玩家資料的檔案路徑
    private static func filePath(for id: UUID) -> String {
        "\(playersDirectory)/\(id.uuidString).json"
    }

    /// 建立名稱索引
    private func buildNameIndex() {
        guard let files = try? storage.listFiles(in: Self.playersDirectory) else {
            return
        }

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(Self.playersDirectory)/\(file)"
            if let player = try? storage.load(Player.self, from: filePath) {
                nameIndex[player.name.lowercased()] = player.id
            }
        }
    }
}
