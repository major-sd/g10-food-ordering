#!/bin/bash

# API-Only Order Flow Test
# This script tests the order flow using ONLY API endpoints (no DB hacks)

echo "=========================================="
echo "🚀 API-Only Order Flow Test"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Step 1: Check Health
print_step "Step 1: Checking Service Health"

ORDER_HEALTH=$(curl -s http://localhost:8083/orders/health | grep "UP")
PAYMENT_HEALTH=$(curl -s http://localhost:8084/payments/health | grep "UP")

if [ -n "$ORDER_HEALTH" ] && [ -n "$PAYMENT_HEALTH" ]; then
    print_success "Services are UP"
else
    print_error "Services are NOT ready"
    exit 1
fi

echo ""

# Step 2: Create Order via API
print_step "Step 2: Creating Order (POST /orders)"

# Note: userId is normally from token, but with security disabled, 
# we need to ensure the service handles it. 
# Looking at OrderController:
# Long userId = SecurityUtil.getCurrentUserId();
# request.setUserId(userId);
# Since we disabled security, SecurityUtil might return null or throw error.
# Let's hope SecurityUtil handles anonymous users or we might need another fix.

print_info "Sending POST request..."

RESPONSE=$(curl -s -X POST http://localhost:8083/orders \
  -H "Content-Type: application/json" \
  -d '{
    "restaurantId": 1,
    "items": [
      {
        "menuItemId": 1,
        "quantity": 2
      }
    ]
  }')

echo "Response: $RESPONSE"

ORDER_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)

if [ -n "$ORDER_ID" ]; then
    print_success "Order created successfully via API"
    print_info "Order ID: $ORDER_ID"
else
    print_error "Failed to create order"
    # If it failed due to missing userId (NPE), we might need to mock SecurityContext
    exit 1
fi

echo ""

# Step 3: Wait for Processing
print_step "Step 3: Waiting for Payment Processing"

print_info "Waiting 5 seconds..."
for i in {5..1}; do
    echo -ne "${YELLOW}⏳ $i... \r${NC}"
    sleep 1
done
echo ""

# Step 4: Get Order Status via API
print_step "Step 4: Checking Status (GET /orders/$ORDER_ID)"

FINAL_RESPONSE=$(curl -s http://localhost:8083/orders/$ORDER_ID)
STATUS=$(echo $FINAL_RESPONSE | grep -o '"status":"[A-Z]*"' | grep -o '[A-Z]*')

print_info "Final Status: $STATUS"

if [ "$STATUS" == "CONFIRMED" ]; then
    print_success "🎉 Order CONFIRMED via API flow!"
    exit 0
elif [ "$STATUS" == "CANCELLED" ]; then
    print_success "⚠️  Order CANCELLED (Payment Failed) via API flow!"
    exit 0
else
    print_error "Order status is $STATUS (Expected CONFIRMED or CANCELLED)"
    exit 1
fi
