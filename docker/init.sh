#!/bin/bash
set -e

echo "=== TKTPrint Docker Initialization ==="

# Create config files from examples if they don't exist
if [ ! -f config/authorization.yml ]; then
    echo "Creating config/authorization.yml from example..."
    cat > config/authorization.yml << EOF
development:
  username: "dev_user"
  password: "dev_password"

test:
  username: "test_user"
  password: "test_password"

production:
  username: "prod_user"
  password: "prod_password"
EOF
    echo "✓ Created config/authorization.yml with default credentials"
    echo "  WARNING: Change these credentials before production use!"
fi

if [ ! -f config/printer.yml ]; then
    echo "Creating config/printer.yml from example..."
    cat > config/printer.yml << EOF
# Printer configuration for Docker development environment
development:
  ticket_printer_1:
    # Use the printer_emulator service name for Docker networking
    address: "printer_emulator"
    port: 9100

test:
  ticket_printer_1:
    address: "localhost"
    port: 9100

production:
  ticket_printer_1:
    address: "192.168.1.100"  # Replace with actual printer IP
    port: 9100
EOF
    echo "✓ Created config/printer.yml for Docker environment"
fi

echo "=== Configuration complete ==="