#!/bin/bash
# Quick debug test for IBM Cloud MCP Server

echo "🚀 Quick Debug Test for IBM Cloud MCP Server"
echo "============================================"

# Enable debug mode
export MCP_DEBUG=true

echo ""
echo "1. Checking if script is executable..."
if [[ ! -x "./ibmcloud_mcp_server.sh" ]]; then
    echo "Making script executable..."
    chmod +x ./ibmcloud_mcp_server.sh
fi
echo "✅ Script is executable"

echo ""
echo "2. Testing basic MCP server startup..."
echo ""

# Create a simple test that should show us what's happening
echo "Sending initialize request..."

# Use a timeout to prevent hanging
timeout 10s bash -c '
echo "{\\"jsonrpc\\": \\"2.0\\", \\"method\\": \\"initialize\\", \\"params\\": {\\"protocolVersion\\": \\"2024-11-05\\", \\"capabilities\\": {}, \\"clientInfo\\": {\\"name\\": \\"debug-client\\", \\"version\\": \\"1.0.0\\"}}, \\"id\\": 1}" | ./ibmcloud_mcp_server.sh
' 2>&1

echo ""
echo "Exit code: $?"

echo ""
echo "3. Checking log file..."
if [[ -f "logs/ibmcloud.log" ]]; then
    echo "Last 10 lines from log:"
    tail -10 logs/ibmcloud.log
else
    echo "No log file found"
fi

echo ""
echo "4. Quick environment check..."
echo "IBM Cloud CLI: $(command -v ibmcloud || echo 'NOT FOUND')"
echo "jq: $(command -v jq || echo 'NOT FOUND')"
echo "mcpserver_core.sh: $([ -f mcpserver_core.sh ] && echo 'EXISTS' || echo 'NOT FOUND')"

echo ""
echo "Debug test complete!"
echo "For more detailed debugging, run: ./debug_mcp.sh"