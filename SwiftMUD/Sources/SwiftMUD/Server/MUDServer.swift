import NIO
import NIOCore
import NIOPosix
import Logging

final class MUDServer {
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let logger: Logger

    let host: String
    let port: Int

    init(host: String, port: Int) {
        self.host = host
        self.port = port
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.logger = Logger(label: "com.swiftmud.server")
    }

    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(BackPressureHandler())
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(LineBasedFrameDecoder()))
                    try channel.pipeline.syncOperations.addHandler(StringCodec())
                    // TODO: Add ClientHandler() - will be implemented in Task 10
                }
            }
            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)
            .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        channel = try bootstrap.bind(host: host, port: port).wait()
        logger.info("SwiftMUD server started on \(host):\(port)")
    }

    func stop() {
        do {
            try channel?.close().wait()
            try group.syncShutdownGracefully()
            logger.info("SwiftMUD server stopped")
        } catch {
            logger.error("Error stopping server: \(error)")
        }
    }

    func waitForClose() throws {
        try channel?.closeFuture.wait()
    }
}

// 行分隔解碼器 (Line-based frame decoder)
final class LineBasedFrameDecoder: ByteToMessageDecoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer

    private let newLine = UInt8(ascii: "\n")
    private let carriageReturn = UInt8(ascii: "\r")

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let readableBytes = buffer.readableBytesView

        if let newlineIndex = readableBytes.firstIndex(of: newLine) {
            let lineLength = newlineIndex - buffer.readerIndex

            // Check if there's a carriage return before the newline
            let effectiveLineLength: Int
            if lineLength > 0 && readableBytes[newlineIndex - 1] == carriageReturn {
                effectiveLineLength = lineLength - 1
            } else {
                effectiveLineLength = lineLength
            }

            // Read the line content (without CR or LF)
            let line = buffer.readSlice(length: effectiveLineLength)!

            // Skip over CR (if present) and LF
            buffer.moveReaderIndex(forwardBy: lineLength - effectiveLineLength + 1)

            context.fireChannelRead(Self.wrapInboundOut(line))
            return .continue
        }
        return .needMoreData
    }
}

// 字串編解碼器
final class StringCodec: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = String
    typealias OutboundIn = String
    typealias OutboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        if let string = buffer.readString(length: buffer.readableBytes) {
            context.fireChannelRead(wrapInboundOut(string))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let string = unwrapOutboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: string.utf8.count + 2)
        buffer.writeString(string)
        buffer.writeString("\r\n")
        context.write(wrapOutboundOut(buffer), promise: promise)
    }
}
