#!/bin/bash
# Validation script for think-mcp Docker setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "🔍 Think MCP Docker Validation"
echo "=============================="

# Check Docker status
print_info "Checking Docker status..."
if docker info > /dev/null 2>&1; then
    print_success "Docker is running"
else
    print_error "Docker is not running"
    exit 1
fi

# Check data directory
print_info "Checking data directory..."
if [ -d "./data" ]; then
    print_success "Data directory exists: ./data"
else
    print_error "Data directory missing: ./data"
fi

# Check container status
print_info "Checking container status..."
if docker ps | grep -q "claude-think-mcp"; then
    print_success "Container 'claude-think-mcp' is running"
    
    # Check container health
    print_info "Checking container health..."
    container_status=$(docker inspect claude-think-mcp --format='{{.State.Status}}')
    if [ "$container_status" = "running" ]; then
        print_success "Container status: $container_status"
    else
        print_warning "Container status: $container_status"
    fi
    
    # Check volume mount
    print_info "Checking volume mount..."
    data_mount=$(docker inspect claude-think-mcp --format='{{range .Mounts}}{{if eq .Destination "/app/data"}}{{.Source}}{{end}}{{end}}')
    
    if [[ "$data_mount" == *"data" ]]; then
        print_success "Data volume properly mounted: $data_mount -> /app/data"
    else
        print_error "Data volume mount issue: $data_mount"
    fi
    
    # Test think-mcp availability
    print_info "Testing think-mcp availability in container..."
    if docker exec claude-think-mcp uvx --help >/dev/null 2>&1; then
        print_success "uvx is available in container"
        
        # Test think-mcp installation
        if docker exec claude-think-mcp uvx list | grep -q "think-mcp" 2>/dev/null; then
            print_success "think-mcp is installed and available"
        else
            print_warning "think-mcp may not be installed (this could be normal on first run)"
        fi
    else
        print_error "uvx not found in container"
    fi
    
    # Test data persistence
    print_info "Testing data persistence..."
    test_file="./data/test_persistence_$(date +%s).txt"
    echo "test data" > "$test_file"
    
    if docker exec claude-think-mcp ls "/app/data/$(basename "$test_file")" >/dev/null 2>&1; then
        print_success "Data persistence working - file visible in container"
        rm "$test_file"
    else
        print_error "Data persistence issue - file not visible in container"
    fi
    
else
    print_error "Container 'claude-think-mcp' is not running"
    print_info "Starting container..."
    docker compose up -d --build
    sleep 5
    if docker ps | grep -q "claude-think-mcp"; then
        print_success "Container started successfully"
    else
        print_error "Failed to start container"
        print_info "Container logs:"
        docker compose logs --tail=20
    fi
fi

# Validate docker-compose.yml
print_info "Validating docker-compose.yml..."
if docker compose config >/dev/null 2>&1; then
    print_success "docker-compose.yml syntax is valid"
else
    print_error "docker-compose.yml has syntax errors"
    docker compose config
fi

echo ""
echo "🎯 Validation Summary"
echo "===================="

if docker ps | grep -q "claude-think-mcp" && [ -d "./data" ]; then
    print_success "Think MCP setup is working correctly!"
    echo ""
    print_info "Next steps:"
    echo "  1. Add the MCP server configuration to Claude Desktop"
    echo "  2. Restart Claude Desktop"
    echo "  3. Test the think functionality with Claude"
    echo ""
    print_info "Basic Claude Desktop config:"
    echo '  {'
    echo '    "mcpServers": {'
    echo '      "think-mcp": {'
    echo '        "command": "docker",'
    echo '        "args": ["exec", "-i", "claude-think-mcp", "uvx", "think-mcp"]'
    echo '      }'
    echo '    }'
    echo '  }'
else
    print_error "Some issues were found. Please check the output above."
    echo ""
    print_info "Common fixes:"
    echo "  - Run: ./setup.sh"
    echo "  - Check: docker compose logs"
    echo "  - Restart: docker compose restart"
fi