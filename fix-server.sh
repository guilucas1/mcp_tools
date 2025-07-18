#!/bin/bash

# Script to examine the repository structure and create a proper Python module if needed

# Set variables
CONTAINER_NAME="claude-thread-continuity"

echo "Examining Claude Thread Continuity MCP Server structure..."

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME is not running. Starting it..."
    docker-compose up -d thread-continuity
    sleep 5
fi

# Examine the repository structure
echo "Repository structure inside container:"
docker exec "$CONTAINER_NAME" find /app/claude-thread-continuity -type f -name "*.py" | sort

# Print the content of server.py
echo -e "\nContents of server.py:"
docker exec "$CONTAINER_NAME" cat /app/claude-thread-continuity/server.py | head -n 20
echo "..."

# Check if there's an __init__.py file
if ! docker exec "$CONTAINER_NAME" test -f /app/claude-thread-continuity/__init__.py; then
    echo -e "\nCreating __init__.py file to make it a proper Python module..."
    docker exec "$CONTAINER_NAME" bash -c "echo '# Claude Thread Continuity MCP Server' > /app/claude-thread-continuity/__init__.py"
    echo "✅ Created __init__.py file"
fi

# Create a symlink to the server.py file in the parent directory
echo "Creating a symlink to server.py in the /app directory..."
docker exec "$CONTAINER_NAME" ln -sf /app/claude-thread-continuity/server.py /app/server.py
echo "✅ Created symlink"

# Fix the CMD to use the symlink
echo "Now you can try running the server with:"
echo "docker exec -it $CONTAINER_NAME python /app/server.py"

# Print module import information
echo -e "\nModules available for import:"
docker exec "$CONTAINER_NAME" python -c "import sys; print(sys.path)"

# Try importing the mcp module
echo -e "\nChecking if MCP module can be imported:"
docker exec "$CONTAINER_NAME" python -c "
try:
    import mcp
    print(f'✅ MCP module found: {mcp.__version__}')
except ImportError as e:
    print(f'❌ MCP module not found: {e}')
"

# Restart the container to apply changes
echo -e "\nRestarting the container to apply changes..."
docker-compose restart thread-continuity
sleep 5

echo -e "\nDone! You can now check if the server is working by running:"
echo "curl http://localhost:8002/v1/health"