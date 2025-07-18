#!/bin/bash

# Script to check and fix the Claude Thread Continuity MCP Server

echo "Checking Claude Thread Continuity MCP Server status..."

# First, build and run with the fixed Dockerfile
echo "Building with fixed Dockerfile..."
docker-compose stop thread-continuity
docker-compose build thread-continuity
docker-compose up -d thread-continuity

# Wait for container to stabilize
echo "Waiting for container to start up..."
sleep 5

# Check if container is running or restarting
CONTAINER_STATUS=$(docker ps --filter "name=claude-thread-continuity" --format "{{.Status}}")
echo "Container status: $CONTAINER_STATUS"

if [[ $CONTAINER_STATUS == *"Restarting"* ]]; then
    echo "Container is restarting. Checking logs for errors..."
    docker logs claude-thread-continuity
    
    echo "Attempting to execute an interactive shell to debug..."
    docker exec -it claude-thread-continuity bash -c "ls -la /app || true"
    
    echo "Checking Python environment..."
    docker exec -it claude-thread-continuity bash -c "python --version || true"
    docker exec -it claude-thread-continuity bash -c "pip list || true"
    
    echo "Trying to run the server manually to see errors..."
    docker exec -it claude-thread-continuity bash -c "cd /app && python -c 'import server; print(\"Server module can be imported\")' || true"
    
    echo "Checking server.py content..."
    docker exec -it claude-thread-continuity bash -c "cat /app/server.py | head -20 || true"
    
    echo "Copying server.py from the container for inspection..."
    docker cp claude-thread-continuity:/app/server.py ./server.py.from.container || true
    
    echo "Creating a debug container for troubleshooting..."
    docker run --rm -it --name debug-claude-thread-continuity -v $(pwd)/data/thread-continuity:/app/data claude-mcp-servers-thread-continuity bash || true
else
    echo "Container appears to be running. Testing the API endpoint..."
    curl -v http://localhost:8002/v1/health || echo "API endpoint is not responding"
fi

echo "Done! You may need to examine the server.py file and fix any issues."