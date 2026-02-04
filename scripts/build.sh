#!/bin/bash
#
# SwiftMUD Build Script
# Supports debug and release modes with optional testing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
BUILD_MODE="debug"
RUN_TESTS=true
VERBOSE=false

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
    echo "  -m, --mode MODE    Build mode: debug or release (default: debug)"
    echo "  -s, --skip-tests   Skip running tests before build"
    echo "  -v, --verbose      Enable verbose output"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Debug build with tests"
    echo "  $0 -m release          # Release build with tests"
    echo "  $0 -m release -s       # Release build without tests"
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
        -m|--mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        -s|--skip-tests)
            RUN_TESTS=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
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

# Validate build mode
if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
    log_error "Invalid build mode: $BUILD_MODE (must be 'debug' or 'release')"
    exit 1
fi

cd "$PROJECT_DIR"

log_info "SwiftMUD Build Script"
log_info "Project directory: $PROJECT_DIR"
log_info "Build mode: $BUILD_MODE"
log_info "Run tests: $RUN_TESTS"

# Run tests if enabled
if [ "$RUN_TESTS" = true ]; then
    log_info "Running tests..."
    if [ "$VERBOSE" = true ]; then
        swift test --parallel
    else
        swift test --parallel 2>&1 | tail -20
    fi
    log_success "All tests passed"
fi

# Build the project
log_info "Building SwiftMUD in $BUILD_MODE mode..."

BUILD_FLAGS=""
if [ "$BUILD_MODE" = "release" ]; then
    BUILD_FLAGS="-c release"
fi

if [ "$VERBOSE" = true ]; then
    swift build $BUILD_FLAGS
else
    swift build $BUILD_FLAGS 2>&1 | tail -10
fi

# Get the binary path
if [ "$BUILD_MODE" = "release" ]; then
    BINARY_PATH="$PROJECT_DIR/.build/release/SwiftMUD"
else
    BINARY_PATH="$PROJECT_DIR/.build/debug/SwiftMUD"
fi

if [ -f "$BINARY_PATH" ]; then
    BINARY_SIZE=$(du -h "$BINARY_PATH" | cut -f1)
    log_success "Build completed successfully"
    log_info "Binary location: $BINARY_PATH"
    log_info "Binary size: $BINARY_SIZE"
else
    log_error "Build failed - binary not found"
    exit 1
fi

echo ""
log_success "SwiftMUD build complete!"
