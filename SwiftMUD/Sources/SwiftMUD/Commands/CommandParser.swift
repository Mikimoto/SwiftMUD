import Foundation

/// 指令解析器 - 負責解析玩家輸入並執行對應的指令
final class CommandParser {
    /// 單例模式
    static let shared = CommandParser()

    /// 已註冊的指令類型 (指令名稱/別名 -> Command.Type)
    private var commands: [String: Command.Type] = [:]

    /// 已建立的指令實例 (指令名稱 -> Command)
    private var commandInstances: [String: Command] = [:]

    /// 方向快捷鍵對應表
    private let directionShortcuts: [String: Direction] = [
        "n": .north, "north": .north,
        "s": .south, "south": .south,
        "e": .east, "east": .east,
        "w": .west, "west": .west,
        "u": .up, "up": .up,
        "d": .down, "down": .down
    ]

    private init() {
        registerBuiltInCommands()
    }

    // MARK: - 註冊內建指令

    /// 註冊所有內建指令
    private func registerBuiltInCommands() {
        // 移動指令
        register(MoveCommand.self)

        // 查看指令
        register(LookCommand.self)
        register(StatusCommand.self)
        register(WhoCommand.self)

        // 通訊指令
        register(SayCommand.self)
        register(YellCommand.self)

        // 系統指令
        register(HelpCommand.self)
        register(QuitCommand.self)

        // 戰鬥指令
        register(AttackCommand.self)
        register(FleeCommand.self)
    }

    // MARK: - 指令註冊

    /// 註冊一個指令類型
    /// - Parameter commandType: 要註冊的指令類型
    func register(_ commandType: Command.Type) {
        // 註冊主要名稱
        let name = commandType.name.lowercased()
        commands[name] = commandType
        commandInstances[name] = commandType.init()

        // 註冊所有別名
        for alias in commandType.aliases {
            let aliasLower = alias.lowercased()
            commands[aliasLower] = commandType
            // 別名共享相同的指令實例
            commandInstances[aliasLower] = commandInstances[name]
        }
    }

    // MARK: - 指令解析與執行

    /// 解析並執行玩家輸入
    /// - Parameters:
    ///   - input: 玩家輸入的原始字串
    ///   - session: 玩家的連線 Session
    /// - Returns: 指令執行結果
    func parse(_ input: String, session: Session) -> CommandResult {
        // 取得 playerId
        guard let playerId = session.playerId else {
            return .failure(error: .notLoggedIn)
        }

        // 取得 player
        guard var player = World.shared.getPlayer(byId: playerId) else {
            return .failure(error: .playerNotFound(name: session.playerName ?? "unknown"))
        }

        // 解析輸入
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return .success(message: nil)
        }

        let parts = trimmedInput.split(separator: " ", maxSplits: 1)
        let commandName = String(parts[0]).lowercased()
        let argsString = parts.count > 1 ? String(parts[1]) : ""
        let args = argsString.isEmpty ? [] : argsString.split(separator: " ").map(String.init)

        // 檢查是否為方向快捷鍵
        if let direction = parseDirection(commandName) {
            // 建立移動指令的 context
            let context = CommandContext(
                session: session,
                playerId: playerId,
                player: player,
                args: [direction.rawValue],
                rawInput: trimmedInput
            )

            // 如果有 MoveCommand 則執行，否則直接處理移動
            if let moveCommand = commandInstances["move"] ?? commandInstances["go"] {
                // 檢查權限
                let commandType = type(of: moveCommand)
                if player.adminLevel < commandType.requiredAdminLevel {
                    return .failure(error: .permissionDenied(required: commandType.requiredAdminLevel))
                }
                return moveCommand.execute(context: context)
            } else {
                // 沒有移動指令時，嘗試直接移動
                return handleDirectionMove(direction: direction, player: &player, session: session)
            }
        }

        // 查找指令
        guard let command = commandInstances[commandName] else {
            return .failure(error: .unknownCommand(command: commandName))
        }

        // 取得指令類型以檢查權限
        let commandType = type(of: command)

        // 檢查權限
        if player.adminLevel < commandType.requiredAdminLevel {
            return .failure(error: .permissionDenied(required: commandType.requiredAdminLevel))
        }

        // 建立 context 並執行指令
        let context = CommandContext(
            session: session,
            playerId: playerId,
            player: player,
            args: args,
            rawInput: trimmedInput
        )

        return command.execute(context: context)
    }

    // MARK: - 輔助方法

    /// 解析方向字串
    /// - Parameter input: 輸入字串
    /// - Returns: 對應的方向，如果不是方向則返回 nil
    func parseDirection(_ input: String) -> Direction? {
        return directionShortcuts[input.lowercased()]
    }

    /// 取得所有已註冊指令的資訊
    /// - Returns: 指令資訊陣列 (名稱、說明、用法)
    func getAllCommands() -> [(name: String, description: String, usage: String)] {
        var result: [(name: String, description: String, usage: String)] = []
        var seenNames = Set<String>()

        for (_, commandType) in commands {
            let name = commandType.name
            // 避免因為別名而重複列出同一個指令
            if !seenNames.contains(name) {
                seenNames.insert(name)
                result.append((
                    name: name,
                    description: commandType.description,
                    usage: commandType.usage
                ))
            }
        }

        // 按名稱排序
        return result.sorted { $0.name < $1.name }
    }

    // MARK: - 私有輔助方法

    /// 直接處理方向移動（當沒有 MoveCommand 時的備用方案）
    private func handleDirectionMove(direction: Direction, player: inout Player, session: Session) -> CommandResult {
        guard let room = World.shared.getRoom(player.currentRoomId) else {
            return .failure(error: .roomNotFound(id: player.currentRoomId))
        }

        guard let destinationRoomId = room.exits[direction] else {
            return .failure(error: .noExitInDirection(direction: direction))
        }

        guard let destinationRoom = World.shared.getRoom(destinationRoomId) else {
            return .failure(error: .roomNotFound(id: destinationRoomId))
        }

        // 執行移動
        World.shared.movePlayer(player.id, from: player.currentRoomId, to: destinationRoomId)
        player.currentRoomId = destinationRoomId

        // 顯示新房間
        let message = """
        你往\(direction.displayName)方走去...

        【\(destinationRoom.name)】
        \(destinationRoom.description)
        """

        return .success(message: message)
    }
}
