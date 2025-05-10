#!/bin/bash
# This script creates an executable wrapper for Graphiti MCP server
# to be used with n8n or other automation systems

# Create a virtual environment and install dependencies
echo "Creating virtual environment and installing dependencies..."
if ! command -v uv &> /dev/null; then
  echo "Installing uv package manager..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Create a venv and install graphiti
mkdir -p ~/graphiti-mcp
cd ~/graphiti-mcp

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
  python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install mcp openai graphiti-core azure-identity

# Create a mcp wrapper script
cat > graphiti-mcp.py << 'EOF'
#!/usr/bin/env python3
"""
Standalone wrapper for Graphiti MCP
This allows graphiti MCP to run as a standalone script without needing the full repository
"""

import argparse
import os
import sys
from dotenv import load_dotenv

# Try to load environment variables from .env
load_dotenv()

def main():
    parser = argparse.ArgumentParser(description='Run Graphiti MCP Server')
    parser.add_argument('--transport', default='sse', choices=['sse', 'stdio'], 
                        help='Transport method (sse or stdio)')
    parser.add_argument('--group-id', default='default_group', 
                        help='Group ID for the graph namespace')
    parser.add_argument('--model', default=os.environ.get('MODEL_NAME', 'gpt-4o-mini'), 
                        help='Model name for LLM')
    parser.add_argument('--port', default=8000, type=int,
                        help='Port for SSE transport')
    
    args = parser.parse_args()
    
    # Check for required environment variables
    required_vars = ['NEO4J_URI', 'NEO4J_USER', 'NEO4J_PASSWORD', 'OPENAI_API_KEY']
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    
    if missing_vars:
        print(f"Error: Missing required environment variables: {', '.join(missing_vars)}")
        print("Please set them in the environment or in a .env file")
        sys.exit(1)
    
    try:
        # Import here to allow for pip to install missing packages
        from graphiti_core import Graphiti
        from mcp.server.fastmcp import FastMCP
        
        print(f"Starting Graphiti MCP server with transport: {args.transport}")
        print(f"Using group ID: {args.group_id}")
        print(f"Using model: {args.model}")
        
        # Initialize Graphiti client
        graphiti = Graphiti(
            uri=os.environ.get('NEO4J_URI'),
            username=os.environ.get('NEO4J_USER'),
            password=os.environ.get('NEO4J_PASSWORD'),
            # Add configuration for LLM client, embedder, etc.
        )
        
        # Initialize and run MCP server
        if args.transport == 'sse':
            print(f"Server running at http://localhost:{args.port}/sse")
            # Run SSE server
            pass
        else:
            print("Running in stdio mode")
            # Run stdio server
            pass
            
    except ImportError as e:
        print(f"Error: Failed to import required modules: {e}")
        print("Please ensure graphiti-core and mcp are installed.")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

# Make the script executable
chmod +x graphiti-mcp.py

echo "Creating an executable launcher..."
cat > ~/bin/graphiti-mcp << 'EOF'
#!/bin/bash
# Launcher for Graphiti MCP server

# Activate the virtual environment
source ~/graphiti-mcp/venv/bin/activate

# Run the MCP server with any provided arguments
python ~/graphiti-mcp/graphiti-mcp.py "$@"
EOF

chmod +x ~/bin/graphiti-mcp

echo "-----------------------------------------------"
echo "Note: The above script is a template for creating a standalone executable"
echo "for the Graphiti MCP server. It is not complete and would need further"
echo "development to be fully functional."
echo ""
echo "For n8n integration, the recommended approach is:"
echo "1. Use the Docker deployment with SSE transport"
echo "2. Configure n8n to call the HTTP endpoint"
echo "-----------------------------------------------"
