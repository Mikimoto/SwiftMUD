# SwiftMUD Makefile
# Provides convenient shortcuts for common development tasks

.PHONY: all build build-release test run run-release clean help deploy stop status

# Default target
all: build

# Build in debug mode
build:
	@echo "Building SwiftMUD (debug)..."
	swift build

# Build in release mode
build-release:
	@echo "Building SwiftMUD (release)..."
	swift build -c release

# Run all tests
test:
	@echo "Running tests..."
	swift test --parallel

# Run the server in debug mode (default port 4000)
run: build
	@echo "Starting SwiftMUD server..."
	./.build/debug/SwiftMUD --port 4000

# Run the server in release mode
run-release: build-release
	@echo "Starting SwiftMUD server (release)..."
	./.build/release/SwiftMUD --port 4000

# Deploy the server (daemon mode)
deploy:
	@echo "Deploying SwiftMUD..."
	./scripts/deploy.sh start

# Stop the server
stop:
	@echo "Stopping SwiftMUD..."
	./scripts/deploy.sh stop

# Restart the server
restart:
	@echo "Restarting SwiftMUD..."
	./scripts/deploy.sh restart

# Check server status
status:
	@./scripts/deploy.sh status

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build
	rm -f swiftmud.pid
	@echo "Clean complete"

# Generate Xcode project
xcode:
	@echo "Generating Xcode project..."
	swift package generate-xcodeproj

# Update dependencies
update:
	@echo "Updating dependencies..."
	swift package update

# Show package dependencies
deps:
	@echo "Package dependencies:"
	swift package show-dependencies

# Format code (requires swift-format)
format:
	@echo "Formatting code..."
	swift-format -i -r Sources/ Tests/

# Lint code (requires swift-format)
lint:
	@echo "Linting code..."
	swift-format lint -r Sources/ Tests/

# Help
help:
	@echo "SwiftMUD Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build targets:"
	@echo "  build         Build in debug mode"
	@echo "  build-release Build in release mode"
	@echo "  clean         Clean build artifacts"
	@echo ""
	@echo "Test targets:"
	@echo "  test          Run all tests"
	@echo ""
	@echo "Run targets:"
	@echo "  run           Run server in debug mode (port 4000)"
	@echo "  run-release   Run server in release mode (port 4000)"
	@echo ""
	@echo "Deploy targets:"
	@echo "  deploy        Deploy server as daemon"
	@echo "  stop          Stop running server"
	@echo "  restart       Restart server"
	@echo "  status        Check server status"
	@echo ""
	@echo "Utility targets:"
	@echo "  xcode         Generate Xcode project"
	@echo "  update        Update package dependencies"
	@echo "  deps          Show package dependencies"
	@echo "  format        Format code with swift-format"
	@echo "  lint          Lint code with swift-format"
	@echo "  help          Show this help message"
