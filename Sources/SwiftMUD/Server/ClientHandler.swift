import NIO
import NIOCore
import Logging
import Crypto
import Foundation

final class ClientHandler: ChannelInboundHandler {
    typealias InboundIn = String
    typealias OutboundOut = String

    private var session: Session?
    private var logger = Logger(label: "com.swiftmud.client")

    func channelActive(context: ChannelHandlerContext) {
        let session = Session(channel: context.channel)
        self.session = session

        // 註冊到 SessionManager
        SessionManager.shared.register(session)

        let remoteAddress = context.remoteAddress?.description ?? "unknown"
        logger.info("New connection from \(remoteAddress), session: \(session.id)")

        sendWelcome(context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let input = unwrapInboundIn(data).trimmingCharacters(in: .whitespaces)

        guard !input.isEmpty else { return }
        guard let session = session else { return }

        logger.debug("[\(session.id)] Received: \(input)")

        handleInput(input, session: session, context: context)
    }

    func channelInactive(context: ChannelHandlerContext) {
        guard let session = session else { return }
        logger.info("Connection closed, session: \(session.id)")

        // 清理玩家狀態
        if let playerId = session.playerId {
            World.shared.removePlayer(playerId)
        }

        // 從 SessionManager 取消註冊
        SessionManager.shared.unregister(session.id)

        self.session = nil
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("Error: \(error)")
        context.close(promise: nil)
    }

    private func sendWelcome(context: ChannelHandlerContext) {
        let welcome = """

        ========================================
        |     Welcome to SwiftMUD World!       |
        |                                      |
        |  Type: login <name> <password>       |
        |  Type: register <name> <password>    |
        |  Type: quit to leave                 |
        ========================================

        """
        for line in welcome.split(separator: "\n") {
            _ = context.writeAndFlush(wrapOutboundOut(String(line)))
        }
    }

    private func handleInput(_ input: String, session: Session, context: ChannelHandlerContext) {
        let parts = input.split(separator: " ").map(String.init)
        let command = parts[0].lowercased()
        let args = Array(parts.dropFirst())

        switch session.state {
        case .connected, .authenticating:
            handleAuthCommand(command: command, args: args, session: session, context: context)
        case .playing:
            handleGameCommand(command: command, args: args, session: session, context: context)
        case .disconnecting:
            break
        }
    }

    private func handleAuthCommand(command: String, args: [String], session: Session, context: ChannelHandlerContext) {
        switch command {
        case "quit", "exit":
            session.send("Goodbye!")
            session.close()

        case "login":
            handleLogin(args: args, session: session)

        case "register":
            handleRegister(args: args, session: session)

        case "help":
            session.send("Commands: login <name> <password>, register <name> <password>, quit")

        default:
            session.send("Please login or register first. Type help for instructions.")
        }
    }

    private func handleLogin(args: [String], session: Session) {
        guard args.count >= 2 else {
            session.send("Usage: login <name> <password>")
            return
        }

        let name = args[0]
        let password = args[1]

        // 檢查玩家是否已在線
        if SessionManager.shared.isPlayerOnline(name) {
            session.send("This player is already logged in.")
            return
        }

        // 從 World 查找玩家
        guard let player = World.shared.getPlayer(byName: name) else {
            session.send("Player not found. Use 'register' to create a new account.")
            return
        }

        // 驗證密碼
        let hashedPassword = hashPassword(password)
        guard player.passwordHash == hashedPassword else {
            session.send("Invalid password.")
            return
        }

        // 登入成功
        SessionManager.shared.loginPlayer(player, session: session)
        World.shared.addPlayer(player)

        session.send("Welcome back, \(player.name)!")
        session.send("You are level \(player.level) with \(player.currentHP)/\(player.maxHP) HP.")
        showRoom(session: session)
    }

    private func handleRegister(args: [String], session: Session) {
        guard args.count >= 2 else {
            session.send("Usage: register <name> <password>")
            return
        }

        let name = args[0]
        let password = args[1]

        // 驗證名稱：2-16 字元，只能字母和數字
        guard name.count >= 2 && name.count <= 16 else {
            session.send("Name must be 2-16 characters long.")
            return
        }

        let allowedCharacters = CharacterSet.alphanumerics
        guard name.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            session.send("Name can only contain letters and numbers.")
            return
        }

        // 驗證密碼：至少 4 字元
        guard password.count >= 4 else {
            session.send("Password must be at least 4 characters long.")
            return
        }

        // 檢查名稱是否已存在
        if World.shared.getPlayer(byName: name) != nil {
            session.send("This name is already taken.")
            return
        }

        // 建立新玩家
        let hashedPassword = hashPassword(password)
        let player = Player.create(name: name, passwordHash: hashedPassword)

        // 登入玩家
        SessionManager.shared.loginPlayer(player, session: session)
        World.shared.addPlayer(player)

        session.send("Welcome to SwiftMUD, \(player.name)!")
        session.send("You start at level 1. Type 'help' for a list of commands.")
        showRoom(session: session)
    }

