#!/bin/bash

# Complete Order Flow Demo Script
# This script demonstrates the complete order flow from creation to confirmation/cancellation

set -e  # Exit on error

echo "=========================================="
echo "🚀 Order Flow Demo - Complete Simulation"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Step 1: Check Services
print_step "Step 1: Checking Service Health"

services=("order-service:8083" "payment-service:8084" "restaurant-service:8082" "auth-service:8081")
all_up=true

for service in "${services[@]}"; do
    IFS=':' read -r name port <<< "$service"
    if docker ps | grep -q "$name"; then
        print_success "$name is running"
    else
        print_error "$name is NOT running"
        all_up=false
    fi
done

if [ "$all_up" = false ]; then
    print_error "Some services are not running. Please start all services first."
    exit 1
fi

echo ""

# Step 2: Check RabbitMQ
print_step "Step 2: Checking RabbitMQ"

if docker ps | grep -q "rabbitmq"; then
    print_success "RabbitMQ is running"
    
    # Check if RabbitMQ is healthy
    RABBITMQ_STATUS=$(docker inspect rabbitmq --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$RABBITMQ_STATUS" = "healthy" ]; then
        print_success "RabbitMQ is healthy"
    else
        print_warning "RabbitMQ status: $RABBITMQ_STATUS"
    fi
else
    print_error "RabbitMQ is NOT running"
    exit 1
fi

echo ""

# Step 3: Get or Create Test User
print_step "Step 3: Setting Up Test User"

print_info "Attempting to register test user..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo_user","password":"demo123","email":"demo@example.com"}' || echo "")

if [ -n "$REGISTER_RESPONSE" ]; then
    print_success "User registered (or already exists)"
else
    print_info "User might already exist, continuing..."
fi

print_info "Logging in to get JWT token..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo_user","password":"demo123"}' || echo "")

if [ -n "$LOGIN_RESPONSE" ]; then
    JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$JWT_TOKEN" ] && [ "$JWT_TOKEN" != "null" ]; then
        print_success "JWT token obtained successfully"
        print_info "Token: ${JWT_TOKEN:0:50}..."
    else
        print_warning "Could not extract JWT token from response"
        print_warning "Response: $LOGIN_RESPONSE"
        print_warning "Attempting to continue without auth..."
        JWT_TOKEN=""
    fi
else
    print_warning "Login failed, attempting to continue without auth..."
    JWT_TOKEN=""
fi

echo ""

# Step 4: Check Restaurant Data
print_step "Step 4: Verifying Restaurant Data"

