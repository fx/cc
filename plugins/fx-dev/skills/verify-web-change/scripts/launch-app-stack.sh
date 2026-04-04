#!/bin/bash
# Detect and launch application stack for web applications
# Supports: bun, npm, yarn, pnpm with docker/docker-compose for services
#
# Usage: ./launch-app-stack.sh [project_dir]
#
# Outputs:
#   DEV_PID written to /tmp/dev-server.pid
#   Dev server logs written to /tmp/dev-server.log
#   Detected port printed to stdout
#
# Exit codes:
#   0 - Stack launched successfully
#   1 - Failed to launch stack

set -e

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

echo "=== Application Stack Launcher ==="
echo "Project directory: $(pwd)"
echo ""

# --- Docker daemon management ---

ensure_docker_running() {
    if docker info > /dev/null 2>&1; then
        echo "[Docker] Daemon is running."
        return 0
    fi

    echo "[Docker] Daemon is not running. Attempting to start..."

    # Try without sudo first, then with sudo
    if service docker start 2>/dev/null; then
        echo "[Docker] Started via 'service docker start'"
    elif systemctl start docker 2>/dev/null; then
        echo "[Docker] Started via 'systemctl start docker'"
    elif sudo service docker start 2>/dev/null; then
        echo "[Docker] Started via 'sudo service docker start'"
    elif sudo systemctl start docker 2>/dev/null; then
        echo "[Docker] Started via 'sudo systemctl start docker'"
    else
        echo "[Docker] ❌ Failed to start Docker daemon."
        echo "  Try manually: sudo systemctl start docker"
        echo "  Or:           sudo service docker start"
        return 1
    fi

    # Wait for daemon to be ready
    for i in $(seq 1 10); do
        if docker info > /dev/null 2>&1; then
            echo "[Docker] Daemon is ready."
            return 0
        fi
        echo "[Docker] Waiting for daemon... ($i/10)"
        sleep 2
    done

    echo "[Docker] ❌ Daemon started but not responding after 20s."
    return 1
}

# --- Detection functions ---

