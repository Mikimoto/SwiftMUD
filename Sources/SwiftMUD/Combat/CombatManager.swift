import Foundation
import Logging

// MARK: - CombatStats

/// 戰鬥屬性結構，用於傷害計算
struct CombatStats {
    let attack: Int
    let defense: Int
    let magic: Int
    let speed: Int

    init(attack: Int, defense: Int, magic: Int, speed: Int) {
        self.attack = attack
        self.defense = defense
        self.magic = magic
        self.speed = speed
    }

    init(from player: Player) {
        self.attack = player.baseAttack
        self.defense = player.baseDefense
        self.magic = player.baseMagic
        self.speed = 10 // 玩家預設速度
    }

    init(from monster: Monster) {
        self.attack = monster.attack
        self.defense = monster.defense
        self.magic = monster.magic
        self.speed = 10 // 怪物預設速度
    }
}

// MARK: - AttackResult

/// 攻擊結果結構
struct AttackResult {
    let success: Bool
    let damage: Int
    let message: String
    let targetDied: Bool
    let targetType: CombatantType?
}

// MARK: - CombatManager

/// 戰鬥管理器，負責管理所有活動戰鬥
///
/// `CombatManager` is marked as `@unchecked Sendable` because it is a
/// shared singleton that can be accessed from multiple concurrent
/// contexts, but it uses manual synchronization instead of Swift's
/// structured concurrency isolation.
///
/// Thread-safety guarantees:
/// - All mutable shared state (`activeCombats`, `participantToCombat`)
///   must be accessed and mutated only while holding `lock`.
/// - `lock` (an `NSLock` instance) provides mutual exclusion so that
///   at most one thread reads or writes the combat dictionaries at a time.
/// - Any future properties that are mutated from multiple threads
///   must either be immutable after initialization or protected by
///   the same lock (or an explicitly documented alternative).
///
/// When modifying this class, ensure that any access to shared mutable
/// state continues to follow the locking discipline described above.
final class CombatManager: @unchecked Sendable {
    static let shared = CombatManager()

    private let logger = Logger(label: "CombatManager")
    private let lock = NSLock()

    /// 活動戰鬥 (戰鬥ID -> 戰鬥狀態)
    private var activeCombats: [UUID: CombatState] = [:]

    /// 參與者到戰鬥的映射 (參與者ID -> 戰鬥ID)
    private var participantToCombat: [UUID: UUID] = [:]

    private init() {}

    // MARK: - Public Methods

    /// 開始戰鬥
    /// - Parameters:
    ///   - playerId: 玩家 ID
    ///   - targetId: 目標 ID
    ///   - targetType: 目標類型
    ///   - roomId: 房間 ID
    /// - Returns: 戰鬥狀態或錯誤
    func startCombat(
        playerId: UUID,
        targetId: UUID,
        targetType: CombatantType,
        roomId: String
    ) -> Result<CombatState, MUDError> {
        lock.lock()
        defer { lock.unlock() }

        // 檢查玩家是否已在戰鬥中
        if participantToCombat[playerId] != nil {
            logger.warning("Player \(playerId) already in combat")
            return .failure(.alreadyInCombat)
        }

        // 檢查目標是否已在戰鬥中
        if participantToCombat[targetId] != nil {
            logger.warning("Target \(targetId) already in combat")
            return .failure(.alreadyInCombat)
        }

        // 建立新戰鬥
        var combat = CombatState(roomId: roomId)
        combat.addParticipant(.player(playerId))
        combat.addParticipant(targetType)

        let combatId = combat.id

        // 註冊戰鬥
        activeCombats[combatId] = combat
        participantToCombat[playerId] = combatId
        participantToCombat[targetId] = combatId

        logger.info("Combat started: \(combatId) in room \(roomId)")
        return .success(combat)
    }

    /// 結束戰鬥
    /// - Parameter combatId: 戰鬥 ID
    func endCombat(_ combatId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let combat = activeCombats[combatId] else {
            logger.warning("Combat \(combatId) not found")
            return
        }

        // 移除所有參與者的映射
        for participant in combat.participants {
            participantToCombat.removeValue(forKey: participant.id)
        }

        // 移除戰鬥
        activeCombats.removeValue(forKey: combatId)
        logger.info("Combat ended: \(combatId)")
    }

    /// 獲取參與者的戰鬥狀態
    /// - Parameter participantId: 參與者 ID
    /// - Returns: 戰鬥狀態（如果存在）
    func getCombat(forParticipant participantId: UUID) -> CombatState? {
        lock.lock()
        defer { lock.unlock() }

        guard let combatId = participantToCombat[participantId] else {
            return nil
        }
        return activeCombats[combatId]
    }

    /// 檢查參與者是否在戰鬥中
    /// - Parameter participantId: 參與者 ID
    /// - Returns: 是否在戰鬥中
    func isInCombat(_ participantId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return participantToCombat[participantId] != nil
    }

