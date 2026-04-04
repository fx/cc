---
name: verify-web-change
description: Verify web application changes work by launching the app stack and testing in a real browser. This skill should be used when the user asks to "verify the change", "test in browser", "check if it works", or after completing a PR to validate the implementation. Requires Playwright MCP server. MUST exit if Playwright MCP is unavailable.
---

# Verify Web Change

Verify that pull request changes work correctly in a running web application using browser automation.

## Critical Requirements

**Playwright MCP is MANDATORY.** This skill cannot function without it.

## Workflow

Execute these steps in order. Do not skip steps.

### Step 1: Verify Playwright MCP Availability

**MUST exit if this step fails.**

Test Playwright MCP by attempting to list browser tabs:

```
mcp__playwright__browser_tabs
  action: "list"
```

If this tool:
- **Succeeds**: Continue to Step 2
- **Fails with "tool not found"**: EXIT immediately with message:
  ```
  ❌ VERIFICATION FAILED: Playwright MCP server is not installed.

  To install:
  1. Run: npx @anthropic-ai/mcp-server-playwright
  2. Configure in Claude Code MCP settings
  3. Restart Claude Code
  ```
- **Fails with connection error**: EXIT with message about MCP server not running

**Do NOT proceed if Playwright MCP is unavailable.**

### Step 2: Analyze PR Changes

Before launching the application, understand what to verify.

#### 2.1 Get Changed Files

```bash
git diff main --name-only
git diff main --stat
```

#### 2.2 Understand the Changes (ULTRATHINK)

Read the changed files and related context to understand:
- What UI elements were added/modified?
- What user interactions should work?
- What visual changes should be visible?
- Are there related test files that show expected behavior?

```bash
# Check for existing Playwright/E2E tests
find . -name "*.spec.ts" -o -name "*.test.ts" -o -name "*.e2e.ts" | head -20
ls -la tests/ e2e/ playwright/ __tests__/ 2>/dev/null || true
```

If Playwright tests exist, read them to understand:
- What pages/routes are tested
- What elements are interacted with
- What assertions are made

#### 2.3 Define Verification Criteria

Create a mental checklist of what must be verified:
- [ ] Specific UI element(s) present
- [ ] Specific interaction(s) work
- [ ] No console errors
- [ ] Expected visual appearance

### Step 3: Ensure Docker is Running (if needed)

Before launching any services, check if the project needs Docker and ensure the daemon is running.

#### 3.1 Check for Compose Files

```bash
COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    if [[ -f "$f" ]]; then
        COMPOSE_FILE="$f"
        break
    fi
done
echo "Compose file: ${COMPOSE_FILE:-none}"
```

If no compose file is found, skip to Step 4.

#### 3.2 Verify Docker Daemon is Running

```bash
docker info > /dev/null 2>&1
```

If this fails, the Docker daemon is not running. Try to start it:

```bash
# Check current status
service docker status 2>/dev/null || systemctl status docker 2>/dev/null || true
```

If the daemon is stopped, start it:

```bash
# Try without sudo first
service docker start 2>/dev/null \
  || systemctl start docker 2>/dev/null \
  || sudo service docker start 2>/dev/null \
  || sudo systemctl start docker 2>/dev/null
```

**Wait for Docker to be ready after starting:**

```bash
for i in $(seq 1 10); do
    docker info > /dev/null 2>&1 && break
    echo "Waiting for Docker daemon... ($i/10)"
    sleep 2
done

# Final check
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker daemon failed to start. Start it manually and retry."
    echo "   Try: sudo systemctl start docker"
    echo "   Or:  sudo service docker start"
    # Continue without Docker — the app may still work without services
fi
```

#### 3.3 Start Compose Services

```bash
# Prefer `docker compose` (v2 plugin) over `docker-compose` (standalone)
if docker compose version > /dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi
```

**Wait for services to be healthy** — don't just sleep:

