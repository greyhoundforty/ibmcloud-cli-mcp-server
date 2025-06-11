#!/bin/bash
# Claude Desktop Configuration Setup Script

set -e

echo "🤖 Claude Desktop Integration Setup"
echo "=================================="

# Detect OS and set config path
case "$(uname -s)" in
    Darwin*)
        CONFIG_DIR="$HOME/Library/Application Support/Claude"
        ;;
    Linux*)
        CONFIG_DIR="$HOME/.config/Claude"
        ;;
    CYGWIN*|MINGW32*|MSYS*|MINGW*)
        CONFIG_DIR="$APPDATA/Claude"
        ;;
    *)
        echo "❌ Unsupported operating system"
        exit 1
        ;;
esac

CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Get current directory and script path
CURRENT_DIR=$(pwd)
SCRIPT_PATH="$CURRENT_DIR/ibmcloud_mcp_server.sh"

# Check if the MCP server script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "❌ ibmcloud_mcp_server.sh not found in current directory"
    echo "Please run this script from the directory containing your MCP server"
    exit 1
fi

# Make sure the script is executable
chmod +x "$SCRIPT_PATH"

echo ""
echo "Choose integration method:"
echo "1) Direct executable (recommended)"
echo "2) Docker container"
echo ""
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "Setting up direct executable integration..."
        
        # Create configuration for direct executable
        CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "ibmcloud": {
      "command": "$SCRIPT_PATH",
      "args": [],
      "env": {
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "IBMCLOUD_HOME": "$HOME/.bluemix"
      }
    }
  }
}
EOF
)
        ;;
    2)
        echo ""
        echo "Setting up Docker container integration..."
        
        # Check if Docker is available
        if ! command -v docker &> /dev/null; then
            echo "❌ Docker is not installed"
            exit 1
        fi
        
        # Check if Docker wrapper exists
        DOCKER_WRAPPER="$CURRENT_DIR/docker_wrapper.sh"
        if [[ ! -f "$DOCKER_WRAPPER" ]]; then
            echo "❌ docker_wrapper.sh not found"
            echo "Please create the Docker wrapper script first"
            exit 1
        fi
        
        chmod +x "$DOCKER_WRAPPER"
        
        # Build Docker image
        echo "Building Docker image..."
        if ! docker build -t ibmcloud-mcp-server . ; then
            echo "❌ Failed to build Docker image"
            exit 1
        fi
        
        # Create configuration for Docker
        CONFIG_JSON=$(cat <<EOF
{
  "mcpServers": {
    "ibmcloud": {
      "command": "$DOCKER_WRAPPER",
      "args": [],
      "env": {
        "PATH": "/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
EOF
)
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Backup existing config if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📄 Backing up existing config to: $BACKUP_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    
    # Try to merge with existing config
    echo ""
    echo "⚠️  Existing Claude Desktop configuration found."
    echo "Do you want to:"
    echo "1) Replace the entire configuration"
    echo "2) Merge with existing configuration"
    echo ""
    read -p "Enter your choice (1 or 2): " merge_choice
    
    if [[ "$merge_choice" == "2" ]]; then
        # Merge configurations
        TEMP_FILE=$(mktemp)
        echo "$CONFIG_JSON" > "$TEMP_FILE"
        
        # Use jq to merge if available
        if command -v jq &> /dev/null; then
            jq -s '.[0] * .[1]' "$CONFIG_FILE" "$TEMP_FILE" > "${CONFIG_FILE}.new"
            mv "${CONFIG_FILE}.new" "$CONFIG_FILE"
            rm "$TEMP_FILE"
        else
            echo "⚠️  jq not found - cannot auto-merge. Manual merge required."
            echo "New configuration written to: ${CONFIG_FILE}.new"
            echo "$CONFIG_JSON" > "${CONFIG_FILE}.new"
        fi
    else
        # Replace entire configuration
        echo "$CONFIG_JSON" > "$CONFIG_FILE"
    fi
else
    # No existing config, create new one
    echo "$CONFIG_JSON" > "$CONFIG_FILE"
fi

echo ""
echo "✅ Configuration written to: $CONFIG_FILE"
echo ""

# Test the setup
echo "🧪 Testing the MCP server..."
if echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | "$SCRIPT_PATH" > /dev/null 2>&1; then
    echo "✅ MCP server test passed"
else
    echo "❌ MCP server test failed"
    echo "Please check your IBM Cloud CLI authentication:"
    echo "  ibmcloud login"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Restart Claude Desktop"
echo "2. Start a new conversation"
echo "3. Try asking: 'Show me my IBM Cloud target information'"
echo ""
echo "Configuration file location: $CONFIG_FILE"

# Show the final configuration
echo ""
echo "📋 Final configuration:"
cat "$CONFIG_FILE" | head -20
if [[ $(cat "$CONFIG_FILE" | wc -l) -gt 20 ]]; then
    echo "... (truncated)"
fi