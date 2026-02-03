import Foundation

/// 指令執行結果
enum CommandResult {
    case success(message: String?)
    case failure(error: MUDError)
    case quit
}

/// 指令的執行上下文
struct CommandContext {
    let session: Session
    let playerId: UUID
    var player: Player
    let args: [String]
    let rawInput: String
}

/// 所有遊戲指令必須實作此協定
protocol Command {
    /// 指令名稱（主要名稱）
    static var name: String { get }

    /// 別名
    static var aliases: [String] { get }

    /// 說明
    static var description: String { get }

    /// 用法
    static var usage: String { get }

    /// 執行所需的最低管理權限
    static var requiredAdminLevel: AdminTier { get }

    /// 初始化
    init()

    /// 執行指令
    func execute(context: CommandContext) -> CommandResult
}

extension Command {
    static var aliases: [String] { [] }
    static var requiredAdminLevel: AdminTier { .player }
}
