import Foundation

enum MUDError: Error, Equatable {
    // 連線相關
    case connectionFailed(reason: String)
    case sessionExpired
    case notLoggedIn

    // 玩家相關
    case playerNotFound(name: String)
    case playerAlreadyExists(name: String)
    case invalidCredentials
    case accountBanned(until: Date?)
    case accountMuted(until: Date?)

    // 房間與移動
    case roomNotFound(id: String)
    case invalidDirection(direction: String)
    case noExitInDirection(direction: Direction)

    // 指令相關
    case invalidCommand(command: String)
    case unknownCommand(command: String)
    case missingArgument(name: String)
    case invalidArgument(name: String, value: String)

    // 物品與交易
    case itemNotFound(id: String)
    case insufficientGold(required: Int, has: Int)
    case inventoryFull
    case cannotEquip(reason: String)
    case levelTooLow(required: Int, has: Int)

    // 戰鬥相關
    case notInCombat
    case alreadyInCombat
    case targetNotFound(name: String)
    case cannotAttackInSafeZone
    case skillOnCooldown(skillId: String, remaining: TimeInterval)
    case insufficientMP(required: Int, has: Int)
    case stillCasting
    case skillNotLearned(skillId: String)
    case prerequisiteNotMet(skillId: String, required: String, requiredLevel: Int)

    // 任務相關
    case questNotFound(id: String)
    case questAlreadyActive(id: String)
    case questNotActive(id: String)
    case questPrerequisiteNotMet(required: String)
    case questObjectiveNotComplete
    case questOnCooldown(remaining: TimeInterval)

    // 權限相關
    case permissionDenied(required: AdminTier)
    case targetHigherRank
    case cannotTargetSelf

    // 系統相關
    case databaseError(message: String)
    case configurationError(message: String)

    var localizedDescription: String {
        switch self {
        case .connectionFailed(let reason):
            return "連線失敗：\(reason)"
        case .sessionExpired:
            return "連線已過期，請重新登入"
        case .notLoggedIn:
            return "請先登入"
        case .playerNotFound(let name):
            return "找不到玩家：\(name)"
        case .playerAlreadyExists(let name):
            return "玩家名稱已被使用：\(name)"
        case .invalidCredentials:
            return "帳號或密碼錯誤"
        case .accountBanned(let until):
            if let until = until {
                return "帳號已被封禁至 \(until)"
            }
            return "帳號已被永久封禁"
        case .accountMuted(let until):
            if let until = until {
                return "你已被禁言至 \(until)"
            }
            return "你已被永久禁言"
        case .roomNotFound(let id):
            return "找不到房間：\(id)"
        case .invalidDirection(let direction):
            return "無效的方向：\(direction)"
        case .noExitInDirection(let direction):
            return "那個方向沒有出口（\(direction.displayName)）"
        case .invalidCommand(let command):
            return "無效的指令：\(command)"
        case .unknownCommand(let command):
            return "未知的指令：\(command)。輸入 help 查看可用指令。"
        case .missingArgument(let name):
            return "缺少參數：\(name)"
        case .invalidArgument(let name, let value):
            return "無效的參數 \(name)：\(value)"
        case .itemNotFound(let id):
            return "找不到物品：\(id)"
        case .insufficientGold(let required, let has):
            return "金幣不足！需要 \(required)，只有 \(has)"
        case .inventoryFull:
            return "背包已滿"
        case .cannotEquip(let reason):
            return "無法裝備：\(reason)"
        case .levelTooLow(let required, let has):
            return "等級不足！需要 \(required) 級，目前 \(has) 級"
        case .notInCombat:
            return "你不在戰鬥中"
        case .alreadyInCombat:
            return "你已經在戰鬥中了"
        case .targetNotFound(let name):
            return "找不到目標：\(name)"
        case .cannotAttackInSafeZone:
            return "這裡是安全區，無法進行戰鬥"
        case .skillOnCooldown(let skillId, let remaining):
            return "技能 \(skillId) 冷卻中，剩餘 \(String(format: "%.1f", remaining)) 秒"
        case .insufficientMP(let required, let has):
            return "MP 不足！需要 \(required)，只有 \(has)"
        case .stillCasting:
            return "正在施法中，請稍候"
        case .skillNotLearned(let skillId):
            return "你還沒學會技能：\(skillId)"
        case .prerequisiteNotMet(_, let required, let requiredLevel):
            return "需要先將 \(required) 升到 \(requiredLevel) 級"
        case .questNotFound(let id):
            return "找不到任務：\(id)"
        case .questAlreadyActive(let id):
            return "任務已在進行中：\(id)"
        case .questNotActive(let id):
            return "你沒有接這個任務：\(id)"
        case .questPrerequisiteNotMet(let required):
            return "需要先完成任務：\(required)"
        case .questObjectiveNotComplete:
            return "任務目標尚未完成"
        case .questOnCooldown(let remaining):
            return "任務冷卻中，剩餘 \(Int(remaining)) 秒"
        case .permissionDenied(let required):
            return "權限不足，需要 \(required) 或更高權限"
        case .targetHigherRank:
            return "無法對權限比你高的人執行此操作"
        case .cannotTargetSelf:
            return "無法對自己執行此操作"
        case .databaseError(let message):
            return "資料庫錯誤：\(message)"
        case .configurationError(let message):
            return "設定錯誤：\(message)"
        }
    }
}
