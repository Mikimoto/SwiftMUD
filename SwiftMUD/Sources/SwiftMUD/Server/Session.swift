import Foundation
import NIO

enum SessionState {
    case connected
    case authenticating
    case playing
    case disconnecting
}

final class Session {
    let id: UUID
    let channel: Channel
    var state: SessionState
    var playerId: UUID?
    var playerName: String?
    let connectedAt: Date

    init(channel: Channel) {
        self.id = UUID()
        self.channel = channel
        self.state = .connected
        self.connectedAt = Date()
    }

    func send(_ message: String) {
        _ = channel.writeAndFlush(message)
    }

    func sendLines(_ lines: [String]) {
        for line in lines {
            send(line)
        }
    }

    func close() {
        state = .disconnecting
        _ = channel.close()
    }
}
