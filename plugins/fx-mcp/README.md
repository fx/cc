# fx-mcp

MCP (Model Context Protocol) server management guidance and best practices for Claude Code.

## Overview

The fx-mcp plugin provides comprehensive guidance for managing MCP servers in Claude Code, covering configuration scopes, transport types, security practices, and common patterns.

## Components

### Skills

- **managing-mcp-servers** - Comprehensive guidance for adding, configuring, and managing MCP servers across different scopes and transport types

## What is MCP?

MCP (Model Context Protocol) is a protocol that extends Claude Code's capabilities by providing additional tools, resources, and prompts through external servers. MCP servers can:

- Add new tools and commands
- Provide access to external resources
- Integrate with APIs and services
- Extend Claude's capabilities

## Skill Description

### managing-mcp-servers

Provides comprehensive guidance for managing MCP servers using the `claude mcp` CLI. The skill covers:

**Configuration Scopes:**
- **project** (`.mcp.json`) - **RECOMMENDED** for team consistency
- **local** (`~/.config/claude/mcp.json`) - Machine-specific config
- **user** (`~/.claude/mcp.json`) - Personal tools only

**Transport Types:**
- **stdio** - Standard input/output (most common, e.g., `npx` commands)
- **sse** - Server-Sent Events over HTTP
- **http** - HTTP-based communication

**Key Features:**
- Command reference for all `claude mcp` commands
- Scope selection guidance (strongly recommends project scope)
- Security best practices
- Common patterns and examples
- Troubleshooting guidance

## Usage

The skill is automatically invoked when you need MCP-related guidance. You can also trigger it by asking questions about MCP servers:

```
"How do I add an MCP server to my project?"
"What's the difference between project and user scope for MCP?"
"How do I add an MCP server with authentication?"
```

## Quick Start

### Adding an MCP Server (Project Scope - Recommended)

```bash
# Add a basic stdio server
claude mcp add --scope project playwright npx @playwright/mcp@latest

# Add with environment variables
claude mcp add --scope project myserver \
  --env API_KEY="${MY_API_KEY}" -- npx my-mcp-server

# Add SSE server with authentication
claude mcp add --transport sse --scope project myapi \
  --header "Authorization: Bearer ${TOKEN}" \
  https://api.example.com/sse
```

### Listing MCP Servers

```bash
claude mcp list
```

Shows all configured servers with health status:
- ✓ Connected
- ⚠ Needs authentication
- ✗ Failed to connect

### Removing an MCP Server

```bash
claude mcp remove <name>
```

## Scope Recommendations

### **Project Scope (RECOMMENDED)** ⭐

**Always prefer project scope unless there's a specific reason not to.**

Benefits:
- ✅ Team consistency - everyone uses the same tools
- ✅ Version controlled - committed to git
- ✅ Self-documenting - `.mcp.json` shows project tools
- ✅ Easy onboarding - automatic for new team members

Use for:
- Project-specific integrations
- Team-shared tools
- Development dependencies
- Testing frameworks
- Documentation servers

### Local Scope

Use only for:
- Machine-specific configurations
- Local development servers
- Testing before adding to project

### User Scope

Use only for:
- Personal productivity tools (unrelated to development)
- **Avoid for development tools** - use project scope instead

## Common Patterns

### Development Environment Setup

```bash
# All in project scope for team consistency
claude mcp add --scope project db-local \
  --env DATABASE_URL=postgresql://localhost:5432/dev -- npx db-mcp

claude mcp add --scope project playwright npx @playwright/mcp@latest

claude mcp add --scope project docs npx @upstash/context7-mcp
```

### Team-Shared Server with Personal Credentials

```bash
# Add to project (committed to git) without secrets
claude mcp add --scope project team-tool \
  --env TOOL_API_KEY=SET_THIS_IN_YOUR_ENV -- npx team-tool-mcp

# Team members set their own credentials
export TOOL_API_KEY=their_personal_key
```

### Multi-Environment Setup

```bash
# All in project scope - different env vars per environment
claude mcp add --scope project api-dev \
  --env API_URL=http://localhost:3000 -- npx api-mcp

claude mcp add --scope project api-staging \
  --env API_URL="${STAGING_API_URL}" -- npx api-mcp

claude mcp add --scope project api-prod \
  --env API_URL="${PROD_API_URL}" -- npx api-mcp
```