RESTAURANTS=$(curl -s http://localhost:8082/restaurants)
RESTAURANT_COUNT=$(echo "$RESTAURANTS" | grep -o '"id"' | wc -l | tr -d ' ')

if [ "$RESTAURANT_COUNT" -gt 0 ]; then
    print_success "Found $RESTAURANT_COUNT restaurants"
    echo "$RESTAURANTS" | python3 -m json.tool 2>/dev/null | head -20
else
    print_error "No restaurants found"
    exit 1
fi

echo ""

# Check menu items
print_info "Checking menu items for restaurant 1..."
MENU_ITEM=$(curl -s http://localhost:8082/restaurants/menu/1)

if echo "$MENU_ITEM" | grep -q '"id"'; then
    print_success "Menu item found"
    echo "$MENU_ITEM" | python3 -m json.tool 2>/dev/null
else
    print_error "No menu items found"
    exit 1
fi

echo ""

# Step 5: Create Order
print_step "Step 5: Creating Order"

print_info "Creating order for restaurant 1, menu item 1, quantity 2..."

if [ -n "$JWT_TOKEN" ]; then
    ORDER_RESPONSE=$(curl -s -X POST http://localhost:8083/orders \
      -H 'Content-Type: application/json' \
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
else
    # Try without auth (might fail due to security)
    ORDER_RESPONSE=$(curl -s -X POST http://localhost:8083/orders \
      -H 'Content-Type: application/json' \
      -d '{
        "userId": 1,
        "restaurantId": 1,
        "items": [
          {
            "menuItemId": 1,
            "quantity": 2
          }
        ]
      }')
fi

# Extract order ID
ORDER_ID=$(echo "$ORDER_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
INITIAL_STATUS=$(echo "$ORDER_RESPONSE" | grep -o '"status":"[A-Z]*"' | grep -o '[A-Z]*')
AMOUNT=$(echo "$ORDER_RESPONSE" | grep -o '"amount":[0-9.]*' | grep -o '[0-9.]*')

if [ -n "$ORDER_ID" ]; then
    print_success "Order created successfully!"
    print_info "Order ID: $ORDER_ID"
    print_info "Initial Status: $INITIAL_STATUS"
    print_info "Amount: ₹$AMOUNT"
    echo ""
    echo "Full Response:"
    echo "$ORDER_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ORDER_RESPONSE"
else
    print_error "Failed to create order"
    echo "Response: $ORDER_RESPONSE"
    exit 1
fi

echo ""

# Step 6: Monitor Logs
print_step "Step 6: Monitoring Payment Processing"

print_info "Watching Order Service logs for payment events..."
echo ""

# Watch logs for 5 seconds
timeout 5 docker logs -f order-service 2>&1 | grep -E "(OrderCreatedEvent|payment result|status updated)" || true

echo ""
print_info "Watching Payment Service logs..."
echo ""

timeout 5 docker logs -f payment-service 2>&1 | grep -E "(Processing payment|Payment processed|Published payment)" || true

echo ""

# Step 7: Wait for Payment Processing
print_step "Step 7: Waiting for Async Payment Processing"

print_info "Payment processing typically takes 0.5-1.5 seconds..."
for i in {3..1}; do
    echo -ne "${YELLOW}⏳ Waiting... $i seconds remaining\r${NC}"
    sleep 1
done
echo -e "${GREEN}⏳ Wait complete!                    ${NC}"

echo ""

# Step 8: Check Final Order Status
print_step "Step 8: Checking Final Order Status"

if [ -n "$JWT_TOKEN" ]; then
    FINAL_ORDER=$(curl -s -X GET "http://localhost:8083/orders/$ORDER_ID" \
      -H "Authorization: Bearer $JWT_TOKEN")
else
    FINAL_ORDER=$(curl -s -X GET "http://localhost:8083/orders/$ORDER_ID")
fi

FINAL_STATUS=$(echo "$FINAL_ORDER" | grep -o '"status":"[A-Z]*"' | grep -o '[A-Z]*')

echo ""
print_info "Order Status Transition:"
echo -e "   ${YELLOW}$INITIAL_STATUS${NC} → ${BLUE}$FINAL_STATUS${NC}"
echo ""

if [ "$FINAL_STATUS" = "CONFIRMED" ]; then
    print_success "🎉 ORDER CONFIRMED - Payment Successful!"
    echo ""
    echo -e "${GREEN}┌─────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│  ✅ Order Flow Completed Successfully │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────┘${NC}"
    echo ""
    print_info "Order Details:"
    echo "$FINAL_ORDER" | python3 -m json.tool 2>/dev/null || echo "$FINAL_ORDER"
    
elif [ "$FINAL_STATUS" = "CANCELLED" ]; then
    print_warning "❌ ORDER CANCELLED - Payment Failed"
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  ⚠️  Payment Failed (Expected ~10%)  │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────┘${NC}"
    echo ""
    print_info "This is expected behavior - payment gateway simulation has 10% failure rate"
    print_info "Order Details:"
    echo "$FINAL_ORDER" | python3 -m json.tool 2>/dev/null || echo "$FINAL_ORDER"
    
elif [ "$FINAL_STATUS" = "PENDING" ]; then
    print_error "🔴 ORDER STILL PENDING - Payment Processing Failed!"
    echo ""
    echo -e "${RED}┌─────────────────────────────────────┐${NC}"
    echo -e "${RED}│  ❌ Order Flow Failed                │${NC}"
    echo -e "${RED}└─────────────────────────────────────┘${NC}"
    echo ""
    print_error "The order is stuck in PENDING state. This indicates a problem!"
    echo ""
    print_info "Troubleshooting Steps:"
    echo "  1. Check RabbitMQ queues: http://localhost:15672 (guest/guest)"
    echo "  2. Verify payment-queue has messages"
    echo "  3. Verify payment-result-queue has messages"
    echo "  4. Check Order Service logs: docker logs order-service"
    echo "  5. Check Payment Service logs: docker logs payment-service"
    echo ""
    print_info "Recent Order Service Logs:"
    docker logs --tail 10 order-service
    echo ""
    print_info "Recent Payment Service Logs:"
    docker logs --tail 10 payment-service
    
else
    print_error "Unknown status: $FINAL_STATUS"
fi

echo ""

# Step 9: Summary
print_step "Step 9: Demo Summary"

echo ""
echo "📊 Test Results:"
echo "  • Order ID: $ORDER_ID"
echo "  • Initial Status: $INITIAL_STATUS"
echo "  • Final Status: $FINAL_STATUS"
echo "  • Amount: ₹$AMOUNT"
echo ""

if [ "$FINAL_STATUS" = "CONFIRMED" ] || [ "$FINAL_STATUS" = "CANCELLED" ]; then
    print_success "✅ Order flow is working correctly!"
    echo ""
    echo "The order successfully transitioned from PENDING to $FINAL_STATUS"
    echo "This demonstrates:"
    echo "  ✓ Event-driven architecture"
    echo "  ✓ Asynchronous payment processing"
    echo "  ✓ RabbitMQ message queue integration"
    echo "  ✓ Saga pattern with compensation (CANCELLED on failure)"
    exit 0
else
    print_error "❌ Order flow has issues - order stuck in PENDING"
    exit 1
fi
