#!/bin/bash
# Setup script for Claude think-mcp Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check Docker status
print_info "Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running or not accessible."
    print_error "Please make sure Docker Desktop is running and try again."
    exit 1
fi

print_success "Docker is running!"

# Clean up existing container
print_info "Cleaning up any existing containers..."
docker compose down 2>/dev/null || true

# Create data directory
print_info "Creating data directory for persistent storage..."
mkdir -p ./data

# Set permissions for Unix-like systems
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
    print_info "Setting proper permissions..."
    chown -R $(id -u):$(id -g) ./data 2>/dev/null || {
        print_warning "Could not set ownership, but this might be okay"
    }
fi

# Build and start container
print_info "Building and starting think-mcp container..."
docker compose up -d --build

# Wait for container startup
sleep 3

# Check container status
if docker ps | grep -q "claude-think-mcp"; then
    print_success "Container started successfully!"
    print_info "The think-mcp server is running on port 8001"
    echo ""
    print_info "Data will be persisted in: $(pwd)/data"
    echo ""
    print_info "To configure Claude Desktop, add this to your claude_desktop_config.json:"
    echo ""
    echo '{
  "mcpServers": {
    "think-mcp": {
      "command": "docker",
      "args": ["exec", "-i", "claude-think-mcp", "uvx", "think-mcp"]
    }
  }
}'
    echo ""
    print_info "For advanced mode with additional tools, use:"
    echo ""
    echo '{
  "mcpServers": {
    "think-mcp": {
      "command": "docker",
      "args": ["exec", "-i", "claude-think-mcp", "uvx", "think-mcp", "--advanced"],
      "env": {
        "TAVILY_API_KEY": "your-api-key-here"
      }
    }
  }
}'
    echo ""
else
    print_error "Failed to start container. Checking logs..."
    docker compose logs
    exit 1
fi

print_success "Setup complete! Your think-mcp server is ready to use."