    private func handleGameCommand(command: String, args: [String], session: Session, context: ChannelHandlerContext) {
        guard let playerId = session.playerId,
              let player = World.shared.getPlayer(byId: playerId) else {
            session.send("Error: Player not found.")
            return
        }

        switch command {
        // 移動指令
        case "n", "north":
            move(player: player, session: session, direction: .north)
        case "s", "south":
            move(player: player, session: session, direction: .south)
        case "e", "east":
            move(player: player, session: session, direction: .east)
        case "w", "west":
            move(player: player, session: session, direction: .west)
        case "u", "up":
            move(player: player, session: session, direction: .up)
        case "d", "down":
            move(player: player, session: session, direction: .down)

        // 觀察指令
        case "l", "look":
            showRoom(session: session)

        // 狀態指令
        case "status", "stat":
            showStatus(player: player, session: session)

        // 在線玩家
        case "who":
            showOnlinePlayers(session: session)

        // 房間聊天
        case "say":
            let message = args.joined(separator: " ")
            if message.isEmpty {
                session.send("Usage: say <message>")
            } else {
                say(player: player, session: session, message: message)
            }

        // 全服喊話
        case "yell":
            let message = args.joined(separator: " ")
            if message.isEmpty {
                session.send("Usage: yell <message>")
            } else {
                yell(player: player, session: session, message: message)
            }

        // 離開遊戲
        case "quit", "exit":
            session.send("Goodbye, \(player.name)! See you next time!")
            session.close()

        // 幫助
        case "help":
            showHelp(session: session)

        default:
            session.send("Unknown command: \(command). Type 'help' for a list of commands.")
        }
    }

    // MARK: - Helper Methods

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func move(player: Player, session: Session, direction: Direction) {
        guard let room = World.shared.getRoom(player.currentRoomId) else {
            session.send("Error: Current room not found.")
            return
        }

        guard let newRoomId = room.exits[direction] else {
            session.send("You cannot go \(direction.displayName).")
            return
        }

        guard World.shared.getRoom(newRoomId) != nil else {
            session.send("Error: Destination room not found.")
            return
        }

        // 通知當前房間的玩家
        SessionManager.shared.broadcast(
            "\(player.name) heads \(direction.displayName).",
            inRoom: player.currentRoomId,
            except: player.id
        )

        // 移動玩家
        World.shared.movePlayer(player.id, from: player.currentRoomId, to: newRoomId)

        // 通知新房間的玩家
        SessionManager.shared.broadcast(
            "\(player.name) arrives from \(direction.opposite.displayName).",
            inRoom: newRoomId,
            except: player.id
        )

        // 顯示新房間
        showRoom(session: session)
    }

    private func showRoom(session: Session) {
        guard let playerId = session.playerId,
              let player = World.shared.getPlayer(byId: playerId),
              let room = World.shared.getRoom(player.currentRoomId) else {
            session.send("Error: Cannot display room.")
            return
        }

        // 取得房間內的其他玩家
        let playersInRoom = World.shared.getPlayersInRoom(room.id)
            .filter { $0.id != playerId }
            .map { $0.name }

        // 取得房間內的怪物
        let monstersInRoom = World.shared.getMonstersInRoom(room.id)
            .map { $0.name }

        let description = room.fullDescription(playerNames: playersInRoom, monsterNames: monstersInRoom)
        session.send(description)
    }

    private func showStatus(player: Player, session: Session) {
        let status = """
        ========== Status ==========
        Name: \(player.name)
        Level: \(player.level)
        HP: \(player.currentHP)/\(player.maxHP)
        MP: \(player.currentMP)/\(player.maxMP)
        Attack: \(player.baseAttack)
        Defense: \(player.baseDefense)
        Magic: \(player.baseMagic)
        EXP: \(player.exp)/\(player.expToNextLevel())
        Gold: \(player.gold)
        ============================
        """
        session.send(status)
    }

    private func showOnlinePlayers(session: Session) {
        let count = SessionManager.shared.onlinePlayerCount
        session.send("Online players: \(count)")
    }

    private func say(player: Player, session: Session, message: String) {
        // 發送給自己
        session.send("You say: \(message)")

        // 發送給房間內其他玩家
        SessionManager.shared.broadcast(
            "\(player.name) says: \(message)",
            inRoom: player.currentRoomId,
            except: player.id
        )
    }

    private func yell(player: Player, session: Session, message: String) {
        // 發送給自己
        session.send("You yell: \(message)")

        // 發送給所有其他玩家
        SessionManager.shared.broadcastGlobal(
            "\(player.name) yells: \(message)",
            except: player.id
        )
    }

    private func showHelp(session: Session) {
        let help = """
        ========== Commands ==========
        Movement: n/s/e/w/u/d or north/south/east/west/up/down
        look, l      - Look around the room
        status, stat - Show your status
        who          - Show online player count
        say <msg>    - Talk to players in the room
        yell <msg>   - Shout to all players
        quit         - Leave the game
        help         - Show this help message
        ===============================
        """
        session.send(help)
    }
}
