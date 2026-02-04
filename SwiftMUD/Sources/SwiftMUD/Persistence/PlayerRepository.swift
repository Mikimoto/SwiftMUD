import Foundation

/// 玩家資料專用的 Repository 協定
/// 繼承自 Repository，並添加按名稱查詢的功能
protocol PlayerRepository: Repository where Entity == Player {
    /// 根據玩家名稱載入玩家資料
    /// - Parameter name: 玩家名稱
    /// - Returns: 找到的玩家，若不存在則返回 nil
    /// - Throws: 載入失敗時拋出錯誤
    func loadByName(_ name: String) async throws -> Player?
}
