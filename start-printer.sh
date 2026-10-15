#!/bin/bash

# Start tktprint services
# This script stops any running tktprint services and starts them fresh
#
# Usage: ./start-printer.sh [options]
#
# Options:
#   -d, --detached     Run services in background (default)
#   -f, --foreground   Run services in foreground
#   -m, --mode MODE    Set printer mode: "live" or "test" (default based on RAILS_ENV)
#   -h, --help         Show this help message

# Default values
DETACHED=true
MODE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--detached)
            DETACHED=true
            shift
            ;;
        -f|--foreground)
            DETACHED=false
            shift
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Start tktprint services"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "This script stops any running tktprint services and starts them fresh."
            echo ""
            echo "Options:"
            echo "  -d, --detached      Run services in background (default)"
            echo "  -f, --foreground    Run services in foreground"
            echo "  -m, --mode MODE     Set printer mode: 'live' or 'test'"
            echo "                      Default: 'live' if RAILS_ENV=production, otherwise 'test'"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Set RAILS_ENV if not already set (defaults to development)
if [ -z "$RAILS_ENV" ]; then
    export RAILS_ENV="development"
fi

# Determine default mode based on RAILS_ENV if not specified
if [ -z "$MODE" ]; then
    if [ "$RAILS_ENV" = "production" ]; then
        MODE="live"
    else
        MODE="test"
    fi
fi

# Validate mode
if [ "$MODE" != "live" ] && [ "$MODE" != "test" ]; then
    echo "Error: Invalid mode '$MODE'. Must be 'live' or 'test'"
    exit 1
fi

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

# Setup printer configuration based on mode
echo "=== TKTprint Service Startup ==="
echo "Working directory: $SCRIPT_DIR"
echo "Rails environment: $RAILS_ENV"
echo "Printer mode: $MODE"
echo ""

# Export environment variables for docker-compose
export PRINTER_CONFIG="$MODE"

# Keep SECRET_KEY_BASE across runs; generate one on first start
SECRET_KEY_BASE=$(grep -s '^SECRET_KEY_BASE=' .env | cut -d= -f2-)
SECRET_KEY_BASE=${SECRET_KEY_BASE:-$(openssl rand -hex 64)}

# Keep virtual printer settings across runs unless set in the shell
BOCA_FONT_DIR=${BOCA_FONT_DIR:-$(grep -s '^BOCA_FONT_DIR=' .env | cut -d= -f2-)}
FGL_PDF_REF=${FGL_PDF_REF:-$(grep -s '^FGL_PDF_REF=' .env | cut -d= -f2-)}

# Create .env file for docker-compose to read
cat > .env << EOF
RAILS_ENV=$RAILS_ENV
PRINTER_CONFIG=$PRINTER_CONFIG
SECRET_KEY_BASE=$SECRET_KEY_BASE
HOST_UID=$(id -u)
HOST_GID=$(id -g)
EOF
[ -n "$BOCA_FONT_DIR" ] && echo "BOCA_FONT_DIR=$BOCA_FONT_DIR" >> .env
[ -n "$FGL_PDF_REF" ] && echo "FGL_PDF_REF=$FGL_PDF_REF" >> .env

# Copy the appropriate printer configuration
PRINTER_SOURCE="config/printer.yml.$MODE"
PRINTER_DEST="config/printer.yml"

if [ ! -f "$PRINTER_SOURCE" ]; then
    echo "Error: Printer configuration file not found: $PRINTER_SOURCE"
    exit 1
fi

echo "Copying printer configuration from $PRINTER_SOURCE to $PRINTER_DEST..."
cp "$PRINTER_SOURCE" "$PRINTER_DEST"

echo ""

# Stop any running tktprint services (including orphaned containers)
echo "Stopping existing tktprint services..."
docker compose down --remove-orphans

# Also stop any containers from the main site that might still be running
echo "Stopping any conflicting containers..."
docker stop tktprint_web tktprint_worker tktprint_printer tktprint_db_setup 2>/dev/null || true
docker rm tktprint_web tktprint_worker tktprint_printer tktprint_db_setup 2>/dev/null || true

echo ""

# Start services
# Set COMPOSE_PROFILES based on mode
if [ "$MODE" = "test" ]; then
    export COMPOSE_PROFILES=test
    mkdir -p tmp/printed_tickets tmp/fonts
    echo "Starting services with virtual Boca printer (PDFs in tmp/printed_tickets/)..."
else
    export COMPOSE_PROFILES=""
    echo "Starting services for live printer (no emulator)..."
fi

# Temporarily rename override file if in production mode
OVERRIDE_RENAMED=false
if [ "$RAILS_ENV" = "production" ] && [ -f "docker-compose.override.yml" ]; then
    echo "Temporarily disabling docker-compose.override.yml for production..."
    mv docker-compose.override.yml docker-compose.override.yml.disabled
    OVERRIDE_RENAMED=true
fi

if [ "$DETACHED" = true ]; then
    echo "Starting tktprint services in background..."
    docker compose up -d --build
    UP_STATUS=$?

    # Restore override file if it was renamed
    if [ "$OVERRIDE_RENAMED" = true ]; then
        mv docker-compose.override.yml.disabled docker-compose.override.yml
    fi

    if [ $UP_STATUS -ne 0 ]; then
        echo ""
        echo "Error: docker compose up failed (exit $UP_STATUS)"
        exit $UP_STATUS
    fi

    echo ""
    echo "Services started successfully!"
    echo ""
    echo "Available services:"
    docker compose ps --services

    echo ""
    echo "Container status:"
    docker compose ps

    echo ""
    echo "To view logs, use:"
    echo "  ./show-tktprint-logs.sh -f     # Follow web logs"
    echo "  docker compose logs -f worker  # Follow worker logs"
    if [ "$MODE" = "test" ]; then
        echo "  docker compose logs -f boca_printer  # Follow virtual printer logs"
        echo "  ls tmp/printed_tickets/              # Printed tickets as PDFs"
    fi
    echo ""
    echo "To stop services, use:"
    echo "  docker compose down"
else
    echo "Starting tktprint services in foreground (Ctrl+C to stop)..."
    docker compose up --build

    # Restore override file if it was renamed
    if [ "$OVERRIDE_RENAMED" = true ]; then
        mv docker-compose.override.yml.disabled docker-compose.override.yml
    fi
fi