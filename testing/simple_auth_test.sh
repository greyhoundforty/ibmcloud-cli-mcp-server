#!/bin/bash
# Simple authentication test to isolate the API key issue

echo "🔍 Simple Authentication Test"
echo "============================"

# Step 1: Check current environment
echo ""
echo "1. Current environment:"
echo "   IBMCLOUD_API_KEY: ${IBMCLOUD_API_KEY:+[SET]} ${IBMCLOUD_API_KEY:-[NOT SET]}"

# Step 2: Load .env file manually
echo ""
echo "2. Loading .env file manually..."
if [[ -f ".env" ]]; then
    echo "   .env file found"
    
    # Show the API key line (masked)
    api_key_line=$(grep "^IBMCLOUD_API_KEY=" .env 2>/dev/null)
    if [[ -n "$api_key_line" ]]; then
        echo "   Found API key line: ${api_key_line:0:20}..."
        
        # Extract and export the API key
        export IBMCLOUD_API_KEY="${api_key_line#*=}"
        
        # Remove quotes if present
        IBMCLOUD_API_KEY="${IBMCLOUD_API_KEY%\"}"
        IBMCLOUD_API_KEY="${IBMCLOUD_API_KEY#\"}"
        IBMCLOUD_API_KEY="${IBMCLOUD_API_KEY%\'}"
        IBMCLOUD_API_KEY="${IBMCLOUD_API_KEY#\'}"
        
        echo "   Extracted API key (${#IBMCLOUD_API_KEY} chars): ${IBMCLOUD_API_KEY:0:8}..."
    else
        echo "   No API key found in .env file"
    fi
else
    echo "   No .env file found"
fi

# Step 3: Test the API key
echo ""
echo "3. Testing API key with IBM Cloud CLI..."
if [[ -n "$IBMCLOUD_API_KEY" ]]; then
    echo "   API key available (${#IBMCLOUD_API_KEY} chars)"
    echo "   Attempting login..."
    
    # Test login command with verbose output
    if ibmcloud login --apikey "$IBMCLOUD_API_KEY" 2>&1; then
        echo "   ✅ Login successful!"
        
        echo ""
        echo "4. Verifying authentication..."
        ibmcloud target
    else
        echo "   ❌ Login failed!"
        
        echo ""
        echo "Troubleshooting:"
        echo "- Check if your API key is correct"
        echo "- Verify IBM Cloud CLI is up to date: ibmcloud update"
        echo "- Try manual login: ibmcloud login --apikey \"your-api-key\""
    fi
else
    echo "   ❌ No API key available"
    echo ""
    echo "Please either:"
    echo "- Set IBMCLOUD_API_KEY environment variable"
    echo "- Create .env file with IBMCLOUD_API_KEY=your-key"
fi

echo ""
echo "Test complete!"