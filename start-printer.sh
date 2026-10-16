#!/bin/bash

# Start tktprint services
# This script stops any running tktprint services and starts them fresh
#
# Usage: ./start-printer.sh [options]
#
# Options:
#   -d, --detached     Run services in background (default)
#   -f, --foreground   Run services in foreground
#   -h, --help         Show this help message
#
# Where tickets print comes from this machine's config/printer.yml, by RAILS_ENV
# (see config/printer.yml.example). When that address is "boca_printer", the
# virtual Boca printer starts too and tickets render to PDFs in tmp/printed_tickets/.

# Default values
DETACHED=true
PRINTER_CONFIG_FILE="config/printer.yml"
VIRTUAL_PRINTER_ADDRESS="boca_printer"

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
            # Modes are gone; keep old commands (start-printer.sh -m live) working
            echo "Note: -m $2 is ignored; the printer comes from $PRINTER_CONFIG_FILE by RAILS_ENV."
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
            echo "  -h, --help          Show this help message"
            echo ""
            echo "The printer comes from $PRINTER_CONFIG_FILE for the current RAILS_ENV."
            echo "If its address is \"$VIRTUAL_PRINTER_ADDRESS\", the virtual Boca printer starts as well."
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

# Printer address for RAILS_ENV, read the way config/application.rb does: the RAILS_ENV
# section, else the production section, else a flat file's ticket_printer_1
printer_address() {
    local section
    for section in "$RAILS_ENV" production ""; do
        local address
        address=$(awk -v want="$section" '
            /^[^[:space:]#][^:]*:/ { current = $1; sub(/:$/, "", current) }
            (want == "" || current == want) && $1 == "address:" {
                gsub(/["\047]/, "", $2); print $2; exit
            }' "$PRINTER_CONFIG_FILE")
        if [ -n "$address" ]; then
            echo "$address"
            return
        fi
    done
}

if [ ! -f "$PRINTER_CONFIG_FILE" ]; then
    echo "No $PRINTER_CONFIG_FILE yet: creating it from config/printer.yml.example."
    echo "Edit it to set this machine's printer (development prints PDFs by default)."
    cp config/printer.yml.example "$PRINTER_CONFIG_FILE"
fi

PRINTER_ADDRESS=$(printer_address)
if [ -z "$PRINTER_ADDRESS" ]; then
    echo "Error: no printer address for RAILS_ENV=$RAILS_ENV in $PRINTER_CONFIG_FILE"
    exit 1
fi

echo "=== TKTprint Service Startup ==="
echo "Working directory: $SCRIPT_DIR"
echo "Rails environment: $RAILS_ENV"
echo "Printer: $PRINTER_ADDRESS (from $PRINTER_CONFIG_FILE)"
echo ""

# Keep SECRET_KEY_BASE across runs; generate one on first start
SECRET_KEY_BASE=$(grep -s '^SECRET_KEY_BASE=' .env | cut -d= -f2-)
SECRET_KEY_BASE=${SECRET_KEY_BASE:-$(openssl rand -hex 64)}

# Keep virtual printer settings across runs unless set in the shell
BOCA_FONT_DIR=${BOCA_FONT_DIR:-$(grep -s '^BOCA_FONT_DIR=' .env | cut -d= -f2-)}
FGL_PDF_REF=${FGL_PDF_REF:-$(grep -s '^FGL_PDF_REF=' .env | cut -d= -f2-)}

# Create .env file for docker-compose to read
cat > .env << EOF
RAILS_ENV=$RAILS_ENV
SECRET_KEY_BASE=$SECRET_KEY_BASE
HOST_UID=$(id -u)
HOST_GID=$(id -g)
EOF
[ -n "$BOCA_FONT_DIR" ] && echo "BOCA_FONT_DIR=$BOCA_FONT_DIR" >> .env
[ -n "$FGL_PDF_REF" ] && echo "FGL_PDF_REF=$FGL_PDF_REF" >> .env

# Stop any running tktprint services (including orphaned containers)
echo "Stopping existing tktprint services..."
docker compose down --remove-orphans

# Also stop any containers from the main site that might still be running
echo "Stopping any conflicting containers..."
docker stop tktprint_web tktprint_worker tktprint_printer tktprint_db_setup 2>/dev/null || true
docker rm tktprint_web tktprint_worker tktprint_printer tktprint_db_setup 2>/dev/null || true

echo ""

# Start services, with the virtual printer only when this machine prints to it
if [ "$PRINTER_ADDRESS" = "$VIRTUAL_PRINTER_ADDRESS" ]; then
    export COMPOSE_PROFILES=virtual-printer
    mkdir -p tmp/printed_tickets tmp/fonts
    echo "Starting services with virtual Boca printer (PDFs in tmp/printed_tickets/)..."
else
    export COMPOSE_PROFILES=""
    echo "Starting services for the printer at $PRINTER_ADDRESS (no virtual printer)..."
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
    if [ "$PRINTER_ADDRESS" = "$VIRTUAL_PRINTER_ADDRESS" ]; then
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