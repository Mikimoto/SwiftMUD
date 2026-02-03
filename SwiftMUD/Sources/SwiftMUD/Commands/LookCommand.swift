import Foundation

final class LookCommand: Command {
    static let name = "look"
    static let aliases = ["l", "看"]
    static let description = "查看目前房間"
    static let usage = "look"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard let room = World.shared.getRoom(context.player.currentRoomId) else {
            return .failure(error: .roomNotFound(id: context.player.currentRoomId))
        }

        let otherPlayers = World.shared.getPlayersInRoom(room.id)
            .filter { $0.id != context.playerId }
            .map { $0.name }

        let monsters = World.shared.getMonstersInRoom(room.id)
            .filter { $0.isAlive }
            .map { $0.name }

        let description = room.fullDescription(playerNames: otherPlayers, monsterNames: monsters)
        context.session.send(description)

        return .success(message: nil)
    }
}