```bash
# If compose services define healthchecks, wait for them
if docker compose version > /dev/null 2>&1; then
    # Check if any services have healthchecks
    if docker compose ps --format json 2>/dev/null | grep -q '"Health"'; then
        echo "Waiting for healthy services..."
        for i in $(seq 1 30); do
            UNHEALTHY=$(docker compose ps --format json 2>/dev/null | grep -c '"starting"\|"unhealthy"' || true)
            if [[ "$UNHEALTHY" -eq 0 ]]; then
                echo "All services healthy."
                break
            fi
            echo "  Waiting for $UNHEALTHY service(s)... ($i/30)"
            sleep 2
        done
    else
        # No healthchecks — fall back to a brief wait
        echo "No healthchecks defined. Waiting 5s for services..."
        sleep 5
    fi
fi
```

#### 3.4 Verify Key Services

After compose services start, check that critical ports are actually listening:

```bash
# Common service ports — check whatever the compose file exposes
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker-compose ps
```

If a database or API service failed to start, report it and decide whether to continue.

### Step 4: Launch Application Stack

#### 4.1 Detect Package Manager

```bash
if [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
    PM="bun"
elif [[ -f "pnpm-lock.yaml" ]]; then
    PM="pnpm"
elif [[ -f "yarn.lock" ]]; then
    PM="yarn"
else
    PM="npm"
fi
echo "Package manager: $PM"
```

#### 4.2 Check for Environment Files

Many apps won't start without environment configuration:

```bash
# Check for env templates that need to be copied
for tmpl in .env.example .env.template .env.sample; do
    if [[ -f "$tmpl" ]] && [[ ! -f ".env" ]] && [[ ! -f ".env.local" ]]; then
        echo "⚠️  Found $tmpl but no .env or .env.local — copying $tmpl to .env"
        cp "$tmpl" .env
        break
    fi
done

# Check if required env files exist
if [[ -f ".env.local" ]] || [[ -f ".env" ]] || [[ -f ".env.development" ]]; then
    echo "Environment file found."
else
    echo "⚠️  No .env file detected. App may fail if it requires environment variables."
fi
```

#### 4.3 Install Dependencies (if needed)

```bash
[[ -d "node_modules" ]] || $PM install
```

#### 4.4 Detect Dev Server Port

Detect the port BEFORE starting the server so we know where to navigate:

```bash
PORT=""

# 1. Check vite.config.ts / vite.config.js (most common for bun/vite stacks)
for cfg in vite.config.ts vite.config.js vite.config.mts; do
    if [[ -f "$cfg" ]]; then
        # Look for server.port or preview.port
        VITE_PORT=$(grep -oP 'port\s*:\s*\K\d+' "$cfg" | head -1)
        if [[ -n "$VITE_PORT" ]]; then
            PORT="$VITE_PORT"
            echo "Port $PORT detected from $cfg"
        fi
        break
    fi
done

# 2. Check package.json scripts for --port flags
if [[ -z "$PORT" ]] && [[ -f "package.json" ]]; then
    SCRIPT_PORT=$(grep -oP '"dev"\s*:\s*"[^"]*--port\s+\K\d+' package.json || true)
    if [[ -n "$SCRIPT_PORT" ]]; then
        PORT="$SCRIPT_PORT"
        echo "Port $PORT detected from package.json dev script"
    fi
fi

# 3. Check next.config.js/ts for custom port (rare)
if [[ -z "$PORT" ]]; then
    for cfg in next.config.js next.config.ts next.config.mjs; do
        if [[ -f "$cfg" ]]; then
            PORT="3000"  # Next.js default
            echo "Next.js detected, using default port $PORT"
            break
        fi
    done
fi

# 4. Check nuxt.config.ts
if [[ -z "$PORT" ]] && [[ -f "nuxt.config.ts" ]]; then
    NUXT_PORT=$(grep -oP 'port\s*:\s*\K\d+' nuxt.config.ts | head -1)
    PORT="${NUXT_PORT:-3000}"
    echo "Nuxt detected, using port $PORT"
fi

# 5. Fall back to framework defaults
if [[ -z "$PORT" ]]; then
    if [[ -f "vite.config.ts" ]] || [[ -f "vite.config.js" ]] || [[ -f "vite.config.mts" ]]; then
        PORT="5173"
    elif [[ -f "svelte.config.js" ]]; then
        PORT="5173"
    else
        PORT="3000"
    fi
    echo "Using default port $PORT"
fi

echo "Will verify at: http://localhost:$PORT"
```