## Security Best Practices

### 1. Never Commit Secrets

```bash
# ❌ Wrong - hardcoded secret
claude mcp add --scope project myapi \
  --env API_KEY="secret123" -- npx api-server

# ✅ Correct - use environment variable
claude mcp add --scope project myapi \
  --env API_KEY="${MY_API_KEY}" -- npx api-server
```

### 2. Use Headers for Remote Authentication

```bash
# For SSE/HTTP servers
claude mcp add --transport sse --scope project myapi \
  --header "Authorization: Bearer ${TOKEN}" \
  https://api.example.com/sse
```

### 3. Document Required Environment Variables

In project README.md:
```markdown
## Required Environment Variables

- `MY_API_KEY` - API key for myapi MCP server
- `DATABASE_URL` - Database connection string
```

## Examples

### Example 1: Adding Playwright for Testing

```bash
claude mcp add --scope project playwright npx @playwright/mcp@latest
```

### Example 2: Adding Documentation Server

```bash
claude mcp add --scope project context7 \
  --env UPSTASH_API_KEY="${UPSTASH_API_KEY}" -- npx -y @upstash/context7-mcp
```

### Example 3: Adding Custom API Server

```bash
claude mcp add --transport sse --scope project mycompany \
  --header "X-Api-Key: ${COMPANY_API_KEY}" \
  https://mcp.mycompany.com/sse
```

### Example 4: Adding Database Tools

```bash
claude mcp add --scope project prisma \
  --env DATABASE_URL="${DATABASE_URL}" -- npx prisma-mcp
```

## Troubleshooting

### Server Won't Connect

1. Check if command exists: `which npx`
2. Verify environment variables: `echo $API_KEY`
3. Test transport independently:
   - stdio: Run command manually
   - SSE/HTTP: `curl -N <url>`

### Headers Not Working

Headers only work with SSE/HTTP, not stdio:

```bash
# ❌ Wrong - headers don't work with stdio
claude mcp add myserver --header "X-Key: val" npx server

# ✅ Correct - use env vars for stdio
claude mcp add myserver --env API_KEY=val -- npx server

# ✅ Correct - headers work with SSE/HTTP
claude mcp add --transport sse myserver \
  --header "X-Key: val" https://url
```

### Scope Confusion

```bash
# List all servers to see which scope each is in
claude mcp list

# Get specific server details
claude mcp get <name>

# Remove without specifying scope (auto-detects)
claude mcp remove <name>
```

## Integration with Other Plugins

Works with all plugins as MCP servers extend Claude Code's core capabilities.

## Reference

### Command Quick Reference

| Command | Purpose |
|---------|---------|
| `claude mcp list` | Show all servers and health |
| `claude mcp add` | Add new server |
| `claude mcp remove` | Remove server |
| `claude mcp get` | Show server details |
| `claude mcp serve` | Start Claude Code MCP server |

### Scope Reference

| Scope | Location | Use For |
|-------|----------|---------|
| `project` ⭐ | `.mcp.json` | **DEFAULT**: Team servers (preferred) |
| `local` | `~/.config/claude/mcp.json` | Machine-specific, testing |
| `user` | `~/.claude/mcp.json` | Personal tools only |

### Transport Reference

| Transport | Flag | Use For |
|-----------|------|---------|
| `stdio` | Default | Local commands (npx, node, python) |
| `sse` | `--transport sse` | Server-Sent Events servers |
| `http` | `--transport http` | HTTP API servers |

## Best Practices Summary

1. **Always use project scope by default** - Only deviate with good reason
2. **Never commit secrets** - Use environment variables
3. **Document required env vars** - In project README
4. **Use meaningful names** - `github-prod` not `gh1`
5. **Test before adding to project** - Use local scope for testing
6. **Keep configurations clean** - Remove unused servers regularly

## Contributing

To enhance this plugin:

1. Update `skills/managing-mcp-servers/SKILL.md` with new guidance
2. Add new examples and patterns
3. Update this README
4. Test with real MCP servers

## License

Part of the fx/cc Claude Code marketplace.
