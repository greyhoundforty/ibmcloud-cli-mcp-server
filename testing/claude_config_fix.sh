#!/bin/bash
# Fix Claude Desktop configuration to use persistent MCP server

echo "🔧 Claude Desktop Configuration Fix"
echo "==================================="

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

echo "Configuration file: $CONFIG_FILE"
echo ""

# Check if persistent wrapper exists
CURRENT_DIR=$(pwd)
PERSISTENT_WRAPPER="$CURRENT_DIR/persistent_mcp_wrapper.sh"

if [[ ! -f "$PERSISTENT_WRAPPER" ]]; then
    echo "❌ Persistent wrapper not found at: $PERSISTENT_WRAPPER"
    echo "Please ensure persistent_mcp_wrapper.sh exists in the current directory"
    exit 1
fi

# Make wrapper executable
chmod +x "$PERSISTENT_WRAPPER"
echo "✅ Persistent wrapper found and made executable"

# Backup existing config
if [[ -f "$CONFIG_FILE" ]]; then
    BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📄 Creating backup: $BACKUP_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

# Create new configuration using persistent wrapper
echo ""
echo "📝 Creating configuration for persistent MCP server..."

cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "ibmcloud": {
      "command": "$PERSISTENT_WRAPPER",
      "args": [],
      "env": {
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "IBMCLOUD_HOME": "$HOME/.bluemix",
        "MCP_DEBUG": "true"
      }
    }
  }
}
EOF

echo "✅ Configuration updated to use persistent wrapper"

# Validate the configuration
echo ""
echo "🔍 Validating configuration..."
if command -v jq &> /dev/null; then
    if jq . "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "✅ Configuration JSON is valid"
    else
        echo "❌ Configuration JSON is invalid"
        exit 1
    fi
else
    echo "⚠️  jq not available for validation"
fi

# Test the persistent wrapper
echo ""
echo "🧪 Testing persistent wrapper..."
echo "Sending test request..."

# Quick test
if timeout 5 bash -c 'echo "{\"jsonrpc\": \"2.0\", \"method\": \"initialize\", \"params\": {\"protocolVersion\": \"2024-11-05\", \"capabilities\": {}, \"clientInfo\": {\"name\": \"test\", \"version\": \"1.0.0\"}}, \"id\": 1}" | '"$PERSISTENT_WRAPPER" > /dev/null 2>&1; then
    echo "✅ Persistent wrapper test passed"
else
    echo "❌ Persistent wrapper test failed"
    echo "Check the logs: tail -f logs/ibmcloud.log"
fi

echo ""
echo "🎉 Configuration update complete!"
echo ""
echo "📋 Summary:"
echo "- Using persistent wrapper: $PERSISTENT_WRAPPER"
echo "- Configuration file: $CONFIG_FILE"
echo "- Debug mode enabled: true"
echo ""
echo "Next steps:"
echo "1. Restart Claude Desktop"
echo "2. Try asking: 'Show me my IBM Cloud target information'"
echo "3. If issues persist, check logs: tail -f logs/ibmcloud.log"

# Show final configuration
echo ""
echo "📄 Final configuration:"
cat "$CONFIG_FILE"