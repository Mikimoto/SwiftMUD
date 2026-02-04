import Foundation

/// 管理員傳送自己到指定房間
final class GotoCommand: Command {
    static let name = "goto"
    static let aliases = ["前往"]
    static let description = "傳送自己到指定房間"
    static let usage = "goto <房間ID>"
    static let requiredAdminLevel: AdminTier = .gm

    func execute(context: CommandContext) -> CommandResult {
        guard context.args.count >= 1 else {
            return .failure(error: .invalidArguments(expected: "goto <房間ID>"))
        }

        let roomId = context.args[0]

        guard let targetRoom = World.shared.getRoom(roomId) else {
            return .failure(error: .roomNotFound(id: roomId))
        }

        let oldRoomId = context.player.currentRoomId

        // 通知舊房間的玩家
        for player in World.shared.getPlayersInRoom(oldRoomId) where player.id != context.player.id {
            if let session = SessionManager.shared.getSession(byPlayerId: player.id) {
                session.send("\(context.player.name) 消失在一道光芒中。")
            }
        }

        // 執行移動
        World.shared.movePlayer(context.player.id, from: oldRoomId, to: roomId)

        var updatedPlayer = context.player
        updatedPlayer.currentRoomId = roomId
        World.shared.updatePlayer(updatedPlayer)

        // 通知新房間的玩家
        for player in World.shared.getPlayersInRoom(roomId) where player.id != context.player.id {
            if let session = SessionManager.shared.getSession(byPlayerId: player.id) {
                session.send("\(context.player.name) 出現在一道光芒中。")
            }
        }

        return .success(message: """
        你傳送到了新的地點...

        【\(targetRoom.name)】
        \(targetRoom.description)
        """)
    }
}
