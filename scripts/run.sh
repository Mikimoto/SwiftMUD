#!/bin/bash
#
# SwiftMUD Run Script
# Runs the MUD server with configurable options
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
PORT=4000
BUILD_MODE="debug"
DATA_DIR="$PROJECT_DIR/data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT      Server port (default: 4000)"
    echo "  -m, --mode MODE      Run mode: debug or release (default: debug)"
    echo "  -d, --data-dir DIR   Data directory (default: ./data)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run on default port 4000"
    echo "  $0 -p 5000            # Run on port 5000"
    echo "  $0 -m release -p 4000 # Run release build on port 4000"
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

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -m|--mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
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

# Determine binary path
if [ "$BUILD_MODE" = "release" ]; then
    BINARY_PATH="$PROJECT_DIR/.build/release/SwiftMUD"
else
    BINARY_PATH="$PROJECT_DIR/.build/debug/SwiftMUD"
fi

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    log_warning "Binary not found at $BINARY_PATH"
    log_info "Building SwiftMUD in $BUILD_MODE mode..."

    BUILD_FLAGS=""
    if [ "$BUILD_MODE" = "release" ]; then
        BUILD_FLAGS="-c release"
    fi

    swift build $BUILD_FLAGS

    if [ ! -f "$BINARY_PATH" ]; then
        log_error "Build failed - binary not found"
        exit 1
    fi
fi

# Ensure data directory exists
if [ ! -d "$DATA_DIR" ]; then
    log_info "Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/players"
    mkdir -p "$DATA_DIR/world"
    mkdir -p "$DATA_DIR/logs"
fi

log_info "SwiftMUD Run Script"
log_info "Binary: $BINARY_PATH"
log_info "Port: $PORT"
log_info "Data directory: $DATA_DIR"
log_info "Starting SwiftMUD server..."

echo ""
echo "=========================================="
echo "  SwiftMUD Server"
echo "  Port: $PORT"
echo "  Mode: $BUILD_MODE"
echo "=========================================="
echo ""

# Run the server
exec "$BINARY_PATH" --port "$PORT"
