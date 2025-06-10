#!/bin/bash
# Setup script for IBM Cloud MCP Server

set -e

echo "Setting up IBM Cloud MCP Server..."

# Create directory structure
echo "Creating directory structure..."
mkdir -p assets
mkdir -p logs

# Check if IBM Cloud CLI is installed
if ! command -v ibmcloud &> /dev/null; then
    echo "❌ IBM Cloud CLI is not installed"
    echo "Please install it from: https://cloud.ibm.com/docs/cli?topic=cli-getting-started"
    echo ""
    echo "Installation commands:"
    echo "  macOS: curl -fsSL https://clis.cloud.ibm.com/install/osx | sh"
    echo "  Linux: curl -fsSL https://clis.cloud.ibm.com/install/linux | sh"
    echo "  Windows: iex(New-Object Net.WebClient).DownloadString('https://clis.cloud.ibm.com/install/powershell')"
    exit 1
else
    echo "✅ IBM Cloud CLI is installed"
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed"
    echo "Please install it:"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  CentOS/RHEL: sudo yum install jq"
    exit 1
else
    echo "✅ jq is installed"
fi

# Check if user is logged in
if ! ibmcloud target &> /dev/null; then
    echo "❌ Not logged in to IBM Cloud"
    echo "Please run: ibmcloud login"
    echo "For federated login: ibmcloud login --sso"
    exit 1
else
    echo "✅ Logged in to IBM Cloud"
fi

# Install recommended plugins
echo ""
echo "Installing recommended IBM Cloud CLI plugins..."

plugins_to_install=(
    "vpc-infrastructure"
    "code-engine"
    "container-service"
    "container-registry"
    "cloud-object-storage"
)

for plugin in "${plugins_to_install[@]}"; do
    if ibmcloud plugin list | grep -q "$plugin"; then
        echo "✅ Plugin '$plugin' is already installed"
    else
        echo "Installing plugin '$plugin'..."
        ibmcloud plugin install "$plugin" -f
        echo "✅ Installed plugin '$plugin'"
    fi
done

# Make scripts executable
echo ""
echo "Making scripts executable..."
chmod +x ibmcloud_mcp_server.sh
chmod +x setup.sh

# Verify mcpserver_core.sh exists
if [[ ! -f "mcpserver_core.sh" ]]; then
    echo "❌ mcpserver_core.sh not found"
    echo "Please ensure you have the core MCP server file from:"
    echo "https://github.com/muthuishere/mcp-server-bash-sdk"
    exit 1
else
    echo "✅ mcpserver_core.sh found"
fi

# Test the server
echo ""
echo "Testing the MCP server..."
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | ./ibmcloud_mcp_server.sh > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo "✅ MCP server test passed"
else
    echo "⚠️  MCP server test failed - check the logs"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Usage:"
echo "  Test tool listing: echo '{\"jsonrpc\": \"2.0\", \"method\": \"tools/list\", \"id\": 1}' | ./ibmcloud_mcp_server.sh"
echo "  Test get target: echo '{\"jsonrpc\": \"2.0\", \"method\": \"tools/call\", \"params\": {\"name\": \"get_target\"}, \"id\": 1}' | ./ibmcloud_mcp_server.sh"
echo ""
echo "Configuration files:"
echo "  - assets/ibmcloud_config.json"
echo "  - assets/ibmcloud_tools.json"
echo "  - logs/ibmcloud.log"