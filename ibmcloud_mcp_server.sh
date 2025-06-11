#!/bin/bash
# IBM Cloud CLI MCP Server Implementation

# Override configuration paths BEFORE sourcing the core
MCP_CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/assets/ibmcloud_config.json"
MCP_TOOLS_LIST_FILE="$(dirname "${BASH_SOURCE[0]}")/assets/ibmcloud_tools.json"
MCP_LOG_FILE="$(dirname "${BASH_SOURCE[0]}")/logs/ibmcloud.log"

# MCP Server Tool Function Guidelines:
# 1. Name all tool functions with prefix "tool_" followed by the same name defined in tools_list.json
# 2. Function should accept a single parameter "$1" containing JSON arguments
# 3. For successful operations: Echo the expected result and return 0
# 4. For errors: Echo an error message and return 1
# 5. All tool functions are automatically exposed to the MCP server based on tools_list.json

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "${BASH_SOURCE[0]}")/logs"

# Debug logging function - writes to both file and stderr for Claude Desktop logs
debug_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="${MCP_LOG_FILE:-$(dirname "${BASH_SOURCE[0]}")/logs/ibmcloud.log}"
    
    # Write to log file
    echo "[$timestamp] DEBUG: $message" >> "$log_file"
    
    # Write to stderr so it appears in Claude Desktop logs
    echo "[$timestamp] IBM Cloud MCP DEBUG: $message" >&2
    
    # Also write to stdout for immediate visibility during testing
    if [[ "${MCP_DEBUG:-false}" == "true" ]]; then
        echo "[$timestamp] DEBUG: $message"
    fi
}

# Error logging function
error_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="${MCP_LOG_FILE:-$(dirname "${BASH_SOURCE[0]}")/logs/ibmcloud.log}"
    
    # Write to log file
    echo "[$timestamp] ERROR: $message" >> "$log_file"
    
    # Write to stderr so it appears in Claude Desktop logs
    echo "[$timestamp] IBM Cloud MCP ERROR: $message" >&2
}

# Initialize debugging
debug_log "Starting IBM Cloud MCP Server initialization"
debug_log "Script path: ${BASH_SOURCE[0]}"
debug_log "Working directory: $(pwd)"
debug_log "Environment: PATH=$PATH"
debug_log "Debug mode: ${MCP_DEBUG:-false}"

# Load environment variables from .env file if it exists
load_env_file() {
    local env_file="$(dirname "${BASH_SOURCE[0]}")/.env"
    debug_log "Checking for .env file at: $env_file"
    
    if [[ -f "$env_file" ]]; then
        debug_log "Found .env file, loading environment variables"
        debug_log ".env file permissions: $(ls -la "$env_file")"
        debug_log ".env file contents (masked):"
        
        local loaded_vars=0
        
        # Load .env file, ignoring comments and empty lines
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            
            # Extract variable name and value
            local var_name="${line%%=*}"
            local var_value="${line#*=}"
            
            # Remove any quotes around the value
            var_value="${var_value%\"}"
            var_value="${var_value#\"}"
            var_value="${var_value%\'}"
            var_value="${var_value#\'}"
            
            debug_log "Loading: $var_name=${var_value:0:8}... (${#var_value} chars)"
            
            # Export the variable
            export "$var_name=$var_value"
            
            # Verify it was exported
            local exported_value
            case "$var_name" in
                "IBMCLOUD_API_KEY")
                    exported_value="${!var_name}"
                    debug_log "Exported IBMCLOUD_API_KEY: ${exported_value:0:8}... (${#exported_value} chars)"
                    ;;
                *)
                    debug_log "Exported $var_name: ${!var_name}"
                    ;;
            esac
            
            ((loaded_vars++))
        done < "$env_file"
        
        debug_log "Loaded $loaded_vars environment variables from .env file"
        
        # Double-check that IBMCLOUD_API_KEY is available
        if [[ -n "$IBMCLOUD_API_KEY" ]]; then
            debug_log "IBMCLOUD_API_KEY is available after loading (${#IBMCLOUD_API_KEY} chars)"
        else
            debug_log "IBMCLOUD_API_KEY is NOT available after loading"
        fi
        
    else
        debug_log "No .env file found"
    fi
}

