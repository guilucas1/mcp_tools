# test_thread_continuity.sh

```bash
#!/bin/bash

# Test script for Claude Thread Continuity MCP Server

# Set variables
CONTAINER_NAME="claude-thread-continuity"
PORT=8002

echo "Testing Claude Thread Continuity MCP Server..."

# Check if container is running
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✅ Container $CONTAINER_NAME is running"
else
    echo "❌ Container $CONTAINER_NAME is not running"
    echo "Try running: docker-compose up -d"
    exit 1
fi

# Check if port is open
if nc -z localhost $PORT; then
    echo "✅ Port $PORT is open and accepting connections"
else
    echo "❌ Port $PORT is not accessible"
    echo "Check container logs: docker logs $CONTAINER_NAME"
    exit 1
fi

# Verify the MCP server is responding
echo "Testing MCP server response..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/v1/health 2>/dev/null || echo "failed")

if [ "$RESPONSE" = "200" ]; then
    echo "✅ MCP server is responding correctly"
elif [ "$RESPONSE" = "failed" ]; then
    echo "❌ Unable to connect to MCP server"
    echo "Check container logs: docker logs $CONTAINER_NAME"
    exit 1
else
    echo "⚠️ MCP server returned unexpected status code: $RESPONSE"
    echo "Check container logs: docker logs $CONTAINER_NAME"
    exit 1
fi

echo ""
echo "All tests passed! The Claude Thread Continuity MCP Server is working correctly."
echo ""
echo "To use in Claude Desktop, add this to your configuration:"
echo ""
echo "{" 
echo "  \"mcpServers\": {"
echo "    \"claude-continuity\": {"
echo "      \"command\": \"nc\","
echo "      \"args\": [\"localhost\", \"8002\"],"
echo "      \"env\": {}"
echo "    }"
echo "  }"
echo "}"
echo ""
echo "For more information, see the Implementation Guide."
```