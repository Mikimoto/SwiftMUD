import ArgumentParser
import Logging

@main
struct SwiftMUD: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftmud",
        abstract: "A Swift MUD game server"
    )

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 4000

    @Option(name: .shortAndLong, help: "Host to bind to")
    var host: String = "0.0.0.0"

    func run() throws {
        var logger = Logger(label: "com.swiftmud.main")
        logger.logLevel = .info

        let server = MUDServer(host: host, port: port)

        defer {
            server.stop()
        }

        do {
            try server.start()
            try server.waitForClose()
        } catch {
            logger.error("Server error: \(error)")
            throw error
        }
    }
}
