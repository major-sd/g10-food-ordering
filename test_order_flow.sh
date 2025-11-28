#!/bin/bash

# Order Flow Test Script
# This script tests the complete order flow from PENDING to CONFIRMED/CANCELLED

echo "=========================================="
echo "Order Flow Test Script"
echo "=========================================="
echo ""

# Configuration
ORDER_SERVICE_URL="http://localhost:8083"
PAYMENT_SERVICE_URL="http://localhost:8084"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if JWT token is provided
if [ -z "$1" ]; then
    print_status "$RED" "❌ Error: JWT token required"
    echo "Usage: $0 <JWT_TOKEN>"
    echo ""
    echo "Example:"
    echo "  $0 eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    echo ""
    echo "To get a JWT token, first register and login:"
    echo "  1. Register: curl -X POST http://localhost:8081/auth/register -H 'Content-Type: application/json' -d '{\"username\":\"testuser\",\"password\":\"password123\",\"email\":\"test@example.com\"}'"
    echo "  2. Login: curl -X POST http://localhost:8081/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"testuser\",\"password\":\"password123\"}'"
    exit 1
fi

JWT_TOKEN=$1

echo "Step 1: Checking service health..."
echo "-----------------------------------"

# Check Order Service
ORDER_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_SERVICE_URL/orders/health")
if [ "$ORDER_HEALTH" == "200" ]; then
    print_status "$GREEN" "✅ Order Service is UP"
else
    print_status "$RED" "❌ Order Service is DOWN (HTTP $ORDER_HEALTH)"
    exit 1
fi

# Check Payment Service
PAYMENT_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$PAYMENT_SERVICE_URL/health")
if [ "$PAYMENT_HEALTH" == "200" ]; then
    print_status "$GREEN" "✅ Payment Service is UP"
else
    print_status "$RED" "❌ Payment Service is DOWN (HTTP $PAYMENT_HEALTH)"
    exit 1
fi

echo ""
echo "Step 2: Creating an order..."
echo "-----------------------------------"

# Create order
ORDER_RESPONSE=$(curl -s -X POST "$ORDER_SERVICE_URL/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "restaurantId": 1,
    "items": [
      {
        "menuItemId": 1,
        "quantity": 2
      }
    ]
  }')

# Extract order ID
ORDER_ID=$(echo $ORDER_RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)
INITIAL_STATUS=$(echo $ORDER_RESPONSE | grep -o '"status":"[A-Z]*"' | grep -o '[A-Z]*')

if [ -z "$ORDER_ID" ]; then
    print_status "$RED" "❌ Failed to create order"
    echo "Response: $ORDER_RESPONSE"
    exit 1
fi

print_status "$GREEN" "✅ Order created successfully"
print_status "$BLUE" "   Order ID: $ORDER_ID"
print_status "$YELLOW" "   Initial Status: $INITIAL_STATUS"

echo ""
echo "Step 3: Waiting for payment processing..."
echo "-----------------------------------"
print_status "$YELLOW" "⏳ Waiting 3 seconds for async payment processing..."
sleep 3

echo ""
echo "Step 4: Checking final order status..."
echo "-----------------------------------"

# Get order status
FINAL_ORDER=$(curl -s -X GET "$ORDER_SERVICE_URL/orders/$ORDER_ID" \
  -H "Authorization: Bearer $JWT_TOKEN")

FINAL_STATUS=$(echo $FINAL_ORDER | grep -o '"status":"[A-Z]*"' | grep -o '[A-Z]*')
AMOUNT=$(echo $FINAL_ORDER | grep -o '"amount":[0-9.]*' | grep -o '[0-9.]*')

if [ "$FINAL_STATUS" == "CONFIRMED" ]; then
    print_status "$GREEN" "✅ Order CONFIRMED - Payment successful!"
    print_status "$BLUE" "   Order ID: $ORDER_ID"
    print_status "$BLUE" "   Amount: \$$AMOUNT"
    print_status "$GREEN" "   Status: $FINAL_STATUS"
    echo ""
    print_status "$GREEN" "🎉 Order flow completed successfully!"
elif [ "$FINAL_STATUS" == "CANCELLED" ]; then
    print_status "$RED" "❌ Order CANCELLED - Payment failed"
    print_status "$BLUE" "   Order ID: $ORDER_ID"
    print_status "$BLUE" "   Amount: \$$AMOUNT"
    print_status "$RED" "   Status: $FINAL_STATUS"
    echo ""
    print_status "$YELLOW" "⚠️  This is expected ~10% of the time (simulated payment failure)"
elif [ "$FINAL_STATUS" == "PENDING" ]; then
    print_status "$RED" "❌ Order still PENDING - Payment processing failed!"
    print_status "$BLUE" "   Order ID: $ORDER_ID"
    print_status "$RED" "   Status: $FINAL_STATUS"
    echo ""
    print_status "$RED" "🔍 Troubleshooting steps:"
    echo "   1. Check if RabbitMQ is running: docker ps | grep rabbitmq"
    echo "   2. Check Order Service logs: docker logs order-service"
    echo "   3. Check Payment Service logs: docker logs payment-service"
    echo "   4. Verify RabbitMQ queues: http://localhost:15672 (guest/guest)"
else
    print_status "$RED" "❌ Unknown status: $FINAL_STATUS"
fi

echo ""
echo "Step 5: Full order details..."
echo "-----------------------------------"
echo "$FINAL_ORDER" | python3 -m json.tool 2>/dev/null || echo "$FINAL_ORDER"

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
