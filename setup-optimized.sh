#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
PROJECT_NAME="claude-mcp-servers"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop first."
        exit 1
    fi
}

# Function to check if docker-compose is available
check_compose() {
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Determine compose command
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
}

# Function to show memory usage
show_memory_usage() {
    print_status "Current memory usage:"
    echo
    docker stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | grep -E "(claude|lazytainer)" || echo "No containers running"
    echo
}

# Function to start the optimized setup
start_optimized() {
    print_status "Starting optimized MCP server setup with Lazytainer..."
    
    # Stop existing containers
    print_status "Stopping existing containers..."
    $COMPOSE_CMD down --remove-orphans 2>/dev/null || true
    
    # Build and start services
    print_status "Building and starting optimized services..."
    $COMPOSE_CMD up -d --build
    
    # Wait for services to start
    print_status "Waiting for services to initialize..."
    sleep 10
    
    # Check status
    check_service_status
    
    print_success "Optimized setup is running!"
    print_status "Memory usage should now be ~50-80MB when idle."
    print_status ""
    print_status "Service endpoints:"
    print_status "  - Basic Memory: http://localhost:8888"
    print_status "  - Think MCP:    http://localhost:8001" 
    print_status "  - Calculator:   http://localhost:8002"
    print_status ""
    print_warning "Note: Containers will automatically start when Claude makes requests"
    print_warning "and pause after 3-5 minutes of inactivity to save memory."
}

# Function to stop the setup
stop_optimized() {
    print_status "Stopping optimized MCP server setup..."
    $COMPOSE_CMD down
    print_success "All services stopped."
}

# Function to restart the setup
restart_optimized() {
    print_status "Restarting optimized MCP server setup..."
    stop_optimized
    sleep 2
    start_optimized
}

# Function to check service status
check_service_status() {
    print_status "Service status:"
    echo
    
    # Check container status
    local containers=("claude-lazytainer" "claude-basic-memory" "claude-think-mcp" "claude-calculator")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container"; then
            local status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container" | awk '{print $2" "$3}')
            print_success "$container: $status"
        else
            print_warning "$container: Not running (managed by Lazytainer)"
        fi
    done
    
    echo
    show_memory_usage
}

# Function to view logs
view_logs() {
    local service=$1
    if [ -z "$service" ]; then
        print_status "Available services: lazytainer, basic-memory, think-mcp, calculator"
        print_status "Usage: $0 logs [service-name]"
        return
    fi
    
    case $service in
        "lazytainer")
            $COMPOSE_CMD logs -f lazytainer
            ;;
        "basic-memory")
            $COMPOSE_CMD logs -f basic-memory
            ;;
        "think-mcp")
            $COMPOSE_CMD logs -f think-mcp
            ;;
        "calculator")
            $COMPOSE_CMD logs -f calculator
            ;;
        *)
            print_error "Unknown service: $service"
            print_status "Available services: lazytainer, basic-memory, think-mcp, calculator"
            ;;
    esac
}

# Function to test the setup
test_setup() {
    print_status "Testing optimized setup..."
    
    # Test Lazytainer proxy
    print_status "Testing Lazytainer proxy on port 8888..."
    if curl -s --connect-timeout 5 http://localhost:8888 >/dev/null 2>&1; then
        print_success "Lazytainer proxy is responding"
        print_status "This should have automatically started the basic-memory container"
    else
        print_warning "Lazytainer proxy not responding yet (containers may be starting)"
    fi
    
    # Show status after test
    sleep 5
    check_service_status
}

# Function to monitor memory usage
monitor_memory() {
    print_status "Monitoring memory usage (Press Ctrl+C to stop)..."
    print_status "This will show real-time memory consumption as containers start/stop"
    echo
    
    while true; do
        clear
        echo -e "${BLUE}=== MCP Servers Memory Monitor ===${NC}"
        echo "$(date)"
        echo
        
        # Show total memory usage
        docker stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | head -1
        docker stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | grep -E "(claude|lazytainer)" || echo "No MCP containers running"
        
        echo
        echo -e "${YELLOW}Tip: Make a request to Claude to see containers start automatically${NC}"
        echo -e "${YELLOW}Containers will pause after 3-5 minutes of inactivity${NC}"
        
        sleep 5
    done
}

# Function to show help
show_help() {
    echo "Optimized MCP Server Management Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  start     Start the optimized MCP server setup"
    echo "  stop      Stop all MCP services"  
    echo "  restart   Restart the entire setup"
    echo "  status    Show service status and memory usage"
    echo "  logs      View logs for a specific service"
    echo "  test      Test the setup connectivity"
    echo "  monitor   Monitor real-time memory usage"
    echo "  help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs lazytainer"
    echo "  $0 monitor"
}

# Function to backup current configuration
backup_config() {
    if [ -f "$COMPOSE_FILE" ]; then
        local backup_file="${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$COMPOSE_FILE" "$backup_file"
        print_success "Backed up current configuration to: $backup_file"
    fi
}

# Main script logic
main() {
    check_docker
    check_compose
    
    case "${1:-help}" in
        "start")
            backup_config
            start_optimized
            ;;
        "stop")
            stop_optimized
            ;;
        "restart")
            restart_optimized
            ;;
        "status")
            check_service_status
            ;;
        "logs")
            view_logs "$2"
            ;;
        "test")
            test_setup
            ;;
        "monitor")
            monitor_memory
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"