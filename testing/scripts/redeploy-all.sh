#!/bin/bash

echo "🚀 Redeploying All Services"
echo "============================"
echo ""

# Array of services to redeploy
services=("catalog" "delivery" "order" "payment" "user")

# Redeploy each service
for service in "${services[@]}"; do
    echo "📦 Redeploying $service service..."
    ./redeploy-$service.sh
    
    if [ $? -eq 0 ]; then
        echo "✅ $service service redeployed successfully"
    else
        echo "❌ Failed to redeploy $service service"
        exit 1
    fi
    echo ""
done

echo "🎉 All services redeployed successfully!"
echo ""
echo "Waiting 10 seconds for services to stabilize..."
sleep 10

echo ""
echo "📊 Service Status:"
echo "=================="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep food-ordering

echo ""
echo "✅ Deployment complete! Services are ready for testing."
