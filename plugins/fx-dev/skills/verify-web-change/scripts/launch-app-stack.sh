#!/bin/bash
# Detect and launch application stack for web applications
# Supports: bun, npm, yarn, pnpm with docker/docker-compose for services
#
# Usage: ./launch-app-stack.sh [project_dir]
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

# Detect package manager
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

# Detect dev command from package.json
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

# Detect docker requirements
detect_docker() {
    if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        echo "docker-compose"
    elif [[ -f "compose.yml" ]] || [[ -f "compose.yaml" ]]; then
        echo "compose"
    else
        echo ""
    fi
}

# Start docker services if needed
start_docker_services() {
    local docker_type="$1"

    if [[ -z "$docker_type" ]]; then
        echo "[Docker] No docker-compose file found, skipping..."
        return 0
    fi

    echo "[Docker] Starting services with $docker_type..."

    if [[ "$docker_type" == "docker-compose" ]]; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    echo "[Docker] Services started. Waiting 5s for initialization..."
    sleep 5
}

# Install dependencies if needed
install_dependencies() {
    local pm="$1"

    if [[ -z "$pm" ]]; then
        echo "[Dependencies] No package manager detected, skipping..."
        return 0
    fi

    # Check if node_modules exists
    if [[ -d "node_modules" ]]; then
        echo "[Dependencies] node_modules exists, skipping install..."
        return 0
    fi

    echo "[Dependencies] Installing with $pm..."

    case "$pm" in
        bun)
            bun install
            ;;
        pnpm)
            pnpm install
            ;;
        yarn)
            yarn install
            ;;
        npm)
            npm install
            ;;
    esac
}

# Main execution
PACKAGE_MANAGER=$(detect_package_manager)
DEV_COMMAND=$(detect_dev_command)
DOCKER_TYPE=$(detect_docker)

echo "Detection results:"
echo "  Package manager: ${PACKAGE_MANAGER:-none}"
echo "  Dev command: ${DEV_COMMAND:-none}"
echo "  Docker: ${DOCKER_TYPE:-none}"
echo ""

# Start docker services first
if [[ -n "$DOCKER_TYPE" ]]; then
    start_docker_services "$DOCKER_TYPE"
fi

# Install dependencies
if [[ -n "$PACKAGE_MANAGER" ]]; then
    install_dependencies "$PACKAGE_MANAGER"
fi

# Report how to start the dev server
if [[ -n "$PACKAGE_MANAGER" ]] && [[ -n "$DEV_COMMAND" ]]; then
    echo ""
    echo "=== Ready to start dev server ==="
    echo "Run: $PACKAGE_MANAGER run $DEV_COMMAND"
    echo ""
    echo "Note: Start the dev server in background mode to continue verification:"
    echo "  $PACKAGE_MANAGER run $DEV_COMMAND &"
else
    echo ""
    echo "[Warning] Could not detect how to start the application."
    echo "Please start the dev server manually."
fi
