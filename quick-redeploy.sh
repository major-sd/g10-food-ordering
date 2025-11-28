#!/bin/bash

# Quick Redeploy Script - Minimal version without prompts
# Usage: ./quick-redeploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES=("auth-service" "restaurant-service" "order-service" "payment-service" "notification-service" "api-gateway")

echo "🚀 Quick Redeploy - Building and deploying all services..."
echo ""

cd "$SCRIPT_DIR"

# Stop containers
echo "📦 Stopping containers..."
docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true

# Build services
echo "🔨 Building services..."
for service in "${SERVICES[@]}"; do
    if [ -d "$service" ]; then
        echo "  Building $service..."
        cd "$service"
        mvn clean package -DskipTests -q
        cd "$SCRIPT_DIR"
    fi
done

# Deploy
echo "🚀 Deploying..."
if command -v docker-compose &> /dev/null; then
    docker-compose up --build -d
else
    docker compose up --build -d
fi

echo ""
echo "✅ Redeploy complete!"
echo "📊 Check status: docker-compose ps"
echo "📋 View logs: docker-compose logs -f"