detect_package_manager() {
    if [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
        echo "bun"
    elif [[ -f "pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "package-lock.json" ]] || [[ -f "package.json" ]]; then
        echo "npm"
    else
        echo ""
    fi
}

detect_dev_command() {
    if [[ -f "package.json" ]]; then
        if grep -q '"dev"' package.json; then
            echo "dev"
        elif grep -q '"start"' package.json; then
            echo "start"
        elif grep -q '"serve"' package.json; then
            echo "serve"
        fi
    fi
}

detect_compose_file() {
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$f" ]]; then
            echo "$f"
            return
        fi
    done
    echo ""
}

detect_port() {
    local port=""

    # 1. Vite config (most common for bun/vite stacks)
    for cfg in vite.config.ts vite.config.js vite.config.mts; do
        if [[ -f "$cfg" ]]; then
            port=$(grep -oP 'port\s*:\s*\K\d+' "$cfg" 2>/dev/null | head -1)
            if [[ -n "$port" ]]; then
                echo "$port"
                return
            fi
        fi
    done

    # 2. package.json dev script --port flag
    if [[ -f "package.json" ]]; then
        port=$(grep -oP '"dev"\s*:\s*"[^"]*--port\s+\K\d+' package.json 2>/dev/null || true)
        if [[ -n "$port" ]]; then
            echo "$port"
            return
        fi
    fi

    # 3. Nuxt config
    if [[ -f "nuxt.config.ts" ]]; then
        port=$(grep -oP 'port\s*:\s*\K\d+' nuxt.config.ts 2>/dev/null | head -1)
        echo "${port:-3000}"
        return
    fi

    # 4. Angular config
    if [[ -f "angular.json" ]]; then
        port=$(grep -oP '"port"\s*:\s*\K\d+' angular.json 2>/dev/null | head -1)
        echo "${port:-4200}"
        return
    fi

    # 5. Astro config
    for cfg in astro.config.mjs astro.config.ts astro.config.js; do
        if [[ -f "$cfg" ]]; then
            port=$(grep -oP 'port\s*:\s*\K\d+' "$cfg" 2>/dev/null | head -1)
            echo "${port:-4321}"
            return
        fi
    done

    # 6. Framework defaults
    if [[ -f "vite.config.ts" ]] || [[ -f "vite.config.js" ]] || [[ -f "vite.config.mts" ]] || [[ -f "svelte.config.js" ]]; then
        echo "5173"
    elif [[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]]; then
        echo "3000"
    else
        echo "3000"
    fi
}

# --- Compose services ---

start_compose_services() {
    local compose_file="$1"

    if [[ -z "$compose_file" ]]; then
        return 0
    fi

    echo "[Compose] Starting services from $compose_file..."

    # Prefer docker compose v2 plugin
    if docker compose version > /dev/null 2>&1; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    # Wait for healthchecks if defined
    if docker compose version > /dev/null 2>&1; then
        if docker compose ps --format json 2>/dev/null | grep -q '"Health"'; then
            echo "[Compose] Waiting for services to be healthy..."
            for i in $(seq 1 30); do
                UNHEALTHY=$(docker compose ps --format json 2>/dev/null | grep -c '"starting"\|"unhealthy"' || true)
                if [[ "$UNHEALTHY" -eq 0 ]]; then
                    echo "[Compose] All services healthy."
                    break
                fi
                echo "[Compose]   Waiting for $UNHEALTHY service(s)... ($i/30)"
                sleep 2
            done
        else
            echo "[Compose] No healthchecks defined. Waiting 5s..."
            sleep 5
        fi
    else
        echo "[Compose] Waiting 5s for services..."
        sleep 5
    fi

    echo "[Compose] Service status:"
    if docker compose version > /dev/null 2>&1; then
        docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
    else
        docker-compose ps
    fi
}

# --- Environment files ---

check_env_files() {
    for tmpl in .env.example .env.template .env.sample; do
        if [[ -f "$tmpl" ]] && [[ ! -f ".env" ]] && [[ ! -f ".env.local" ]]; then
            echo "[Env] Found $tmpl but no .env or .env.local — copying to .env"
            cp "$tmpl" .env
            return
        fi
    done

    if [[ -f ".env.local" ]] || [[ -f ".env" ]] || [[ -f ".env.development" ]]; then
        echo "[Env] Environment file found."
    else
        echo "[Env] ⚠️  No .env file detected. App may fail if it requires environment variables."
    fi
}

# --- Dependencies ---

install_dependencies() {
    local pm="$1"

    if [[ -z "$pm" ]]; then
        echo "[Dependencies] No package manager detected, skipping..."
        return 0
    fi

    if [[ -d "node_modules" ]]; then
        echo "[Dependencies] node_modules exists, skipping install..."
        return 0
    fi

    echo "[Dependencies] Installing with $pm..."
    $pm install
}

# --- Server startup and readiness ---

wait_for_server() {
    local port="$1"
    local pid="$2"
    local max_attempts=30

    echo "[Server] Waiting for http://localhost:$port..."

    for i in $(seq 1 $max_attempts); do
        if curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port" 2>/dev/null | grep -qE '^[23]'; then
            echo "[Server] Ready! (attempt $i)"
            return 0
        fi

        # Check if the process died
        if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
            echo "[Server] ❌ Process exited unexpectedly. Last output:"
            tail -20 /tmp/dev-server.log 2>/dev/null || true
            return 1
        fi

        echo "[Server]   Not ready... ($i/$max_attempts)"
        sleep 2
    done

    echo "[Server] ⚠️  Server may not be ready after ${max_attempts} attempts."
    echo "[Server] Last output:"
    tail -10 /tmp/dev-server.log 2>/dev/null || true
    return 0  # Proceed anyway — Playwright navigate may trigger lazy startup
}

# --- Main execution ---

PACKAGE_MANAGER=$(detect_package_manager)
DEV_COMMAND=$(detect_dev_command)
COMPOSE_FILE=$(detect_compose_file)
PORT=$(detect_port)

echo "Detection results:"
echo "  Package manager: ${PACKAGE_MANAGER:-none}"
echo "  Dev command:     ${DEV_COMMAND:-none}"
echo "  Compose file:    ${COMPOSE_FILE:-none}"
echo "  Port:            ${PORT}"
echo ""

# 1. Docker services (if needed)
if [[ -n "$COMPOSE_FILE" ]]; then
    if ensure_docker_running; then
        start_compose_services "$COMPOSE_FILE"
    else
        echo "[Docker] Continuing without Docker services — app may not fully work."
    fi
fi

# 2. Environment files
check_env_files

# 3. Dependencies
if [[ -n "$PACKAGE_MANAGER" ]]; then
    install_dependencies "$PACKAGE_MANAGER"
fi

# 4. Start dev server
if [[ -n "$PACKAGE_MANAGER" ]] && [[ -n "$DEV_COMMAND" ]]; then
    echo ""
    echo "=== Starting dev server ==="
    echo "Running: $PACKAGE_MANAGER run $DEV_COMMAND"

    $PACKAGE_MANAGER run $DEV_COMMAND > /tmp/dev-server.log 2>&1 &
    DEV_PID=$!
    echo "$DEV_PID" > /tmp/dev-server.pid
    echo "Dev server PID: $DEV_PID"

    wait_for_server "$PORT" "$DEV_PID"

    echo ""
    echo "=== Stack is running ==="
    echo "  URL: http://localhost:$PORT"
    echo "  PID: $DEV_PID (saved to /tmp/dev-server.pid)"
    echo "  Log: /tmp/dev-server.log"
else
    echo ""
    echo "[Warning] Could not detect how to start the application."
    echo "Please start the dev server manually."
    exit 1
fi
