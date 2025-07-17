# Claude Basic-Memory MCP Container

This repository contains a Docker configuration for running the basic-memory MCP server for Claude Desktop with persistent memory storage.

## What is basic-memory?

Basic-memory is a Model Context Protocol (MCP) server that allows Claude to maintain persistent memory across conversations. It stores information in simple Markdown files, creating a knowledge base that Claude can access and update.

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop/) installed on your system
- [Claude Desktop](https://claude.ai/download) installed on your system

## Setup Instructions

### 1. Start the basic-memory container

From the root directory of this repository, run:

```bash
docker compose up -d
```

This will:
- Pull the latest basic-memory image
- Create a Docker container with persistent volumes
- Start the MCP server in the background with port 8888 exposed
- Configure memory storage in the `./database` directory (relative to where you run the command)

### 2. Configure Claude Desktop

You need to edit Claude Desktop's configuration file to connect to the Docker-hosted MCP server.

#### For Windows:
Edit the file at `%APPDATA%\Claude\claude_desktop_config.json`

#### For macOS:
Edit the file at `~/Library/Application Support/Claude/claude_desktop_config.json`

#### For Linux:
Edit the file at `~/.config/Claude/claude_desktop_config.json`

If the file doesn't exist, create it with the following content:

```json
{
  "mcpServers": {
    "basic-memory": {
      "command": "docker",
      "args": ["exec", "-i", "claude-basic-memory", "basic-memory", "mcp"],
      "autoapprove": [
        "read_note",
        "write_note",
        "edit_note",
        "view_note",
        "delete_note",
        "search_notes",
        "list_notes",
        "build_context",
        "read_content",
        "move_note",
        "recent_activity",
        "list_directory"
      ]
    }
  }
}
```

If the file already exists, add the `basic-memory` configuration to the `mcpServers` object.

### 3. Restart Claude Desktop

After updating the configuration, restart Claude Desktop for the changes to take effect.

## Using basic-memory with Claude

Once configured, you can interact with basic-memory through Claude Desktop. Try commands like:

- "Create a note about Docker containers"
- "What do I know about MCPs?"
- "Search for information about Claude"

Your notes will be stored in the `./database` folder, which is mounted as a volume in the Docker container.

## Stopping the Container

To stop the basic-memory container, run:

```bash
docker compose down
```

To completely remove the container and its volumes, run:

```bash
docker compose down -v
```

Note that removing the volumes will delete all persisted configuration, but your notes in the `./memories` folder will remain.

## Troubleshooting

- **Claude doesn't connect to basic-memory**: Make sure the container is running with `docker ps` and that the Claude configuration file is correctly formatted.
- **Notes aren't being saved**: Check that the `./database` directory exists and has proper write permissions.
- **Container crashes**: Check logs with `docker logs claude-basic-memory` for error details.