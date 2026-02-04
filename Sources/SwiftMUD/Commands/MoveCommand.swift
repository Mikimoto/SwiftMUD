import Foundation

final class MoveCommand: Command {
    static let name = "move"
    static let aliases = ["go", "走"]
    static let description = "移動到指定方向"
    static let usage = "move <方向> 或直接輸入方向 (n/s/e/w/u/d)"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard let directionStr = context.args.first else {
            return .failure(error: .missingArgument(name: "方向"))
        }

        guard let direction = parseDirection(directionStr) else {
            return .failure(error: .invalidDirection(direction: directionStr))
        }

        guard let room = World.shared.getRoom(context.player.currentRoomId) else {
            return .failure(error: .roomNotFound(id: context.player.currentRoomId))
        }

        guard let destinationId = room.exits[direction] else {
            return .failure(error: .noExitInDirection(direction: direction))
        }

        guard World.shared.getRoom(destinationId) != nil else {
            return .failure(error: .roomNotFound(id: destinationId))
        }

        let player = context.player

        SessionManager.shared.broadcast(
            "\(player.name) 往\(direction.displayName)離開了。",
            inRoom: player.currentRoomId,
            except: player.id
        )

        World.shared.movePlayer(player.id, from: player.currentRoomId, to: destinationId)

        SessionManager.shared.broadcast(
            "\(player.name) 從\(direction.opposite.displayName)進來了。",
            inRoom: destinationId,
            except: player.id
        )

        showRoom(context: context, roomId: destinationId)
        return .success(message: nil)
    }

    private func parseDirection(_ input: String) -> Direction? {
        switch input.lowercased() {
        case "n", "north", "北": return .north
        case "s", "south", "南": return .south
        case "e", "east", "東": return .east
        case "w", "west", "西": return .west
        case "u", "up", "上": return .up
        case "d", "down", "下": return .down
        default: return nil
        }
    }

    private func showRoom(context: CommandContext, roomId: String) {
        guard let room = World.shared.getRoom(roomId) else { return }

        let otherPlayers = World.shared.getPlayersInRoom(roomId)
            .filter { $0.id != context.playerId }
            .map { $0.name }

        let monsters = World.shared.getMonstersInRoom(roomId)
            .filter { $0.isAlive }
            .map { $0.name }

        let description = room.fullDescription(playerNames: otherPlayers, monsterNames: monsters)
        context.session.send(description)
    }
}
