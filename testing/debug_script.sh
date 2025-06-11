#!/bin/bash
# Debug script for IBM Cloud MCP Server

set -e

echo "🔍 IBM Cloud MCP Server Debug Tool"
echo "=================================="

# Enable debug mode
export MCP_DEBUG=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run a debug test
debug_test() {
    local test_name="$1"
    local json_request="$2"
    
    echo ""
    echo -e "${BLUE}🧪 Testing: $test_name${NC}"
    echo "Request: $json_request"
    echo ""
    echo -e "${YELLOW}--- Output ---${NC}"
    
    # Run the test and capture both stdout and stderr
    local output
    local exit_code
    
    output=$(echo "$json_request" | ./ibmcloud_mcp_server.sh 2>&1)
    exit_code=$?
    
    echo "$output"
    echo ""
    echo -e "${YELLOW}--- End Output ---${NC}"
    echo "Exit code: $exit_code"
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ Test passed${NC}"
    else
        echo -e "${RED}❌ Test failed${NC}"
    fi
    
    echo ""
    echo "----------------------------------------"
}

# Function to check prerequisites
check_prereqs() {
    echo -e "${BLUE}🔍 Checking Prerequisites${NC}"
    echo ""
    
    # Check if the MCP server script exists
    if [[ ! -f "./ibmcloud_mcp_server.sh" ]]; then
        echo -e "${RED}❌ ibmcloud_mcp_server.sh not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ ibmcloud_mcp_server.sh found${NC}"
    
    # Check if it's executable
    if [[ ! -x "./ibmcloud_mcp_server.sh" ]]; then
        echo -e "${YELLOW}⚠️  Making ibmcloud_mcp_server.sh executable${NC}"
        chmod +x ./ibmcloud_mcp_server.sh
    fi
    echo -e "${GREEN}✅ ibmcloud_mcp_server.sh is executable${NC}"
    
    # Check for mcpserver_core.sh
    if [[ ! -f "./mcpserver_core.sh" ]]; then
        echo -e "${RED}❌ mcpserver_core.sh not found${NC}"
        echo "Please ensure you have the core MCP server file from:"
        echo "https://github.com/muthuishere/mcp-server-bash-sdk"
        exit 1
    fi
    echo -e "${GREEN}✅ mcpserver_core.sh found${NC}"
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ jq is installed${NC}"
    
    # Check for IBM Cloud CLI
    if ! command -v ibmcloud &> /dev/null; then
        echo -e "${RED}❌ IBM Cloud CLI is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ IBM Cloud CLI is installed${NC}"
    
    # Check IBM Cloud CLI version
    local cli_version=$(ibmcloud version 2>/dev/null | head -1)
    echo "IBM Cloud CLI version: $cli_version"
    
    # Check authentication
    echo ""
    echo -e "${BLUE}🔐 Checking Authentication${NC}"
    if ibmcloud target &> /dev/null; then
        echo -e "${GREEN}✅ Authenticated with IBM Cloud${NC}"
        echo "Current target:"
        ibmcloud target
    else
        echo -e "${YELLOW}⚠️  Not authenticated with IBM Cloud${NC}"
        
        # Check for API key
        if [[ -n "$IBMCLOUD_API_KEY" ]]; then
            echo "Found IBMCLOUD_API_KEY environment variable"
        elif [[ -f ".env" ]]; then
            echo "Found .env file"
            if grep -q "IBMCLOUD_API_KEY" .env; then
                echo "IBMCLOUD_API_KEY found in .env file"
            fi
        else
            echo "No API key found. You may need to:"
            echo "  1. Run 'ibmcloud login'"
            echo "  2. Set IBMCLOUD_API_KEY environment variable"
            echo "  3. Create a .env file with IBMCLOUD_API_KEY"
        fi
    fi
    
    echo ""
    echo "----------------------------------------"
}

# Function to show environment info
show_environment() {
    echo -e "${BLUE}🌍 Environment Information${NC}"
    echo ""
    
    echo "Working directory: $(pwd)"
    echo "Script location: $(realpath ./ibmcloud_mcp_server.sh 2>/dev/null || echo 'N/A')"
    echo "PATH: $PATH"
    echo ""
    
    echo "Environment variables:"
    echo "  IBMCLOUD_API_KEY: ${IBMCLOUD_API_KEY:+[SET]} ${IBMCLOUD_API_KEY:-[NOT SET]}"
    echo "  IBMCLOUD_REGION: ${IBMCLOUD_REGION:-[NOT SET]}"
    echo "  IBMCLOUD_RESOURCE_GROUP: ${IBMCLOUD_RESOURCE_GROUP:-[NOT SET]}"
    echo "  IBMCLOUD_HOME: ${IBMCLOUD_HOME:-[NOT SET]}"
    echo "  MCP_DEBUG: ${MCP_DEBUG:-[NOT SET]}"
    echo ""
    
    echo "Configuration files:"
    echo "  .env: $([ -f .env ] && echo 'EXISTS' || echo 'NOT FOUND')"
    echo "  assets/ibmcloud_config.json: $([ -f assets/ibmcloud_config.json ] && echo 'EXISTS' || echo 'NOT FOUND')"
    echo "  assets/ibmcloud_tools.json: $([ -f assets/ibmcloud_tools.json ] && echo 'EXISTS' || echo 'NOT FOUND')"
    echo ""
    
    echo "Log files:"
    echo "  logs/ibmcloud.log: $([ -f logs/ibmcloud.log ] && echo 'EXISTS' || echo 'NOT FOUND')"
    echo ""
    
    echo "----------------------------------------"
}

