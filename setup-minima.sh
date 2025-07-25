#!/bin/bash
# Setup script for Claude minima Docker container

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
print_info "Cleaning up any existing minima container..."
docker rm -f claude-minima 2>/dev/null || true

# Create data directories
print_info "Creating data and documents directories for persistent storage..."
mkdir -p ./data
mkdir -p ./documents

# Create entrypoint script
print_info "Creating docker-entrypoint.sh script..."
cat > docker-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting Minima services..."

# Start the indexer service in the background
cd /app/minima/indexer
echo "Starting indexer service on port 8001..."
python3 -m main &
INDEXER_PID=$!

# Wait for the indexer service to become available
echo "Waiting for indexer service to be available..."
timeout=30
counter=0
while ! nc -z localhost 8001 >/dev/null 2>&1 && [ $counter -lt $timeout ]; do
  echo "Waiting for indexer service on localhost:8001... ($counter/$timeout)"
  sleep 1
  counter=$((counter+1))
done

if [ $counter -ge $timeout ]; then
  echo "Warning: indexer service not available after $timeout seconds."
  echo "Indexer process status:"
  ps -p $INDEXER_PID || true
  echo "Checking port 8001:"
  netstat -tuln | grep 8001 || true
fi

# Start the MCP server
cd /app/minima/mcp-server
echo "Starting MCP server..."
exec uv --directory . run minima
EOF

# Make entrypoint script executable
chmod +x docker-entrypoint.sh

# Set permissions for Unix-like systems
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
    print_info "Setting proper permissions..."
    chown -R $(id -u):$(id -g) ./data ./documents docker-entrypoint.sh 2>/dev/null || {
        print_warning "Could not set ownership, but this might be okay"
    }
fi

# Build and start container
print_info "Building and starting minima container..."
docker compose up -d --build minima

# Wait for container startup
sleep 10

# Check container status
if docker ps | grep -q "claude-minima"; then
    print_success "Container started successfully!"
    print_info "The minima server is running on port 8003"
    echo ""
    print_info "Data will be persisted in: $(pwd)/data"
    print_info "Documents will be indexed from: $(pwd)/documents"
    echo ""
    print_info "To configure Claude Desktop, add this to your claude_desktop_config.json:"
    echo ""
    echo '{
  "mcpServers": {
    "minima": {
      "command": "docker",
      "args": ["exec", "-i", "claude-minima", "uv", "--directory", "/app/minima/mcp-server", "run", "minima"]
    }
  }
}'
    echo ""
    print_info "You can monitor the container with:"
    echo "docker logs -f claude-minima"
else
    print_error "Failed to start container. Checking logs..."
    docker compose logs minima
    exit 1
fi

print_success "Setup complete! Your minima server is ready to use."