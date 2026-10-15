#!/bin/bash

# Script to automatically connect tktprint containers to the site network
# Run this after starting tktprint containers if they weren't started with the updated docker-compose.yml

echo "Connecting tktprint containers to site_default network..."

# Check if site_default network exists
if ! docker network inspect site_default >/dev/null 2>&1; then
    echo "Error: site_default network not found. Make sure the main site services are running first."
    exit 1
fi

# Connect web container
echo "Connecting tktprint_web to site_default..."
docker network connect site_default tktprint_web 2>/dev/null || echo "tktprint_web already connected or not running"

# Connect worker container  
echo "Connecting tktprint_worker to site_default..."
docker network connect site_default tktprint_worker 2>/dev/null || echo "tktprint_worker already connected or not running"

echo "Network connection complete!"

# Test connectivity
echo "Testing connectivity from stagemgr to tktprint..."
if docker exec site-stagemgr-1 timeout 5 bash -c "</dev/tcp/tktprint_web/3000" 2>/dev/null; then
    echo "✅ Connection successful! Stagemgr can reach tktprint service."
else
    echo "❌ Connection failed. Check container status and network configuration."
fi