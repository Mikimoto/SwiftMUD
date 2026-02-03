import NIO
import NIOCore
import Logging

final class ClientHandler: ChannelInboundHandler {
    typealias InboundIn = String
    typealias OutboundOut = String

    private var session: Session?
    private var logger = Logger(label: "com.swiftmud.client")

    func channelActive(context: ChannelHandlerContext) {
        let session = Session(channel: context.channel)
        self.session = session

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

        // TODO: Clean up player state, save data
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
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        let command = parts[0].lowercased()
        let args = parts.count > 1 ? parts[1] : ""

        switch session.state {
        case .connected, .authenticating:
            handleAuthCommand(command: command, args: args, session: session, context: context)
        case .playing:
            handleGameCommand(command: command, args: args, session: session, context: context)
        case .disconnecting:
            break
        }
    }

    private func handleAuthCommand(command: String, args: String, session: Session, context: ChannelHandlerContext) {
        switch command {
        case "quit", "exit":
            session.send("Goodbye!")
            session.close()

        case "login":
            // TODO: Implement login logic
            session.send("Login feature not yet implemented")

        case "register":
            // TODO: Implement registration logic
            session.send("Registration feature not yet implemented")

        default:
            session.send("Please login or register first. Type help for instructions.")
        }
    }

    private func handleGameCommand(command: String, args: String, session: Session, context: ChannelHandlerContext) {
        // TODO: Implement game commands
        session.send("Game command not yet implemented: \(command)")
    }
}
