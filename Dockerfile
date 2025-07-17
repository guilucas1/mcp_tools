# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm AS base

# Install uv for fast Python package management
COPY --from=ghcr.io/astral-sh/uv:0.5.9 /uv /uvx /bin/

# Create app user for security
RUN useradd --create-home --shell /bin/bash app

# Set up working directory
WORKDIR /app

# Create directory for persistent data
RUN mkdir -p /app/data && chown app:app /app/data

# Switch to non-root user
USER app

# Expose port for potential future web interface
EXPOSE 8000

# Keep container running - don't start think-mcp automatically
# Claude Desktop will invoke it via: docker exec -i container-name uvx think-mcp
CMD ["sleep", "infinity"]