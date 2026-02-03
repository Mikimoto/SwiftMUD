import Foundation

final class FleeCommand: Command {
    static let name = "flee"
    static let aliases = ["run", "escape", "逃跑", "逃"]
    static let description = "逃離戰鬥"
    static let usage = "flee"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        let player = context.player

        guard CombatManager.shared.isInCombat(player.id) else {
            return .failure(error: .notInCombat)
        }

        let escaped = Int.random(in: 1...100) > 30

        if escaped {
            CombatManager.shared.leaveCombat(player.id)

            if let room = World.shared.getRoom(player.currentRoomId),
               let (direction, destinationId) = room.exits.randomElement() {

                World.shared.movePlayer(player.id, from: player.currentRoomId, to: destinationId)

                context.session.send("你成功逃跑了！往\(direction.displayName)方向逃離。")

                SessionManager.shared.broadcast(
                    "\(player.name) 逃跑了！",
                    inRoom: player.currentRoomId,
                    except: player.id
                )

                if let newRoom = World.shared.getRoom(destinationId) {
                    let otherPlayers = World.shared.getPlayersInRoom(destinationId)
                        .filter { $0.id != player.id }
                        .map { $0.name }
                    let monsters = World.shared.getMonstersInRoom(destinationId)
                        .filter { $0.isAlive }
                        .map { $0.name }
                    context.session.send(newRoom.fullDescription(playerNames: otherPlayers, monsterNames: monsters))
                }
            } else {
                context.session.send("你成功逃跑了！")
            }

            return .success(message: nil)
        } else {
            context.session.send("逃跑失敗！")
            return .success(message: nil)
        }
    }
}
