import Foundation

/// 通用的 Repository 協定，提供基本的 CRUD 操作
/// 使用 async/await 支援非同步操作
protocol Repository {
    /// 實體類型，必須遵循 Codable 和 Identifiable
    associatedtype Entity: Codable & Identifiable where Entity.ID == UUID

    /// 儲存實體
    /// - Parameter entity: 要儲存的實體
    /// - Throws: 儲存失敗時拋出錯誤
    func save(_ entity: Entity) async throws

    /// 載入指定 ID 的實體
    /// - Parameter id: 實體的唯一識別碼
    /// - Returns: 找到的實體，若不存在則返回 nil
    /// - Throws: 載入失敗時拋出錯誤
    func load(id: UUID) async throws -> Entity?

    /// 刪除指定 ID 的實體
    /// - Parameter id: 要刪除的實體 ID
    /// - Throws: 刪除失敗時拋出錯誤
    func delete(id: UUID) async throws

    /// 載入所有實體
    /// - Returns: 所有實體的陣列
    /// - Throws: 載入失敗時拋出錯誤
    func loadAll() async throws -> [Entity]
}
