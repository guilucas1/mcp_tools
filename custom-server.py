#!/usr/bin/env python3
"""
Claude Thread Continuity MCP Server
Maintains project state across multiple Claude sessions.
"""

import os
import json
import time
from datetime import datetime
from typing import Dict, List, Optional, Any, Union
import mcp
from pydantic import BaseModel, Field
import uvicorn
from fastapi import FastAPI
from fuzzywuzzy import fuzz

print("Starting server initialization...")

# Configuration
DATA_DIR = os.environ.get("DATA_DIR", os.path.join(os.path.expanduser("~"), ".claude_states"))
SIMILARITY_THRESHOLD = 0.7  # Projects with 70% name similarity trigger warnings

print(f"Data directory: {DATA_DIR}")

# Create data directory if it doesn't exist
os.makedirs(DATA_DIR, exist_ok=True)
print(f"Data directory created/confirmed: {DATA_DIR}")

class ProjectState(BaseModel):
    """Model representing the state of a project."""
    project_name: str
    current_focus: Optional[str] = None
    technical_decisions: List[str] = Field(default_factory=list)
    files_modified: List[str] = Field(default_factory=list)
    next_actions: List[str] = Field(default_factory=list)
    conversation_summary: Optional[str] = None
    last_updated: str = Field(default_factory=lambda: datetime.now().isoformat())

# FastAPI app for health checks
app = FastAPI()

@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "Claude Thread Continuity MCP Server"}

