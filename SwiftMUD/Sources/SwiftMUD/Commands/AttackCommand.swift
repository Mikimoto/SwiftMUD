import Foundation

final class AttackCommand: Command {
    static let name = "attack"
    static let aliases = ["kill", "hit", "攻擊", "打"]
    static let description = "攻擊目標"
    static let usage = "attack <目標名稱>"

    init() {}

    func execute(context: CommandContext) -> CommandResult {
        guard !context.args.isEmpty else {
            return .failure(error: .missingArgument(name: "目標"))
        }

        let targetName = context.args[0].lowercased()
        let player = context.player

        // 檢查是否在安全區
        if let room = World.shared.getRoom(player.currentRoomId), room.isSafeZone {
            return .failure(error: .cannotAttackInSafeZone)
        }

        // 檢查是否已在戰鬥中
        if CombatManager.shared.isInCombat(player.id) {
            let result = CombatManager.shared.processAttack(
                attackerId: player.id,
                attackerType: .player(player.id),
                skill: nil
            )
            context.session.send(result.message)

            if result.targetDied {
                handleTargetDeath(context: context, targetType: result.targetType)
            }

            return .success(message: nil)
        }

        // 尋找目標怪物
        let monstersInRoom = World.shared.getMonstersInRoom(player.currentRoomId)
        if let targetMonster = monstersInRoom.first(where: {
            $0.name.lowercased().contains(targetName) && $0.isAlive
        }) {
            return startCombatWithMonster(context: context, monster: targetMonster)
        }

        return .failure(error: .targetNotFound(name: targetName))
    }

    private func startCombatWithMonster(context: CommandContext, monster: Monster) -> CommandResult {
        let player = context.player

        let result = CombatManager.shared.startCombat(
            playerId: player.id,
            targetId: monster.id,
            targetType: .monster(monster.id),
            roomId: player.currentRoomId
        )

        switch result {
        case .success:
            context.session.send("你開始攻擊 \(monster.name)！")

            SessionManager.shared.broadcast(
                "\(player.name) 開始攻擊 \(monster.name)！",
                inRoom: player.currentRoomId,
                except: player.id
            )

            let attackResult = CombatManager.shared.processAttack(
                attackerId: player.id,
                attackerType: .player(player.id),
                skill: nil
            )
            context.session.send(attackResult.message)

            if attackResult.targetDied {
                handleTargetDeath(context: context, targetType: attackResult.targetType)
            }

            return .success(message: nil)

        case .failure(let error):
            return .failure(error: error)
        }
    }

    private func handleTargetDeath(context: CommandContext, targetType: CombatantType?) {
        guard let targetType = targetType else { return }

        switch targetType {
        case .monster(let monsterId):
            guard let monster = World.shared.getMonster(monsterId),
                  let template = World.shared.monsterTemplates[monster.templateId] else { return }

            let expGained = template.expReward
            let goldGained = Int.random(in: template.goldReward)

            context.session.send("\(monster.name) 被擊敗了！")
            context.session.send("獲得 \(expGained) 經驗值和 \(goldGained) 金幣！")

            if var player = World.shared.getPlayer(byId: context.playerId) {
                let leveledUp = player.gainExp(expGained)
                player.gold += goldGained
                World.shared.updatePlayer(player)

                if leveledUp {
                    context.session.send("恭喜！你升級了！目前等級：\(player.level)")
                }
            }

            CombatManager.shared.leaveCombat(context.playerId)

            SessionManager.shared.broadcast(
                "\(context.player.name) 擊敗了 \(monster.name)！",
                inRoom: context.player.currentRoomId,
                except: context.playerId
            )

        case .player(let playerId):
            CombatManager.shared.leaveCombat(context.playerId)
            CombatManager.shared.leaveCombat(playerId)
        }
    }
}
