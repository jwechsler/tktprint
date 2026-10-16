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

# address "localhost" prints nothing. In docker, start-printer.sh copies
# config/printer.yml.{test,development,production} into place instead.
if [ ! -f config/printer.yml ]; then
    echo "Creating config/printer.yml from example..."
    cp config/printer.yml.example config/printer.yml
    echo "✓ Created config/printer.yml (address: localhost, nothing is printed)"
fi

echo "=== Configuration complete ==="