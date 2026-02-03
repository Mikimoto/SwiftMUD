import Foundation
import NIO
import Logging

/// 管理所有活動的 Session 和玩家連線
final class SessionManager {
    /// 單例模式
    static let shared = SessionManager()

    /// 日誌記錄器
    private let logger = Logger(label: "SessionManager")

    /// 所有活動的 Session (sessionId -> Session)
    private var sessions: [UUID: Session] = [:]

    /// 玩家到 Session 的映射 (playerId -> sessionId)
    private var playerToSession: [UUID: UUID] = [:]

    /// 線程安全鎖
    private let lock = NSLock()

    /// 私有初始化器，確保單例模式
    private init() {}

    // MARK: - Session Management

    /// 註冊新連線
    /// - Parameter session: 要註冊的 Session
    func register(_ session: Session) {
        lock.lock()
        defer { lock.unlock() }

        sessions[session.id] = session
        logger.info("Session registered", metadata: ["sessionId": "\(session.id)"])
    }

    /// 取消註冊連線並清理玩家狀態
    /// - Parameter sessionId: 要取消註冊的 Session ID
    func unregister(_ sessionId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let session = sessions[sessionId] else {
            logger.warning("Attempted to unregister unknown session", metadata: ["sessionId": "\(sessionId)"])
            return
        }

        // 如果有玩家登入，清理玩家映射
        if let playerId = session.playerId {
            playerToSession.removeValue(forKey: playerId)
            logger.info("Player logged out", metadata: [
                "playerId": "\(playerId)",
                "playerName": "\(session.playerName ?? "unknown")"
            ])
        }

        sessions.removeValue(forKey: sessionId)
        logger.info("Session unregistered", metadata: ["sessionId": "\(sessionId)"])
    }

    /// 取得 session
    /// - Parameter sessionId: Session ID
    /// - Returns: 對應的 Session，如果不存在則返回 nil
    func getSession(_ sessionId: UUID) -> Session? {
        lock.lock()
        defer { lock.unlock() }

        return sessions[sessionId]
    }

    /// 根據玩家 ID 取得 session
    /// - Parameter playerId: 玩家 ID
    /// - Returns: 對應的 Session，如果不存在則返回 nil
    func getSessionForPlayer(_ playerId: UUID) -> Session? {
        lock.lock()
        defer { lock.unlock() }

        guard let sessionId = playerToSession[playerId] else {
            return nil
        }
        return sessions[sessionId]
    }

    // MARK: - Player Management

    /// 處理玩家登入
    /// - Parameters:
    ///   - player: 登入的玩家
    ///   - session: 玩家所在的 Session
    func loginPlayer(_ player: Player, session: Session) {
        lock.lock()
        defer { lock.unlock() }

        // 設定 session 的玩家資訊
        session.playerId = player.id
        session.playerName = player.name
        session.state = .playing

        // 建立玩家到 session 的映射
        playerToSession[player.id] = session.id

        logger.info("Player logged in", metadata: [
            "playerId": "\(player.id)",
            "playerName": "\(player.name)",
            "sessionId": "\(session.id)"
        ])
    }

    /// 檢查玩家是否在線
    /// - Parameter playerName: 玩家名稱
    /// - Returns: 如果玩家在線則返回 true
    func isPlayerOnline(_ playerName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return sessions.values.contains { session in
            session.playerName?.lowercased() == playerName.lowercased() && session.state == .playing
        }
    }

    // MARK: - Messaging

    /// 房間廣播
    /// - Parameters:
    ///   - message: 要廣播的訊息
    ///   - roomId: 房間 ID
    ///   - excludePlayerId: 要排除的玩家 ID（可選）
    func broadcast(_ message: String, inRoom roomId: String, except excludePlayerId: UUID? = nil) {
        lock.lock()
        let sessionsSnapshot = Array(sessions.values)
        lock.unlock()

        for session in sessionsSnapshot {
            guard session.state == .playing,
                  let playerId = session.playerId,
                  playerId != excludePlayerId else {
                continue
            }

            // TODO: 需要從 PlayerManager 或其他地方獲取玩家的當前房間
            // 目前先發送給所有在線玩家（未來需要實作房間系統後修改）
            session.send(message)
        }
    }

    /// 全服廣播
    /// - Parameters:
    ///   - message: 要廣播的訊息
    ///   - excludePlayerId: 要排除的玩家 ID（可選）
    func broadcastGlobal(_ message: String, except excludePlayerId: UUID? = nil) {
        lock.lock()
        let sessionsSnapshot = Array(sessions.values)
        lock.unlock()

        for session in sessionsSnapshot {
            guard session.state == .playing,
                  let playerId = session.playerId,
                  playerId != excludePlayerId else {
                continue
            }

            session.send(message)
        }
    }

    /// 發送訊息給特定玩家
    /// - Parameters:
    ///   - playerId: 目標玩家 ID
    ///   - message: 要發送的訊息
    func sendToPlayer(_ playerId: UUID, message: String) {
        lock.lock()
        guard let sessionId = playerToSession[playerId],
              let session = sessions[sessionId] else {
            lock.unlock()
            logger.warning("Cannot send message to offline player", metadata: ["playerId": "\(playerId)"])
            return
        }
        lock.unlock()

        session.send(message)
    }

    // MARK: - Statistics

    /// 在線玩家數
    var onlinePlayerCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return playerToSession.count
    }

    /// 連線數
    var sessionCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return sessions.count
    }
}