#### 4.5 Detect Dev Command

```bash
DEV_CMD="dev"  # default
if [[ -f "package.json" ]]; then
    if grep -q '"dev"' package.json; then
        DEV_CMD="dev"
    elif grep -q '"start"' package.json; then
        DEV_CMD="start"
    elif grep -q '"serve"' package.json; then
        DEV_CMD="serve"
    fi
fi
```

#### 4.6 Start Dev Server with PID Tracking

Start the server in background and capture its PID for reliable cleanup:

```bash
$PM run $DEV_CMD > /tmp/dev-server.log 2>&1 &
DEV_PID=$!
echo "Dev server started (PID: $DEV_PID)"
echo "$DEV_PID" > /tmp/dev-server.pid
```

#### 4.7 Wait for Server to be Ready

**Do NOT use a fixed sleep.** Poll until the server responds:

```bash
echo "Waiting for server at http://localhost:$PORT..."
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT" 2>/dev/null | grep -qE '^[23]'; then
        echo "Server is ready! (attempt $i)"
        break
    fi

    # Check if the process died
    if ! kill -0 "$DEV_PID" 2>/dev/null; then
        echo "❌ Dev server exited unexpectedly. Last output:"
        tail -20 /tmp/dev-server.log
        exit 1
    fi

    echo "  Not ready yet... ($i/30)"
    sleep 2
done

# Final readiness check
if ! curl -s -o /dev/null "http://localhost:$PORT" 2>/dev/null; then
    echo "⚠️  Server may not be ready. Last output:"
    tail -10 /tmp/dev-server.log
    echo "Proceeding anyway — Playwright navigate may trigger lazy startup."
fi
```

### Step 5: Verify Application Loads

#### 5.1 Navigate to Application

```
mcp__playwright__browser_navigate
  url: "http://localhost:$PORT"
```

Use the PORT detected in Step 4.4.

#### 5.2 Take Initial Snapshot

```
mcp__playwright__browser_snapshot
```

#### 5.3 Check for Errors

```
mcp__playwright__browser_console_messages
  level: "error"
```

If critical errors exist, report them and investigate.

#### 5.4 Verify Basic Functionality

Confirm the application loads and shows expected content. If it doesn't load:
- Check dev server logs: `tail -30 /tmp/dev-server.log`
- Check if server process is still running: `kill -0 $(cat /tmp/dev-server.pid) 2>/dev/null && echo "running" || echo "dead"`
- Check console for errors
- Check network requests for failures

### Step 6: Verify Specific Changes

This is the core verification step. Based on the PR changes identified in Step 2:

#### 6.1 Navigate to Affected Area

If the change affects a specific route/page:
```
mcp__playwright__browser_navigate
  url: "http://localhost:$PORT/affected-route"
```

#### 6.2 Snapshot and Verify Elements

```
mcp__playwright__browser_snapshot
```

Check the snapshot for:
- New UI elements mentioned in the PR
- Modified text/labels
- New columns, buttons, or interactive elements

#### 6.3 Test Interactions (if applicable)

For interactive changes, test the interaction:
```
mcp__playwright__browser_click
  element: "description of element"
  ref: "ref-from-snapshot"
```

Then snapshot again to verify the result:
```
mcp__playwright__browser_snapshot
```

#### 6.4 Run Existing Playwright Tests (if available)

If the codebase has Playwright tests covering the changed area, run them against the already-running dev server:

```bash
# Check if Playwright test config exists
if [[ -f "playwright.config.ts" ]] || [[ -f "playwright.config.js" ]]; then
    echo "Running existing Playwright tests..."
    # Point tests at the running dev server
    BASE_URL="http://localhost:$PORT" npx playwright test --reporter=line 2>&1 | tail -30
fi
```

If tests fail, note the failures in the report. If no test suite exists, rely on the manual verification from 6.1-6.3.

### Step 7: Report Results