    /// 離開戰鬥
    /// - Parameter participantId: 參與者 ID
    func leaveCombat(_ participantId: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard let combatId = participantToCombat[participantId] else {
            logger.warning("Participant \(participantId) not in any combat")
            return
        }

        participantToCombat.removeValue(forKey: participantId)

        if var combat = activeCombats[combatId] {
            combat.removeParticipant(participantId)

            // 如果戰鬥不再活躍（少於2人），結束戰鬥
            if !combat.isActive {
                // 移除剩餘參與者的映射
                for participant in combat.participants {
                    participantToCombat.removeValue(forKey: participant.id)
                }
                activeCombats.removeValue(forKey: combatId)
                logger.info("Combat \(combatId) ended due to insufficient participants")
            } else {
                activeCombats[combatId] = combat
            }
        }

        logger.info("Participant \(participantId) left combat")
    }

    /// 計算傷害
    /// - Parameters:
    ///   - attacker: 攻擊者屬性
    ///   - defender: 防禦者屬性
    ///   - skill: 使用的技能（可選）
    /// - Returns: 最終傷害值
    func calculateDamage(attacker: CombatStats, defender: CombatStats, skill: Skill?) -> Int {
        let baseDamage: Int

        if let skill = skill {
            // 技能攻擊
            baseDamage = calculateSkillDamage(attacker: attacker, skill: skill)
        } else {
            // 普通攻擊
            baseDamage = attacker.attack
        }

        // 防禦減傷公式：defense / (defense + 50)
        let defenseReduction = Double(defender.defense) / Double(defender.defense + 50)

        // 最終傷害 = baseDamage * (1 - defenseReduction)，最小為 1
        let finalDamage = Int(Double(baseDamage) * (1.0 - defenseReduction))
        return max(finalDamage, 1)
    }

    /// 處理攻擊
    /// - Parameters:
    ///   - attackerId: 攻擊者 ID
    ///   - attackerType: 攻擊者類型
    ///   - skill: 使用的技能（可選）
    /// - Returns: 攻擊結果
    func processAttack(
        attackerId: UUID,
        attackerType: CombatantType,
        skill: Skill?
    ) -> AttackResult {
        lock.lock()
        defer { lock.unlock() }

        // 獲取戰鬥狀態
        guard let combatId = participantToCombat[attackerId],
              let combat = activeCombats[combatId] else {
            return AttackResult(
                success: false,
                damage: 0,
                message: "你不在戰鬥中",
                targetDied: false,
                targetType: nil
            )
        }

        // 找到目標（戰鬥中的另一個參與者）
        guard let target = combat.participants.first(where: { $0.id != attackerId }) else {
            return AttackResult(
                success: false,
                damage: 0,
                message: "找不到攻擊目標",
                targetDied: false,
                targetType: nil
            )
        }

        // 這裡需要從外部獲取實際的戰鬥屬性
        // 目前使用預設值作為示例
        let attackerStats = getStatsForCombatant(attackerType)
        let defenderStats = getStatsForCombatant(target)

        let damage = calculateDamage(
            attacker: attackerStats,
            defender: defenderStats,
            skill: skill
        )

        let skillName = skill?.name ?? "普通攻擊"
        let message = "你使用 \(skillName) 造成 \(damage) 點傷害！"

        // 注意：實際的 HP 扣減和死亡判定需要在 World 層處理
        // 這裡返回傷害資訊供上層使用
        return AttackResult(
            success: true,
            damage: damage,
            message: message,
            targetDied: false, // 需要上層判定
            targetType: target
        )
    }

    // MARK: - Private Methods

    /// 計算技能傷害
    private func calculateSkillDamage(attacker: CombatStats, skill: Skill) -> Int {
        var totalDamage = 0

        for effect in skill.effects {
            switch effect {
            case .damage(let base, let scaling, let stat):
                let statValue: Int
                switch stat {
                case .attack:
                    statValue = attacker.attack
                case .magic:
                    statValue = attacker.magic
                case .defense:
                    statValue = attacker.defense
                case .speed:
                    statValue = attacker.speed
                default:
                    statValue = 0
                }
                totalDamage += base + Int(Double(statValue) * scaling)
            default:
                break
            }
        }

        // 如果技能沒有傷害效果，使用基礎攻擊力
        return totalDamage > 0 ? totalDamage : attacker.attack
    }

    /// 獲取戰鬥參與者的屬性（預設值）
    private func getStatsForCombatant(_ combatant: CombatantType) -> CombatStats {
        // 這是預設實作，實際使用時應該從 World 獲取真實數據
        switch combatant {
        case .player:
            return CombatStats(attack: 10, defense: 5, magic: 5, speed: 10)
        case .monster:
            return CombatStats(attack: 8, defense: 3, magic: 3, speed: 8)
        }
    }
}
