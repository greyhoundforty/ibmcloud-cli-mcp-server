#!/bin/bash
# Persistent MCP Server Wrapper to keep the server alive

# This wrapper ensures the MCP server stays alive to handle multiple requests
# instead of exiting after the first request

# Enable debug mode
export MCP_DEBUG=true

# Override configuration paths
MCP_CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/assets/ibmcloud_config.json"
MCP_TOOLS_LIST_FILE="$(dirname "${BASH_SOURCE[0]}")/assets/ibmcloud_tools.json"
MCP_LOG_FILE="$(dirname "${BASH_SOURCE[0]}")/logs/ibmcloud.log"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "${BASH_SOURCE[0]}")/logs"

# Debug logging function
debug_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="${MCP_LOG_FILE}"
    
    # Write to log file
    echo "[$timestamp] WRAPPER DEBUG: $message" >> "$log_file"
    
    # Write to stderr so it appears in Claude Desktop logs
    echo "[$timestamp] IBM Cloud MCP WRAPPER: $message" >&2
}

debug_log "Starting persistent MCP server wrapper"
debug_log "Wrapper script: ${BASH_SOURCE[0]}"

# Load the IBM Cloud MCP server functions
debug_log "Loading IBM Cloud MCP server functions"
source "$(dirname "${BASH_SOURCE[0]}")/ibmcloud_mcp_server.sh"

debug_log "IBM Cloud MCP server functions loaded"

# Override the run_mcp_server function to make it persistent
run_mcp_server_persistent() {
    debug_log "Starting persistent MCP server loop"
    
    # Source the core MCP server to get the base functions
    if ! source "$(dirname "${BASH_SOURCE[0]}")/mcpserver_core.sh"; then
        debug_log "Failed to source mcpserver_core.sh"
        exit 1
    fi
    
    debug_log "Core MCP server sourced successfully"
    
    # Send initial server info
    echo '{"jsonrpc":"2.0","result":{"protocolVersion":"0.1.0","serverInfo":{"name":"IBMCloudServer","version":"1.0.0","description":"MCP Server for IBM Cloud CLI operations"},"capabilities":{"tools":{"listChanged":true}}},"id":null}' >&2
    
    debug_log "Entering main request loop"
    
    # Main request processing loop
    while IFS= read -r line; do
        debug_log "Received request: ${line:0:100}..."
        
        # Check if we received an empty line or EOF
        if [[ -z "$line" ]]; then
            debug_log "Received empty line, continuing..."
            continue
        fi
        
        # Process the request using the original MCP server logic
        echo "$line" | timeout 30 bash -c '
            # Re-source the functions
            source "$(dirname "${BASH_SOURCE[0]}")/ibmcloud_mcp_server.sh" 2>/dev/null
            source "$(dirname "${BASH_SOURCE[0]}")/mcpserver_core.sh" 2>/dev/null
            
            # Process the single request
            if declare -f process_request > /dev/null; then
                process_request
            elif declare -f run_mcp_server > /dev/null; then
                run_mcp_server
            else
                echo "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"Method not found\"},\"id\":null}"
            fi
        '
        
        local exit_code=$?
        debug_log "Request processed with exit code: $exit_code"
        
        # If timeout or error, log it but continue
        if [[ $exit_code -eq 124 ]]; then
            debug_log "Request timed out after 30 seconds"
        elif [[ $exit_code -ne 0 ]]; then
            debug_log "Request processing failed with exit code: $exit_code"
        fi
        
    done
    
    debug_log "Request loop ended"
}

# Alternative: Simple persistent loop that handles basic MCP protocol
run_simple_persistent_server() {
    debug_log "Starting simple persistent MCP server"
    
    # Read and process JSON-RPC requests one by one
    while IFS= read -r request; do
        debug_log "Processing request: ${request:0:100}..."
        
        # Parse the request method
        local method=$(echo "$request" | jq -r '.method // "unknown"')
        local id=$(echo "$request" | jq -r '.id // null')
        local params=$(echo "$request" | jq -r '.params // {}')
        
        debug_log "Method: $method, ID: $id"
        
        case "$method" in
            "initialize")
                debug_log "Handling initialize request"
                echo '{"jsonrpc":"2.0","result":{"protocolVersion":"0.1.0","serverInfo":{"name":"IBMCloudServer","version":"1.0.0","description":"MCP Server for IBM Cloud CLI operations"},"capabilities":{"tools":{"listChanged":true}},"instructions":"This server provides access to IBM Cloud CLI operations including resource management, VPC operations, and account information. Requires IBM Cloud CLI to be installed and authenticated.","environment":{"required_tools":["ibmcloud","jq"],"optional_plugins":["vpc-infrastructure","cloud-functions","kubernetes-service"]}},"id":'$id'}'
                ;;
            "tools/list")
                debug_log "Handling tools/list request"
                if [[ -f "$MCP_TOOLS_LIST_FILE" ]]; then
                    local tools=$(jq '.tools' "$MCP_TOOLS_LIST_FILE")
                    echo '{"jsonrpc":"2.0","result":{"tools":'$tools'},"id":'$id'}'
                else
                    echo '{"jsonrpc":"2.0","error":{"code":-32603,"message":"Tools configuration file not found"},"id":'$id'}'
                fi
                ;;
            "tools/call")
                debug_log "Handling tools/call request"
                local tool_name=$(echo "$params" | jq -r '.name // ""')
                local tool_args=$(echo "$params" | jq -r '.arguments // {}')
                
                debug_log "Calling tool: $tool_name with args: $tool_args"
                
                # Call the appropriate tool function
                local tool_function="tool_$tool_name"
                if declare -f "$tool_function" > /dev/null; then
                    local result
                    if result=$($tool_function "$tool_args" 2>&1); then
                        # Escape the result for JSON
                        local escaped_result=$(echo "$result" | jq -R -s .)
                        echo '{"jsonrpc":"2.0","result":'$escaped_result',"id":'$id'}'
                    else
                        local error_msg=$(echo "$result" | jq -R -s .)
                        echo '{"jsonrpc":"2.0","error":{"code":-32603,"message":"Tool execution error","data":'$error_msg'},"id":'$id'}'
                    fi
                else
                    echo '{"jsonrpc":"2.0","error":{"code":-32601,"message":"Tool not found: '$tool_name'"},"id":'$id'}'
                fi
                ;;
            *)
                debug_log "Unknown method: $method"
                echo '{"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found: '$method'"},"id":'$id'}'
                ;;
        esac
        
        debug_log "Request completed"
        
    done
    
    debug_log "Server loop ended"
}

# Trap signals to log when the server is interrupted
trap 'debug_log "Server interrupted by signal"' INT TERM
trap 'debug_log "Server exiting with code $?"' EXIT

# Start the persistent server
debug_log "Starting server with method: simple persistent"
run_simple_persistent_server