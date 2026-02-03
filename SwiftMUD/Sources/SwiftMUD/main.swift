import ArgumentParser
import Dispatch
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
        var logger = Logger(label: "com.swiftmud.server")
        logger.logLevel = .info
        logger.info("SwiftMUD server starting on \(host):\(port)")

        // TODO: Start server
        print("SwiftMUD server placeholder - press Ctrl+C to exit")
        dispatchMain()
    }
}
