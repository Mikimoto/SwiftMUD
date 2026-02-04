#!/bin/bash
#
# SwiftMUD Deploy Script
# Stops old service, builds new version, and starts server
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
PORT=4000
PID_FILE="$PROJECT_DIR/swiftmud.pid"
LOG_FILE="$PROJECT_DIR/logs/swiftmud.log"
DATA_DIR="$PROJECT_DIR/data"
BUILD_MODE="release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start       Start the server (default)"
    echo "  stop        Stop the running server"
    echo "  restart     Restart the server"
    echo "  status      Check server status"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT      Server port (default: 4000)"
    echo "  -m, --mode MODE      Build mode: debug or release (default: release)"
    echo "  -f, --foreground     Run in foreground (don't daemonize)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Build and start server"
    echo "  $0 stop               # Stop the running server"
    echo "  $0 restart            # Restart the server"
    echo "  $0 status             # Check if server is running"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if server is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Get the server PID
get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    fi
}

# Stop the server
stop_server() {
    if is_running; then
        PID=$(get_pid)
        log_info "Stopping SwiftMUD server (PID: $PID)..."

        # Send SIGTERM for graceful shutdown
        kill -TERM "$PID" 2>/dev/null || true

        # Wait for process to stop (up to 10 seconds)
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                log_success "Server stopped"
                rm -f "$PID_FILE"
                return 0
            fi
            sleep 1
        done

        # Force kill if still running
        log_warning "Server didn't stop gracefully, sending SIGKILL..."
        kill -KILL "$PID" 2>/dev/null || true
        rm -f "$PID_FILE"
        log_success "Server killed"
    else
        log_info "Server is not running"
    fi
}

# Start the server
start_server() {
    local foreground=$1

    if is_running; then
        PID=$(get_pid)
        log_error "Server is already running (PID: $PID)"
        exit 1
    fi

    # Determine binary path
    if [ "$BUILD_MODE" = "release" ]; then
        BINARY_PATH="$PROJECT_DIR/.build/release/SwiftMUD"
    else
        BINARY_PATH="$PROJECT_DIR/.build/debug/SwiftMUD"
    fi

    # Build if binary doesn't exist
    if [ ! -f "$BINARY_PATH" ]; then
        log_info "Building SwiftMUD in $BUILD_MODE mode..."
        cd "$PROJECT_DIR"

        BUILD_FLAGS=""
        if [ "$BUILD_MODE" = "release" ]; then
            BUILD_FLAGS="-c release"
        fi

        swift build $BUILD_FLAGS

        if [ ! -f "$BINARY_PATH" ]; then
            log_error "Build failed"
            exit 1
        fi
    fi

    # Ensure directories exist
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/players"
    mkdir -p "$DATA_DIR/world"
    mkdir -p "$DATA_DIR/logs"

    log_info "Starting SwiftMUD server..."
    log_info "Port: $PORT"
    log_info "Mode: $BUILD_MODE"
    log_info "Log file: $LOG_FILE"

    if [ "$foreground" = true ]; then
        # Run in foreground
        log_info "Running in foreground mode (Ctrl+C to stop)"
        "$BINARY_PATH" --port "$PORT"
    else
        # Run as daemon
        cd "$PROJECT_DIR"
        nohup "$BINARY_PATH" --port "$PORT" >> "$LOG_FILE" 2>&1 &
        PID=$!
        echo "$PID" > "$PID_FILE"

        # Wait a moment and check if it started
        sleep 2
        if ps -p "$PID" > /dev/null 2>&1; then
            log_success "Server started (PID: $PID)"
            log_info "PID file: $PID_FILE"
            log_info "Log file: $LOG_FILE"
        else
            log_error "Server failed to start. Check $LOG_FILE for details"
            rm -f "$PID_FILE"
            exit 1
        fi
    fi
}

# Show server status
show_status() {
    if is_running; then
        PID=$(get_pid)
        log_success "Server is running (PID: $PID)"

        # Show process info
        ps -p "$PID" -o pid,ppid,%cpu,%mem,etime,command 2>/dev/null || true
    else
        log_info "Server is not running"
    fi
}

# Default command
COMMAND="start"
FOREGROUND=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        start|stop|restart|status)
            COMMAND="$1"
            shift
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -m|--mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        -f|--foreground)
            FOREGROUND=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate port
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    log_error "Invalid port: $PORT (must be between 1 and 65535)"
    exit 1
fi

# Validate build mode
if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
    log_error "Invalid build mode: $BUILD_MODE (must be 'debug' or 'release')"
    exit 1
fi

cd "$PROJECT_DIR"

# Execute command
case $COMMAND in
    start)
        start_server $FOREGROUND
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 1
        start_server $FOREGROUND
        ;;
    status)
        show_status
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
