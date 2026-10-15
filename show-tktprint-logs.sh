#!/bin/bash

# Display tktprint docker container logs
# Usage: ./show-tktprint-logs.sh [options]
#
# Options:
#   -f, --follow    Follow log output
#   -n, --tail      Number of lines to show from end (default: 100)
#   -h, --help      Show this help message

# Default values
TAIL_LINES=100
FOLLOW=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        -h|--help)
            echo "Display tktprint docker container logs"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -f, --follow    Follow log output"
            echo "  -n, --tail      Number of lines to show from end (default: 100)"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if docker compose is available (V2 syntax)
if ! docker compose version &> /dev/null; then
    echo "Error: docker compose is not installed or not available"
    exit 1
fi

# Navigate to the script directory (where docker-compose.yml is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in $SCRIPT_DIR"
    exit 1
fi

# Check if the web service exists and is running
if ! docker compose ps --status running | grep -q "web"; then
    echo "Error: 'web' service is not running"
    echo ""
    echo "Available services:"
    docker compose ps
    echo ""
    echo "Start services with: ./start-printer.sh"
    exit 1
fi

# Build the docker compose logs command
if [ "$FOLLOW" = true ]; then
    echo "Following tktprint web container logs (press Ctrl+C to stop)..."
    docker compose logs -f --tail="$TAIL_LINES" web
else
    echo "Showing last $TAIL_LINES lines of tktprint web container logs..."
    docker compose logs --tail="$TAIL_LINES" web
fi