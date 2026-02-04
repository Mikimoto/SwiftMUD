import Foundation

/// 傳送玩家指令 - 將指定玩家傳送到目標位置
final class TeleportCommand: Command {
    static let name = "teleport"
    static let aliases = ["tp", "傳送"]
    static let description = "傳送玩家到指定房間"
    static let usage = "teleport <玩家名稱> <房間ID>"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 2 else {
            return .failure(error: .invalidArguments(expected: "teleport <玩家名稱> <房間ID>"))
        }

        let targetName = context.args[0]
        let roomId = context.args[1]

        guard let targetPlayer = World.shared.getPlayer(byName: targetName) else {
            return .failure(error: .playerNotFound(name: targetName))
        }

        guard let targetRoom = World.shared.getRoom(roomId) else {
            return .failure(error: .roomNotFound(id: roomId))
        }

        // 執行傳送
        let oldRoomId = targetPlayer.currentRoomId
        World.shared.movePlayer(targetPlayer.id, from: oldRoomId, to: roomId)

        var updatedPlayer = targetPlayer
        updatedPlayer.currentRoomId = roomId
        World.shared.updatePlayer(updatedPlayer)

        // 通知目標玩家
        if let targetSession = SessionManager.shared.getSession(byPlayerId: targetPlayer.id) {
            targetSession.send("""
            一陣眩暈感襲來...
            你被傳送到了新的地點！

            【\(targetRoom.name)】
            \(targetRoom.description)
            """)
        }

        // 通知舊房間的玩家
        for player in World.shared.getPlayersInRoom(oldRoomId) where player.id != targetPlayer.id {
            if let session = SessionManager.shared.getSession(byPlayerId: player.id) {
                session.send("\(targetName) 在一道閃光中消失了。")
            }
        }

        // 通知新房間的玩家
        for player in World.shared.getPlayersInRoom(roomId) where player.id != targetPlayer.id {
            if let session = SessionManager.shared.getSession(byPlayerId: player.id) {
                session.send("\(targetName) 在一道閃光中出現了。")
            }
        }

        return .success(message: "已將玩家 \(targetName) 傳送到 \(targetRoom.name)（\(roomId)）")
    }
}
