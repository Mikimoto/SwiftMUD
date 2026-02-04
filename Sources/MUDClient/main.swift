import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// 簡單的 MUD Client - 用於測試 SwiftMUD 伺服器
class MUDClient {
    private var socket: Int32 = -1
    private var isConnected = false
    private let host: String
    private let port: UInt16

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func connect() throws {
        // 建立 socket
        socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw ClientError.socketCreationFailed
        }

        // 解析主機位址
        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = port.bigEndian

        if host == "localhost" || host == "127.0.0.1" {
            serverAddr.sin_addr.s_addr = inet_addr("127.0.0.1")
        } else {
            serverAddr.sin_addr.s_addr = inet_addr(host)
        }

        // 連線
        let connectResult = withUnsafePointer(to: &serverAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectResult == 0 else {
            close(socket)
            throw ClientError.connectionFailed(errno: errno)
        }

        isConnected = true
        print("已連線到 \(host):\(port)")
        print("輸入指令後按 Enter 發送，輸入 /quit 離開 client")
        print("---")
    }

    func run() {
        guard isConnected else { return }

        // 設定 socket 為非阻塞
        let flags = fcntl(socket, F_GETFL, 0)
        _ = fcntl(socket, F_SETFL, flags | O_NONBLOCK)

        // 設定 stdin 為非阻塞
        let stdinFlags = fcntl(STDIN_FILENO, F_GETFL, 0)
        _ = fcntl(STDIN_FILENO, F_SETFL, stdinFlags | O_NONBLOCK)

        var buffer = [UInt8](repeating: 0, count: 4096)
        var inputBuffer = ""

        while isConnected {
            // 讀取伺服器訊息
            let bytesRead = recv(socket, &buffer, buffer.count - 1, 0)
            if bytesRead > 0 {
                buffer[bytesRead] = 0
                if let message = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                    print(message, terminator: "")
                    fflush(stdout)
                }
            } else if bytesRead == 0 {
                print("\n伺服器已關閉連線")
                break
            }

            // 讀取使用者輸入
            var inputChar: UInt8 = 0
            let inputRead = read(STDIN_FILENO, &inputChar, 1)
            if inputRead > 0 {
                if inputChar == 10 { // Enter
                    if inputBuffer == "/quit" {
                        print("離開 client...")
                        break
                    }

                    // 發送指令
                    let command = inputBuffer + "\r\n"
                    _ = send(socket, command, command.utf8.count, 0)
                    inputBuffer = ""
                } else {
                    inputBuffer.append(Character(UnicodeScalar(inputChar)))
                }
            }

            // 小延遲避免 CPU 過載
            usleep(10000) // 10ms
        }

        disconnect()
    }

    func disconnect() {
        if isConnected {
            close(socket)
            isConnected = false
            print("已斷開連線")
        }
    }
}

enum ClientError: Error, CustomStringConvertible {
    case socketCreationFailed
    case connectionFailed(errno: Int32)

    var description: String {
        switch self {
        case .socketCreationFailed:
            return "無法建立 socket"
        case .connectionFailed(let errno):
            return "連線失敗: \(String(cString: strerror(errno)))"
        }
    }
}

// 主程式
func main() {
    let args = CommandLine.arguments

    var host = "localhost"
    var port: UInt16 = 4000

    // 解析參數
    var i = 1
    while i < args.count {
        switch args[i] {
        case "-h", "--host":
            if i + 1 < args.count {
                host = args[i + 1]
                i += 1
            }
        case "-p", "--port":
            if i + 1 < args.count, let p = UInt16(args[i + 1]) {
                port = p
                i += 1
            }
        case "--help":
            print("""
            MUD Client - SwiftMUD 測試客戶端

            用法: MUDClient [選項]

            選項:
              -h, --host <host>   伺服器位址 (預設: localhost)
              -p, --port <port>   伺服器埠號 (預設: 4000)
              --help              顯示說明

            客戶端指令:
              /quit               離開客戶端
            """)
            return
        default:
            break
        }
        i += 1
    }

    let client = MUDClient(host: host, port: port)

    do {
        try client.connect()
        client.run()
    } catch {
        print("錯誤: \(error)")
    }
}

main()
