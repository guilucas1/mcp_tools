#!/bin/bash

# Script to fix the Claude Thread Continuity MCP Server

# Set variables
CONTAINER_NAME="claude-thread-continuity"

echo "Fixing Claude Thread Continuity MCP Server..."

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME is not running. Starting it..."
    docker-compose up -d thread-continuity
    sleep 5
fi

# Create a properly formatted Python module
echo "Creating a properly formatted Python module structure..."
docker exec "$CONTAINER_NAME" bash -c "
    # Make directory if it doesn't exist
    mkdir -p /app/claude_thread_continuity

    # Create __init__.py file
    echo '# Claude Thread Continuity MCP Server' > /app/claude_thread_continuity/__init__.py

    # Copy the server.py file to the new module directory
    cp /app/claude-thread-continuity/server.py /app/claude_thread_continuity/server.py

    # Fix imports in server.py if needed
    sed -i 's/from \./from claude_thread_continuity./g' /app/claude_thread_continuity/server.py
"
echo "✅ Created properly formatted module structure"

# Update PYTHONPATH
echo "Updating PYTHONPATH to include the new module..."
docker exec "$CONTAINER_NAME" bash -c "
    echo 'export PYTHONPATH=/app:$PYTHONPATH' >> ~/.bashrc
"
echo "✅ Updated PYTHONPATH"

# Verify that the server can be imported
echo "Verifying server module can be imported..."
docker exec "$CONTAINER_NAME" python -c "
try:
    import claude_thread_continuity.server
    print('✅ Server module imported successfully')
except ImportError as e:
    print(f'❌ Import failed: {e}')
"

# Try starting the server manually to debug
echo "Attempting to start the server manually..."
docker exec -d "$CONTAINER_NAME" bash -c "
    cd /app && uvicorn claude_thread_continuity.server:app --host 0.0.0.0 --port 8000 > /app/data/server.log 2>&1
"
echo "✅ Server start attempted"

# Wait a moment for the server to start
sleep 5

# Check if the server is running
echo "Checking if the server is running..."
if docker exec "$CONTAINER_NAME" curl -s http://localhost:8000/v1/health > /dev/null; then
    echo "✅ Server is running!"
else
    echo "❌ Server is not responding. Checking logs..."
    docker exec "$CONTAINER_NAME" cat /app/data/server.log
fi

echo -e "\nDone! You can now check if the server is working by running:"
echo "curl http://localhost:8002/v1/health"