@app.get("/v1/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

print("FastAPI app initialized with health check endpoint")

# MCP Server
class ThreadContinuityServer(mcp.Server):
    """MCP Server for maintaining project state across Claude sessions."""

    def __init__(self):
        print("Initializing ThreadContinuityServer...")
        super().__init__()
        self.active_projects = self._load_active_projects()
        print(f"Initialized Thread Continuity Server. Data directory: {DATA_DIR}")
        print(f"Found {len(self.active_projects)} active projects")

    def _load_active_projects(self) -> List[str]:
        """Load list of active projects from data directory."""
        try:
            return [d for d in os.listdir(DATA_DIR) if os.path.isdir(os.path.join(DATA_DIR, d))]
        except Exception as e:
            print(f"Error loading active projects: {e}")
            return []

    def _get_project_path(self, project_name: str) -> str:
        """Get the filesystem path for a project."""
        project_dir = os.path.join(DATA_DIR, project_name)
        os.makedirs(project_dir, exist_ok=True)
        return os.path.join(project_dir, "current_state.json")

    def _create_backup(self, project_name: str, state: Dict[str, Any]) -> None:
        """Create a backup of the current state."""
        project_dir = os.path.join(DATA_DIR, project_name)
        backup_path = os.path.join(project_dir, f"backup_{int(time.time())}.json")
        
        # Keep only the last 5 backups
        backups = [f for f in os.listdir(project_dir) if f.startswith("backup_")]
        if len(backups) >= 5:
            backups.sort()
            for old_backup in backups[:-4]:  # Remove all but the 4 newest (plus the one we're about to create)
                try:
                    os.remove(os.path.join(project_dir, old_backup))
                except Exception as e:
                    print(f"Error removing old backup {old_backup}: {e}")
        
        try:
            with open(backup_path, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            print(f"Error creating backup: {e}")

    def _find_similar_projects(self, project_name: str) -> List[str]:
        """Find projects with similar names using fuzzy matching."""
        similar_projects = []
        for existing_project in self.active_projects:
            if existing_project == project_name:
                continue  # Skip exact matches
            
            similarity = fuzz.ratio(project_name.lower(), existing_project.lower()) / 100.0
            if similarity >= SIMILARITY_THRESHOLD:
                similar_projects.append(existing_project)
        
        return similar_projects

    @mcp.tool("save_project_state")
    def save_project_state(self, 
                         project_name: str,
                         current_focus: Optional[str] = None,
                         technical_decisions: Optional[List[str]] = None,
                         files_modified: Optional[List[str]] = None,
                         next_actions: Optional[List[str]] = None,
                         conversation_summary: Optional[str] = None) -> Dict[str, Any]:
        """
        Save the current state of a project.
        
        Args:
            project_name: Name of the project
            current_focus: What you're currently working on
            technical_decisions: List of technical decisions made
            files_modified: List of files created or modified
            next_actions: Planned next steps
            conversation_summary: Brief summary of the conversation
            
        Returns:
            Dict with status and validation info
        """
        print(f"Saving project state for {project_name}")
        # Input validation
        if not project_name or len(project_name.strip()) == 0:
            return {"status": "error", "message": "Project name cannot be empty"}
        
        # Check for similar project names
        similar_projects = self._find_similar_projects(project_name)
        
        # Create new state
        state = {
            "project_name": project_name,
            "current_focus": current_focus,
            "technical_decisions": technical_decisions or [],
            "files_modified": files_modified or [],
            "next_actions": next_actions or [],
            "conversation_summary": conversation_summary,
            "last_updated": datetime.now().isoformat()
        }
        
        # Save state to file
        try:
            state_path = self._get_project_path(project_name)
            
            # Create backup of existing state if it exists
            if os.path.exists(state_path):
                with open(state_path, 'r') as f:
                    old_state = json.load(f)
                self._create_backup(project_name, old_state)
            
            with open(state_path, 'w') as f:
                json.dump(state, f, indent=2)
            
            # Update active projects list if needed
            if project_name not in self.active_projects:
                self.active_projects.append(project_name)
            
            result = {
                "status": "success",
                "message": f"Project state saved for {project_name}"
            }
            
            # Add validation warnings if there are similar projects
            if similar_projects:
                result["validation_warning"] = f"Similar projects found: {', '.join(similar_projects)}"
                result["recommendation"] = "Consider consolidating related projects to maintain context continuity"
            
            return result
            
        except Exception as e:
            print(f"Error saving project state: {e}")
            return {"status": "error", "message": f"Failed to save project state: {str(e)}"}

    @mcp.tool("load_project_state")
    def load_project_state(self, project_name: str) -> Dict[str, Any]:
        """
        Load the state of a project.
        
        Args:
            project_name: Name of the project to load
            
        Returns:
            Dict with project state or error message
        """
        print(f"Loading project state for {project_name}")
        state_path = self._get_project_path(project_name)
        
        if not os.path.exists(state_path):
            # Check for similar project names
            similar_projects = self._find_similar_projects(project_name)
            
            if similar_projects:
                return {
                    "status": "error",
                    "message": f"Project '{project_name}' not found",
                    "similar_projects": similar_projects,
                    "suggestion": f"Did you mean one of these? {', '.join(similar_projects)}"
                }
            else:
                return {
                    "status": "error",
                    "message": f"Project '{project_name}' not found. Use save_project_state to create a new project."
                }
        
        try:
            with open(state_path, 'r') as f:
                state = json.load(f)
            
            # Add last accessed timestamp
            state["last_accessed"] = datetime.now().isoformat()
            with open(state_path, 'w') as f:
                json.dump(state, f, indent=2)
            
            return {
                "status": "success",
                "message": f"Project state loaded for {project_name}",
                "project_state": state
            }
            
        except Exception as e:
            print(f"Error loading project state: {e}")
            return {"status": "error", "message": f"Failed to load project state: {str(e)}"}

    @mcp.tool("list_active_projects")
    def list_active_projects(self) -> Dict[str, Any]:
        """
        List all active projects.
        
        Returns:
            Dict with list of projects and their last updated timestamps
        """
        print("Listing active projects")
        projects_info = []
        
        for project_name in self.active_projects:
            state_path = self._get_project_path(project_name)
            if os.path.exists(state_path):
                try:
                    with open(state_path, 'r') as f:
                        state = json.load(f)
                    
                    projects_info.append({
                        "name": project_name,
                        "last_updated": state.get("last_updated", "Unknown"),
                        "focus": state.get("current_focus", "Not specified")
                    })
                except Exception as e:
                    print(f"Error reading project {project_name}: {e}")
                    projects_info.append({
                        "name": project_name,
                        "last_updated": "Error reading state",
                        "focus": "Unknown"
                    })
        
        return {
            "status": "success",
            "projects_count": len(projects_info),
            "projects": projects_info
        }

    @mcp.tool("get_project_summary")
    def get_project_summary(self, project_name: str) -> Dict[str, Any]:
        """
        Get a summary of a project.
        
        Args:
            project_name: Name of the project
            
        Returns:
            Dict with project summary or error message
        """
        print(f"Getting project summary for {project_name}")
        state_path = self._get_project_path(project_name)
        
        if not os.path.exists(state_path):
            return {
                "status": "error",
                "message": f"Project '{project_name}' not found"
            }
        
        try:
            with open(state_path, 'r') as f:
                state = json.load(f)
            
            return {
                "status": "success",
                "project_name": project_name,
                "current_focus": state.get("current_focus", "Not specified"),
                "technical_decisions_count": len(state.get("technical_decisions", [])),
                "files_modified_count": len(state.get("files_modified", [])),
                "next_actions_count": len(state.get("next_actions", [])),
                "last_updated": state.get("last_updated", "Unknown")
            }
            
        except Exception as e:
            print(f"Error getting project summary: {e}")
            return {"status": "error", "message": f"Failed to get project summary: {str(e)}"}

    @mcp.tool("auto_save_checkpoint")
    def auto_save_checkpoint(self, 
                           project_name: str,
                           current_focus: Optional[str] = None,
                           technical_decisions: Optional[List[str]] = None,
                           files_modified: Optional[List[str]] = None,
                           next_actions: Optional[List[str]] = None,
                           conversation_summary: Optional[str] = None) -> Dict[str, Any]:
        """
        Automatically save a checkpoint of the current project state.
        This is typically called by Claude automatically during conversations.
        
        Args:
            project_name: Name of the project
            current_focus: What you're currently working on
            technical_decisions: List of technical decisions made
            files_modified: List of files created or modified
            next_actions: Planned next steps
            conversation_summary: Brief summary of the conversation
            
        Returns:
            Dict with status
        """
        print(f"Auto-saving checkpoint for {project_name}")
        # This is just a wrapper around save_project_state
        result = self.save_project_state(
            project_name=project_name,
            current_focus=current_focus,
            technical_decisions=technical_decisions,
            files_modified=files_modified,
            next_actions=next_actions,
            conversation_summary=conversation_summary
        )
        
        if result["status"] == "success":
            result["message"] = f"Auto-checkpoint saved for {project_name}"
        
        return result


# Start server if running directly
if __name__ == "__main__":
    print("Starting Claude Thread Continuity MCP Server...")
    try:
        # First start the FastAPI app in a separate thread
        import threading
        
        def run_fastapi():
            print("Starting FastAPI server...")
            uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
        
        fastapi_thread = threading.Thread(target=run_fastapi)
        fastapi_thread.daemon = True
        fastapi_thread.start()
        print("FastAPI server started in background thread")
        
        # Now start the MCP server
        server = ThreadContinuityServer()
        print("Starting MCP server...")
        server.start()
    except Exception as e:
        print(f"Error starting servers: {e}")
        import traceback
        traceback.print_exc()
