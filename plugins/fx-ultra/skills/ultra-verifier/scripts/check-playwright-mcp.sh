#!/bin/bash
# Check whether a Playwright MCP server is configured for this environment.
#
# This is a quick pre-flight gate. A bash script cannot exercise the MCP
# tools directly (those live in Claude's process), so it checks the next-best
# observable signal: is a playwright MCP server declared in any known config?
# Final confirmation is still done by the caller attempting
# mcp__playwright__browser_navigate.
#
# Exit codes:
#   0 - A Playwright MCP server is configured (likely available)
#   1 - No Playwright MCP server found in any known config (gate: treat as missing)

set -e

echo "Checking Playwright MCP availability..."

# Config locations that may declare MCP servers, in precedence order.
CONFIG_PATHS=(
    "$PWD/.mcp.json"
    "$PWD/.claude/settings.json"
    "$PWD/.claude/settings.local.json"
    "$HOME/.claude.json"
    "$HOME/.claude/settings.json"
)

found_config=""
for cfg in "${CONFIG_PATHS[@]}"; do
    [[ -f "$cfg" ]] || continue
    # Match a playwright MCP server key (e.g. "playwright": { ... } under mcpServers).
    if grep -qiE '"[^"]*playwright[^"]*"[[:space:]]*:' "$cfg" 2>/dev/null; then
        found_config="$cfg"
        break
    fi
done

# Optional informational signal: local Playwright binary (MCP may bundle its own).
if command -v npx > /dev/null 2>&1; then
    if npx playwright --version > /dev/null 2>&1; then
        echo "Local Playwright available: $(npx playwright --version 2>/dev/null || echo 'unknown version')"
    fi
fi

if [[ -n "$found_config" ]]; then
    echo "✅ Playwright MCP server declared in: $found_config"
    echo "Confirm responsiveness by calling mcp__playwright__browser_navigate."
    exit 0
fi

echo "❌ No Playwright MCP server found in any known config:"
printf '   - %s\n' "${CONFIG_PATHS[@]}"
echo "Install/configure the Playwright MCP server, or use a headless alternative."
exit 1