#### Success Criteria

The ONLY success criteria is: **The actual changes made in the PR are verified to be present and working in the running application.**

#### Success Report

```
✅ VERIFICATION PASSED

Changes Verified:
- [specific change 1]: ✅ Working
- [specific change 2]: ✅ Working
- [specific change N]: ✅ Working

Evidence:
- [what was observed that confirms each change]
```

#### Failure Report

```
❌ VERIFICATION FAILED

Expected: [what should have been observed]
Actual: [what was actually observed]

Details:
- [specific issue 1]
- [specific issue 2]

Console Errors: [if any]
Dev Server Logs: [relevant lines from /tmp/dev-server.log]
```

### Step 8: Cleanup

Stop processes using tracked PIDs — do NOT use greedy pkill patterns:

```bash
# Kill dev server by PID
if [[ -f /tmp/dev-server.pid ]]; then
    DEV_PID=$(cat /tmp/dev-server.pid)
    if kill -0 "$DEV_PID" 2>/dev/null; then
        kill "$DEV_PID" 2>/dev/null || true
        # Wait briefly, then force-kill if still running
        sleep 1
        kill -0 "$DEV_PID" 2>/dev/null && kill -9 "$DEV_PID" 2>/dev/null || true
    fi
    rm -f /tmp/dev-server.pid
fi
rm -f /tmp/dev-server.log

# Stop docker services if we started them
if [[ -n "${COMPOSE_FILE:-}" ]]; then
    if docker compose version > /dev/null 2>&1; then
        docker compose down 2>/dev/null || true
    else
        docker-compose down 2>/dev/null || true
    fi
fi
```

## Reference

For detailed Playwright MCP tool documentation, see: `references/playwright-mcp.md`

## Bundled Scripts

- `scripts/launch-app-stack.sh` - Detect and launch application stack (standalone usage)
- `scripts/check-playwright-mcp.sh` - Verify Playwright MCP availability

## Common Application Ports

| Framework | Default Port | Config File |
|-----------|-------------|-------------|
| Vite | 5173 | `vite.config.ts` |
| Next.js | 3000 | `next.config.js` |
| Create React App | 3000 | — |
| TanStack Start | 3000 | `app.config.ts` |
| Remix | 5173 | `vite.config.ts` |
| Nuxt | 3000 | `nuxt.config.ts` |
| SvelteKit | 5173 | `vite.config.ts` |
| Angular | 4200 | `angular.json` |
| Astro | 4321 | `astro.config.mjs` |

## Troubleshooting

### Docker Daemon Not Running

```bash
# Check status
service docker status 2>/dev/null || systemctl status docker 2>/dev/null

# Start (try without sudo first)
service docker start 2>/dev/null || sudo service docker start
systemctl start docker 2>/dev/null || sudo systemctl start docker

# Verify
docker info > /dev/null 2>&1 && echo "Docker is running"
```

### Docker Compose Services Won't Start

- Check logs: `docker compose logs` or `docker-compose logs`
- Check if ports are in use: `ss -tlnp | grep <port>`
- Check if images need pulling: `docker compose pull`
- Ensure Docker daemon is running first (see above)

### Playwright MCP Not Found
Install the MCP server and configure it in Claude Code settings.

### Application Won't Start
- Check dev server logs: `tail -30 /tmp/dev-server.log`
- Check if ports are already in use: `ss -tlnp | grep $PORT`
- Verify docker services are running: `docker compose ps`
- Check for missing environment variables — look for `.env.example`
- Review startup logs for errors

### Wrong Port Detected
- Check `vite.config.ts` for `server.port`
- Check `package.json` `dev` script for `--port` flag
- Check for `PORT` env var in `.env` files
- Override manually: navigate to the correct URL in Step 5.1

### Element Not Found in Snapshot
- The page may not have fully loaded; use `browser_wait_for`
- The element may be in a different route/page
- The element may require interaction to appear (expand, click, etc.)

### Console Errors Present
- Note errors but distinguish between critical and non-critical
- Pre-existing errors may not be related to the PR changes
- Focus on errors that appeared with the new changes
