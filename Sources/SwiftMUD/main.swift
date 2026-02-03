import NIO
import ArgumentParser

@main
struct SwiftMUD: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Swift MUD Game Server"
    )

    @Option(name: .shortAndLong, help: "Server port")
    var port: Int = 4000

    @Option(name: .shortAndLong, help: "Server host")
    var host: String = "localhost"

    func run() throws {
        print("SwiftMUD Server starting on \(host):\(port)...")
    }
}
