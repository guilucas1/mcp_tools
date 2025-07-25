#!/bin/bash
set -e

echo "Starting Minima services..."

# Start the indexer service in the background
cd /app/minima/indexer
echo "Starting indexer service on port 8001..."

# Check if there's an app.py file (newer versions may use this)
if [ -f "app.py" ]; then
  python3 app.py &
elif [ -f "__main__.py" ]; then
  python3 -m indexer &
else
  # Check for main.py file
  if [ -f "main.py" ]; then
    python3 main.py &
  else
    echo "WARNING: Could not find appropriate indexer entry point."
    # Try to run the server directly with uvicorn as a fallback
    python3 -c "
import os
from pathlib import Path
# Find any file with a FastAPI app
for file in Path('.').glob('*.py'):
    with open(file, 'r') as f:
        if 'FastAPI(' in f.read():
            print(f'Found FastAPI app in {file}')
            os.system(f'uvicorn {file.stem}:app --host 0.0.0.0 --port 8001 &')
            break
" &
  fi
fi

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
  
  # List files in the indexer directory for debugging
  echo "Files in the indexer directory:"
  ls -la
  
  # Try to start the indexer service using uvicorn directly
  echo "Trying alternative startup method..."
  cd /app/minima/indexer
  find . -type f -name "*.py" | xargs grep -l "FastAPI" | head -1 | xargs -I{} basename {} .py | xargs -I{} uvicorn {}:app --host 0.0.0.0 --port 8001 &
fi

# Start the MCP server
cd /app/minima/mcp-server
echo "Starting MCP server..."
exec uv --directory . run minima