# Function to show recent logs
show_logs() {
    echo -e "${BLUE}📋 Recent Log Entries${NC}"
    echo ""
    
    if [[ -f "logs/ibmcloud.log" ]]; then
        echo "Last 20 lines from logs/ibmcloud.log:"
        echo ""
        tail -20 logs/ibmcloud.log
    else
        echo "No log file found at logs/ibmcloud.log"
    fi
    
    echo ""
    echo "----------------------------------------"
}

# Main debug menu
main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}🔍 Debug Menu${NC}"
        echo "1) Check prerequisites"
        echo "2) Show environment information"
        echo "3) Test authentication (detailed)"
        echo "4) Test MCP server initialization"
        echo "5) Test tools/list"
        echo "6) Test get_target tool"
        echo "7) Show recent logs"
        echo "8) Run custom test"
        echo "9) Continuous monitoring"
        echo "10) Exit"
        echo ""
        read -p "Select an option (1-10): " choice
        
        case $choice in
            1)
                check_prereqs
                ;;
            2)
                show_environment
                ;;
            3)
                echo ""
                echo -e "${BLUE}🔐 Running detailed authentication test${NC}"
                if [[ -f "./auth_test.sh" ]]; then
                    chmod +x ./auth_test.sh
                    ./auth_test.sh
                else
                    echo -e "${YELLOW}auth_test.sh not found, running basic authentication check${NC}"
                    
                    echo "Environment variables:"
                    echo "  IBMCLOUD_API_KEY: ${IBMCLOUD_API_KEY:+[SET - ${#IBMCLOUD_API_KEY} chars]} ${IBMCLOUD_API_KEY:-[NOT SET]}"
                    
                    if [[ -f ".env" ]]; then
                        echo ""
                        echo ".env file contents:"
                        grep -v "^#" .env | grep -v "^$" | while read line; do
                            var_name="${line%%=*}"
                            if [[ "$var_name" == "IBMCLOUD_API_KEY" ]]; then
                                echo "  $var_name=[REDACTED]"
                            else
                                echo "  $line"
                            fi
                        done
                    fi
                    
                    echo ""
                    echo "Testing IBM Cloud authentication:"
                    if ibmcloud target; then
                        echo -e "${GREEN}✅ Currently authenticated${NC}"
                    else
                        echo -e "${RED}❌ Not authenticated${NC}"
                        
                        if [[ -n "$IBMCLOUD_API_KEY" ]]; then
                            echo "Attempting login with API key..."
                            if ibmcloud login --apikey "$IBMCLOUD_API_KEY"; then
                                echo -e "${GREEN}✅ Login successful${NC}"
                            else
                                echo -e "${RED}❌ Login failed${NC}"
                            fi
                        fi
                    fi
                fi
                ;;
            4)
                debug_test "MCP Server Initialization" '{"jsonrpc": "2.0", "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "debug-client", "version": "1.0.0"}}, "id": 1}'
                ;;
            5)
                debug_test "List Tools" '{"jsonrpc": "2.0", "method": "tools/list", "id": 2}'
                ;;
            6)
                debug_test "Get Target Tool" '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "get_target"}, "id": 3}'
                ;;
            7)
                show_logs
                ;;
            8)
                echo ""
                read -p "Enter JSON request: " custom_request
                debug_test "Custom Test" "$custom_request"
                ;;
            9)
                echo ""
                echo -e "${YELLOW}🔄 Starting continuous monitoring (Ctrl+C to stop)${NC}"
                echo "This will monitor the MCP server process and logs in real-time"
                echo ""
                
                # Start the MCP server in background and monitor it
                echo '{"jsonrpc": "2.0", "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "debug-client", "version": "1.0.0"}}, "id": 1}' | ./ibmcloud_mcp_server.sh &
                local pid=$!
                
                echo "Started MCP server with PID: $pid"
                
                # Monitor the process
                while kill -0 $pid 2>/dev/null; do
                    echo -n "."
                    sleep 1
                done
                
                echo ""
                echo "MCP server process ended"
                ;;
            10)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
    done
}

# Run initial checks
check_prereqs
show_environment

# Start the main menu
main_menu