import Foundation

/// 通用的 JSON 檔案儲存服務
/// 提供將 Codable 物件儲存到 JSON 檔案的功能
final class JSONFileStorage {
    /// 儲存目錄的根路徑
    let baseDirectory: URL

    /// 檔案管理器
    private let fileManager: FileManager

    /// JSON 編碼器
    private let encoder: JSONEncoder

    /// JSON 解碼器
    private let decoder: JSONDecoder

    /// 初始化 JSON 檔案儲存服務
    /// - Parameters:
    ///   - baseDirectory: 儲存目錄的根路徑
    ///   - fileManager: 檔案管理器，預設使用系統預設
    init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    /// 確保目錄存在
    /// - Parameter directory: 目錄路徑
    /// - Throws: 無法建立目錄時拋出錯誤
    func ensureDirectoryExists(_ directory: URL) throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// 儲存物件到 JSON 檔案
    /// - Parameters:
    ///   - object: 要儲存的物件
    ///   - filePath: 檔案路徑（相對於 baseDirectory）
    /// - Throws: 編碼或寫入失敗時拋出錯誤
    func save<T: Encodable>(_ object: T, to filePath: String) throws {
        let fileURL = baseDirectory.appendingPathComponent(filePath)
        let directory = fileURL.deletingLastPathComponent()

        try ensureDirectoryExists(directory)

        let data = try encoder.encode(object)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 從 JSON 檔案載入物件
    /// - Parameters:
    ///   - type: 要載入的物件類型
    ///   - filePath: 檔案路徑（相對於 baseDirectory）
    /// - Returns: 載入的物件，若檔案不存在則返回 nil
    /// - Throws: 解碼失敗時拋出錯誤
    func load<T: Decodable>(_ type: T.Type, from filePath: String) throws -> T? {
        let fileURL = baseDirectory.appendingPathComponent(filePath)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(type, from: data)
    }

    /// 刪除檔案
    /// - Parameter filePath: 檔案路徑（相對於 baseDirectory）
    /// - Throws: 刪除失敗時拋出錯誤
    func delete(filePath: String) throws {
        let fileURL = baseDirectory.appendingPathComponent(filePath)

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// 檢查檔案是否存在
    /// - Parameter filePath: 檔案路徑（相對於 baseDirectory）
    /// - Returns: 檔案是否存在
    func exists(filePath: String) -> Bool {
        let fileURL = baseDirectory.appendingPathComponent(filePath)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// 列出目錄下的所有檔案
    /// - Parameter directory: 目錄路徑（相對於 baseDirectory）
    /// - Returns: 檔案名稱陣列
    /// - Throws: 讀取目錄失敗時拋出錯誤
    func listFiles(in directory: String) throws -> [String] {
        let directoryURL = baseDirectory.appendingPathComponent(directory)

        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        return try fileManager.contentsOfDirectory(atPath: directoryURL.path)
    }
}

// MARK: - Async 擴展

extension JSONFileStorage {
    /// 非同步儲存物件到 JSON 檔案
    func saveAsync<T: Encodable>(_ object: T, to filePath: String) async throws {
        try save(object, to: filePath)
    }

    /// 非同步從 JSON 檔案載入物件
    func loadAsync<T: Decodable>(_ type: T.Type, from filePath: String) async throws -> T? {
        try load(type, from: filePath)
    }

    /// 非同步刪除檔案
    func deleteAsync(filePath: String) async throws {
        try delete(filePath: filePath)
    }

    /// 非同步列出目錄下的所有檔案
    func listFilesAsync(in directory: String) async throws -> [String] {
        try listFiles(in: directory)
    }
}
