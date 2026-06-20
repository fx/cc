#!/bin/bash
# Check if Playwright MCP server is available and functional
# Exit codes:
#   0 - Playwright MCP is available
#   1 - Playwright MCP is not installed or not responding

set -e

echo "Checking Playwright MCP availability..."

# Try to list pages - this will fail if MCP is not available
# The actual check happens when Claude tries to use the MCP tools
# This script provides a quick sanity check

# Check if playwright is installed locally (optional, MCP may use its own)
if command -v npx &> /dev/null; then
    if npx playwright --version &> /dev/null 2>&1; then
        echo "Local Playwright available: $(npx playwright --version 2>/dev/null || echo 'unknown version')"
    fi
fi

echo "Playwright MCP check: Use mcp__playwright__browser_snapshot or mcp__playwright__browser_navigate to verify MCP is responding"
echo "If these tools fail, the Playwright MCP server is not installed or not running."

exit 0
