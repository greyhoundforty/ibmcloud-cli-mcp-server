# IBM Cloud CLI MCP Server

A Model Context Protocol (MCP) server implementation for IBM Cloud CLI operations using the bash MCP SDK.

## Prerequisites

- **IBM Cloud CLI**: Install from [IBM Cloud CLI documentation](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
- **jq**: JSON processor for handling API responses
- **bash**: Shell environment (Linux/macOS/WSL)

## Installation

1. Clone the mcp-server-bash-sdk repository:
```bash
git clone https://github.com/muthuishere/mcp-server-bash-sdk
cd mcp-server-bash-sdk
```

2. Copy the IBM Cloud MCP server files into the repository:
   - `ibmcloud_mcp_server.sh` (main server script)
   - `assets/ibmcloud_config.json` (server configuration)
   - `assets/ibmcloud_tools.json` (tools definition)
   - `setup.sh` (setup script)

3. Run the setup script:
```bash
chmod +x setup.sh
./setup.sh
```

4. Login to IBM Cloud:
```bash
ibmcloud login
# For federated login:
ibmcloud login --sso
```

## Available Tools

### Resource Management
- **`list_resources`**: List all resources in the current account
- **`list_resource_groups`**: List all resource groups
- **`get_account_info`**: Get current account information

### VPC Operations  
- **`list_vpc_instances`**: List VPC instances
- **`list_vpcs`**: List VPCs in the account

### Target Information
- **`get_target`**: Get current target (account, region, resource group)
- **`list_regions`**: List all available IBM Cloud regions

### Cloud Foundry
- **`list_cf_apps`**: List Cloud Foundry applications

### Custom Commands
- **`execute_command`**: Execute custom IBM Cloud CLI commands (safe mode enabled by default)

## Usage Examples

### Test the server
```bash
# List available tools
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | ./ibmcloud_mcp_server.sh

# Get current target information
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "get_target"}, "id": 1}' | ./ibmcloud_mcp_server.sh

# List VPC instances in a specific region
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "list_vpc_instances", "arguments": {"region": "us-south"}}, "id": 1}' | ./ibmcloud_mcp_server.sh

# Execute a custom command
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "execute_command", "arguments": {"command": "plugin list"}}, "id": 1}' | ./ibmcloud_mcp_server.sh
```

### Integration with AI Tools

You can integrate this MCP server with AI tools that support the Model Context Protocol:

1. **VS Code with GitHub Copilot**: Add to your VS Code settings.json
2. **Claude Desktop**: Configure in the MCP settings
3. **Other MCP-compatible tools**: Use the stdio interface

Example VS Code settings.json configuration:
```json
{
  "github.copilot.chat.experimental.mcpServers": {
    "ibmcloud": {
      "command": "/path/to/ibmcloud_mcp_server.sh",
      "args": []
    }
  }
}
```

## Configuration

### Server Configuration (`assets/ibmcloud_config.json`)
- **protocolVersion**: MCP protocol version
- **serverInfo**: Server metadata and description
- **capabilities**: Supported MCP capabilities
- **instructions**: Usage instructions for AI systems

### Tools Configuration (`assets/ibmcloud_tools.json`)
- Defines all available tools and their parameters
- JSON Schema validation for parameters
- Tool descriptions for AI understanding

## Security Features

### Safe Mode
The `execute_command` tool runs in safe mode by default, allowing only read-only operations:
- `list`, `show`, `get`, `target`, `regions`, `zones`, `plugins`, `help`, `version`

To disable safe mode (use with caution):
```bash
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "execute_command", "arguments": {"command": "resource service-instance-create ...", "safe_mode": false}}, "id": 1}' | ./ibmcloud_mcp_server.sh
```

### Authentication Check
All tools verify IBM Cloud CLI authentication before execution.

## Logging

Logs are written to `logs/ibmcloud.log` for debugging and monitoring.

## Extending the Server

To add new tools:

1. Add a new function in `ibmcloud_mcp_server.sh` with the `tool_` prefix:
```bash
tool_my_new_tool() {
    local args="$1"
    # Implementation here
    echo "result"
    return 0
}
```

2. Add the tool definition to `assets/ibmcloud_tools.json`:
```json
{
  "name": "my_new_tool",
  "description": "Description of the new tool",
  "parameters": {
    "type": "object",
    "properties": {
      // Parameter definitions
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **IBM Cloud CLI not found**
   - Install IBM Cloud CLI from the official documentation
   - Ensure it's in your PATH

2. **Authentication errors**
   - Run `ibmcloud login` to authenticate
   - Check target settings with `ibmcloud target`

3. **Plugin not found errors**
   - Install required plugins: `ibmcloud plugin install vpc-infrastructure`
   - Run `setup.sh` to install recommended plugins

4. **Permission errors**
   - Make scripts executable: `chmod +x ibmcloud_mcp_server.sh`
   - Check IBM Cloud account permissions

### Debug Mode

Enable debug logging by setting environment variables:
```bash
export MCP_DEBUG=1
./ibmcloud_mcp_server.sh
```

## License

This project follows the MIT License from the original bash MCP SDK.

## Contributing

Contributions are welcome! Please ensure:
- All new tools follow the `tool_` naming convention
- Tools include proper error handling
- Configuration files are updated accordingly
- Documentation is updated