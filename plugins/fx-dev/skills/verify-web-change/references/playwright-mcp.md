# Playwright MCP Reference

## Overview

The Playwright MCP server provides browser automation tools for interacting with web applications. It enables navigation, clicking, typing, screenshots, and accessibility snapshots.

## Essential Tools

### Navigation

```
mcp__playwright__browser_navigate
  url: string (required) - The URL to navigate to
```

### Page Snapshot (Preferred over Screenshots)

```
mcp__playwright__browser_snapshot
  filename?: string - Save snapshot to file instead of returning
```

Returns an accessibility tree snapshot with element references (ref) for interaction. **Always prefer snapshots over screenshots** for understanding page state.

### Click

```
mcp__playwright__browser_click
  element: string (required) - Human-readable description
  ref: string (required) - Element reference from snapshot
```

### Type Text

```
mcp__playwright__browser_type
  element: string (required) - Human-readable description
  ref: string (required) - Element reference from snapshot
  text: string (required) - Text to type
  submit?: boolean - Press Enter after typing
```

### Fill Form

```
mcp__playwright__browser_fill_form
  fields: array (required) - Array of {name, type, ref, value}
```

### Wait

```
mcp__playwright__browser_wait_for
  text?: string - Wait for text to appear
  textGone?: string - Wait for text to disappear
  time?: number - Wait for seconds
```

### Screenshot

```
mcp__playwright__browser_take_screenshot
  filename?: string - Save location
  fullPage?: boolean - Capture full page
  type?: "png" | "jpeg"
```

### Tabs

```
mcp__playwright__browser_tabs
  action: "list" | "new" | "close" | "select"
  index?: number - Tab index for close/select
```

### Console Messages

```
mcp__playwright__browser_console_messages
  level?: "error" | "warning" | "info" | "debug"
```

### Network Requests

```
mcp__playwright__browser_network_requests
  includeStatic?: boolean - Include static resources
```

## Workflow Pattern

1. **Navigate** to URL with `browser_navigate`
2. **Snapshot** page with `browser_snapshot` to get element references
3. **Interact** using refs from snapshot (click, type, etc.)
4. **Snapshot again** after interactions to verify state
5. **Repeat** as needed for verification

## Common Patterns

### Verify Element Exists

```
1. browser_snapshot
2. Check snapshot output for expected element text/role
```

### Verify Navigation Works

```
1. browser_navigate to starting page
2. browser_snapshot to find link/button
3. browser_click on target element
4. browser_wait_for expected text on new page
5. browser_snapshot to verify destination
```

### Check for Errors

```
1. browser_console_messages with level="error"
2. Check for JavaScript errors or warnings
```

### Verify Visual Changes

```
1. browser_snapshot before change
2. Perform action
3. browser_snapshot after change
4. Compare snapshots for expected differences
```

## Error Handling

If Playwright MCP is not available:
- Tools will fail with connection or not-found errors
- The skill MUST exit and report the issue
- User needs to install/configure Playwright MCP server

Common fixes:
- Install: `npx @anthropic-ai/mcp-server-playwright`
- Verify MCP server is configured in Claude settings
- Check browser installation: `npx playwright install chromium`
