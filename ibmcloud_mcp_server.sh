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

# IBM Cloud login
# Access environment variables
IBMCLOUD_API_KEY="${IBMCLOUD_API_KEY:-default_key}"


# Create logs directory if it doesn't exist
mkdir -p "$(dirname "${BASH_SOURCE[0]}")/logs"

# Utility function to check if IBM Cloud CLI is installed and logged in
check_ibmcloud_cli() {
    if ! command -v ibmcloud &> /dev/null; then
        echo "Error: IBM Cloud CLI is not installed"
        return 1
    fi
    
    if ! ibmcloud target &> /dev/null; then
        echo "Error: Not logged in to IBM Cloud. Please run 'ibmcloud login'"
        return 1
    fi
    
    return 0
}

# Tool: List all resources in the current account
tool_list_resources() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local resource_type=$(echo "$args" | jq -r '.resource_type // "all"')
    local region=$(echo "$args" | jq -r '.region // ""')
    
    local cmd="ibmcloud resource service-instances"
    
    if [[ "$region" != "" && "$region" != "null" ]]; then
        cmd="$cmd --location $region"
    fi
    
    local result=$(eval "$cmd" --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
        echo "Error listing resources: $result"
        return 1
    fi
}

# Tool: Get current target information
tool_get_target() {
    local args="$1"
    
    if ! check_ibmcloud_cli; then
        return 1
    fi
    
    local result=$(ibmcloud target --output json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "$result"
        return 0
    else
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

# Source the core MCP server implementation
source "$(dirname "${BASH_SOURCE[0]}")/mcpserver_core.sh"

# Start the MCP server (this should be called when the script is executed)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_mcp_server "$@"
fi