# Authenticate with IBM Cloud using available methods
authenticate_ibmcloud() {
    debug_log "Starting IBM Cloud authentication process"
    
    # Try API key from environment variable
    if [[ -n "$IBMCLOUD_API_KEY" ]]; then
        debug_log "Found IBMCLOUD_API_KEY environment variable (length: ${#IBMCLOUD_API_KEY} chars)"
        debug_log "API key starts with: ${IBMCLOUD_API_KEY:0:8}..."
        
        debug_log "Attempting authentication with API key"
        
        # Try authentication and capture detailed output
        local auth_output
        local auth_exit_code
        
        auth_output=$(ibmcloud login --apikey "$IBMCLOUD_API_KEY" --quiet 2>&1)
        auth_exit_code=$?
        
        debug_log "Authentication command exit code: $auth_exit_code"
        debug_log "Authentication output: $auth_output"
        
        if [[ $auth_exit_code -eq 0 ]]; then
            debug_log "Successfully authenticated with API key"
            
            # Verify authentication worked by checking target
            local target_output
            target_output=$(ibmcloud target 2>&1)
            debug_log "Target verification: $target_output"
            
            return 0
        else
            error_log "Failed to authenticate with API key. Exit code: $auth_exit_code"
            error_log "Authentication error output: $auth_output"
            
            # Check if API key format looks valid
            if [[ ${#IBMCLOUD_API_KEY} -lt 20 ]]; then
                error_log "API key appears too short (${#IBMCLOUD_API_KEY} chars)"
            fi
            
            # Check for common authentication errors
            if echo "$auth_output" | grep -q "Invalid API key"; then
                error_log "API key is invalid"
            elif echo "$auth_output" | grep -q "expired"; then
                error_log "API key may be expired"
            elif echo "$auth_output" | grep -q "network"; then
                error_log "Network connectivity issue"
            fi
        fi
    else
        debug_log "No IBMCLOUD_API_KEY environment variable found"
    fi
    
    # Check if already authenticated
    debug_log "Checking existing authentication status"
    local target_output
    local target_exit_code
    
    target_output=$(ibmcloud target 2>&1)
    target_exit_code=$?
    
    debug_log "Target check exit code: $target_exit_code"
    debug_log "Target check output: $target_output"
    
    if [[ $target_exit_code -eq 0 ]]; then
        debug_log "Already authenticated with IBM Cloud"
        return 0
    else
        debug_log "No existing authentication found"
    fi
    
    error_log "Authentication failed - no valid credentials found"
    return 1
}

# Utility function to check if IBM Cloud CLI is installed and logged in
check_ibmcloud_cli() {
    debug_log "Checking IBM Cloud CLI prerequisites"
    
    if ! command -v ibmcloud &> /dev/null; then
        error_log "IBM Cloud CLI is not installed"
        echo "Error: IBM Cloud CLI is not installed"
        return 1
    fi
    debug_log "IBM Cloud CLI is installed"
    
    # Check IBM Cloud CLI version
    local cli_version=$(ibmcloud version 2>/dev/null | head -1)
    debug_log "IBM Cloud CLI version: $cli_version"
    
    # Load environment variables
    debug_log "Loading environment variables"
    load_env_file
    
    # List relevant environment variables for debugging
    debug_log "Relevant environment variables after loading:"
    debug_log "  IBMCLOUD_API_KEY: ${IBMCLOUD_API_KEY:+[SET - ${#IBMCLOUD_API_KEY} chars]} ${IBMCLOUD_API_KEY:-[NOT SET]}"
    if [[ -n "$IBMCLOUD_API_KEY" ]]; then
        debug_log "  IBMCLOUD_API_KEY preview: ${IBMCLOUD_API_KEY:0:8}..."
    fi
    debug_log "  IBMCLOUD_REGION: ${IBMCLOUD_REGION:-[NOT SET]}"
    debug_log "  IBMCLOUD_RESOURCE_GROUP: ${IBMCLOUD_RESOURCE_GROUP:-[NOT SET]}"
    debug_log "  IBMCLOUD_HOME: ${IBMCLOUD_HOME:-[NOT SET]}"
    
    # Try to authenticate
    debug_log "Attempting authentication"
    if ! authenticate_ibmcloud; then
        error_log "Authentication failed"
        echo "Error: Not logged in to IBM Cloud. Please either:"
        echo "  1. Run 'ibmcloud login'"
        echo "  2. Set IBMCLOUD_API_KEY environment variable"
        echo "  3. Create a .env file with IBMCLOUD_API_KEY=your-key"
        return 1
    fi
    
    debug_log "Authentication successful"
    
    # Get and log current target information
    local target_info=$(ibmcloud target --output json 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        debug_log "Current target information: $target_info"
    else
        debug_log "Could not retrieve target information"
    fi
    
    return 0
}

# Tool: List all resources in the current account
tool_list_resources() {
    local args="$1"
    debug_log "tool_list_resources called with args: $args"
    
    if ! check_ibmcloud_cli; then
        error_log "IBM Cloud CLI check failed in tool_list_resources"
        return 1
    fi
    
    local resource_type=$(echo "$args" | jq -r '.resource_type // "all"')
    local region=$(echo "$args" | jq -r '.region // ""')
    
    debug_log "Parsed parameters - resource_type: $resource_type, region: $region"
    
    local cmd="ibmcloud resource service-instances"
    
    if [[ "$region" != "" && "$region" != "null" ]]; then
        cmd="$cmd --location $region"
        debug_log "Added region filter: $region"
    fi
    
    debug_log "Executing command: $cmd"
    local result=$(eval "$cmd" --output json 2>&1)
    local exit_code=$?
    
    debug_log "Command exit code: $exit_code"
    
    if [[ $exit_code -eq 0 ]]; then
        debug_log "tool_list_resources completed successfully"
        echo "$result"
        return 0
    else
        error_log "tool_list_resources failed: $result"
        echo "Error listing resources: $result"
        return 1
    fi
}

# Tool: Get current target information
tool_get_target() {
    local args="$1"
    debug_log "tool_get_target called with args: $args"
    
    if ! check_ibmcloud_cli; then
        error_log "IBM Cloud CLI check failed in tool_get_target"
        return 1
    fi
    
    debug_log "Executing: ibmcloud target --output json"
    local result=$(ibmcloud target --output json 2>&1)
    local exit_code=$?
    
    debug_log "Command exit code: $exit_code"
    
    if [[ $exit_code -eq 0 ]]; then
        debug_log "tool_get_target completed successfully"
        echo "$result"
        return 0
    else
        error_log "tool_get_target failed: $result"
        echo "Error getting target information: $result"
        return 1
    fi
}

# Tool: List VPC instances
tool_list_vpc_instances() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    # Ensure VPC plugin is available
    if ! ibmcloud plugin list | grep -q "vpc-infrastructure"; then
        echo "Error: IBM Cloud VPC plugin is not installed. Install with: ibmcloud plugin install vpc-infrastructure"
        return 1
    fi
    
    local region=$(echo "$args" | jq -r '.region // ""')
    
    # Set target region if provided
    if [[ "$region" != "" && "$region" != "null" ]]; then
        ibmcloud target -r "$region" &> /dev/null
    fi
    
    local result=$(ibmcloud is instances --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error listing VPC instances: $result"
        return 1
    fi
}

# Tool: List VPCs
tool_list_vpcs() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    if ! ibmcloud plugin list | grep -q "vpc-infrastructure"; then
        echo "Error: IBM Cloud VPC plugin is not installed"
        return 1
    fi
    
    local region=$(echo "$args" | jq -r '.region // ""')
    
    if [[ "$region" != "" && "$region" != "null" ]]; then
        ibmcloud target -r "$region" &> /dev/null
    fi
    
    local result=$(ibmcloud is vpcs --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error listing VPCs: $result"
        return 1
    fi
}

# Tool: Get resource group information
tool_list_resource_groups() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local result=$(ibmcloud resource groups --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error listing resource groups: $result"
        return 1
    fi
}

# Tool: List regions
tool_list_regions() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local result=$(ibmcloud regions --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error listing regions: $result"
        return 1
    fi
}

# Tool: Get account information
tool_get_account_info() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local result=$(ibmcloud account show --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error getting account info: $result"
        return 1
    fi
}

# Tool: List Cloud Foundry apps
tool_list_cf_apps() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local space=$(echo "$args" | jq -r '.space // ""')
    local org=$(echo "$args" | jq -r '.org // ""')
    
    # Target org and space if provided
    if [[ "$org" != "" && "$org" != "null" ]]; then
        if [[ "$space" != "" && "$space" != "null" ]]; then
            ibmcloud target -o "$org" -s "$space" &> /dev/null
        else
            ibmcloud target -o "$org" &> /dev/null
        fi
    fi
    
    local result=$(ibmcloud cf apps 2>&1)
    
    if [[ $? -eq 0 ]]; then
        # Convert to JSON format
        echo "{\"apps\": \"$result\"}"
        return 0
    else
        echo "Error listing CF apps: $result"
        return 1
    fi
}

# Tool: Execute custom IBM Cloud CLI command
tool_execute_command() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local command=$(echo "$args" | jq -r '.command')
    local safe_mode=$(echo "$args" | jq -r '.safe_mode // true')
    
    if [[ "$command" == "" || "$command" == "null" ]]; then
        echo "Error: No command provided"
        return 1
    fi
    
    # Safety check - only allow read-only commands in safe mode
    if [[ "$safe_mode" == "true" ]]; then
        local readonly_commands=("list" "show" "get" "target" "regions" "zones" "plugins" "help" "version")
        local is_safe=false
        
        for safe_cmd in "${readonly_commands[@]}"; do
            if [[ "$command" == *"$safe_cmd"* ]]; then
                is_safe=true
                break
            fi
        done
        
        if [[ "$is_safe" == "false" ]]; then
            echo "Error: Command '$command' is not allowed in safe mode. Only read-only operations are permitted."
            return 1
        fi
    fi
    
    # Execute the command
    local result=$(ibmcloud $command 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error executing command: $result"
        return 1
    fi
}

# Pre-startup checks and debugging
debug_log "Performing pre-startup checks"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    error_log "jq is not installed - this is required for JSON processing"
    echo "Error: jq is not installed. Please install jq for JSON processing." >&2
    exit 1
else
    debug_log "jq is available: $(jq --version)"
fi

# Check if mcpserver_core.sh exists
CORE_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/mcpserver_core.sh"
if [[ ! -f "$CORE_SCRIPT" ]]; then
    error_log "mcpserver_core.sh not found at: $CORE_SCRIPT"
    echo "Error: mcpserver_core.sh not found. Please ensure the core MCP server file exists." >&2
    exit 1
else
    debug_log "Found mcpserver_core.sh at: $CORE_SCRIPT"
fi

# Check configuration files
debug_log "Checking configuration files"
debug_log "  MCP_CONFIG_FILE: ${MCP_CONFIG_FILE}"
debug_log "  MCP_TOOLS_LIST_FILE: ${MCP_TOOLS_LIST_FILE}"
debug_log "  MCP_LOG_FILE: ${MCP_LOG_FILE}"

if [[ ! -f "${MCP_CONFIG_FILE}" ]]; then
    error_log "Configuration file not found: ${MCP_CONFIG_FILE}"
else
    debug_log "Configuration file exists: ${MCP_CONFIG_FILE}"
fi

if [[ ! -f "${MCP_TOOLS_LIST_FILE}" ]]; then
    error_log "Tools list file not found: ${MCP_TOOLS_LIST_FILE}"
else
    debug_log "Tools list file exists: ${MCP_TOOLS_LIST_FILE}"
fi

# Perform initial IBM Cloud CLI check
debug_log "Performing initial IBM Cloud CLI connectivity check"
if check_ibmcloud_cli; then
    debug_log "Initial IBM Cloud CLI check passed"
else
    error_log "Initial IBM Cloud CLI check failed"
    # Don't exit here - let the individual tools handle auth failures
fi

debug_log "Pre-startup checks completed"

# Source the core MCP server implementation
debug_log "Sourcing mcpserver_core.sh"
debug_log "Sourcing mcpserver_core.sh"
if source "$(dirname "${BASH_SOURCE[0]}")/mcpserver_core.sh"; then
    debug_log "Successfully sourced mcpserver_core.sh"
else
    error_log "Failed to source mcpserver_core.sh"
    exit 1
fi

# Debug function availability
debug_log "Checking if run_mcp_server function is available"
if declare -f run_mcp_server > /dev/null; then
    debug_log "run_mcp_server function is available"
else
    error_log "run_mcp_server function is not available"
    exit 1
fi

# List all available tool functions for debugging
debug_log "Available tool functions:"
for func in $(declare -F | grep "tool_" | awk '{print $3}'); do
    debug_log "  - $func"
done

# Start the MCP server (this should be called when the script is executed)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    debug_log "Starting MCP server main loop"
    debug_log "Arguments passed to script: $*"
    
    # Add trap to catch any exit signals
    trap 'debug_log "Script is exiting with code $?"' EXIT
    trap 'error_log "Script interrupted by signal"' INT TERM
    
    debug_log "Calling run_mcp_server function"
    run_mcp_server "$@"
    debug_log "run_mcp_server function returned"
else
    debug_log "Script is being sourced, not executed directly"
fi