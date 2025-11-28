#!/bin/bash

# Simple Order Flow Test - Using RabbitMQ HTTP API
# This script creates an order and publishes event via RabbitMQ Management API

echo "=========================================="
echo "🧪 Order Flow Test (RabbitMQ HTTP API)"
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

# Step 1: Create order in database
print_step "Step 1: Creating Order in Database"

ORDER_SQL="INSERT INTO orders (user_id, restaurant_id, amount, status, created_at) VALUES (1, 1, 500.00, 'PENDING', NOW());"
docker exec mysql_order mysql -uadmin -ppassword -e "USE order_db; $ORDER_SQL" 2>/dev/null

ORDER_ID=$(docker exec mysql_order mysql -uadmin -ppassword -e "USE order_db; SELECT id FROM orders ORDER BY id DESC LIMIT 1;" 2>/dev/null | tail -1)

print_success "Order created: ID=$ORDER_ID, Status=PENDING, Amount=₹500"
echo ""

# Step 2: Publish event via RabbitMQ Management API
print_step "Step 2: Publishing OrderCreatedEvent"

# Create JSON payload
PAYLOAD=$(cat <<EOF
{
  "properties": {
    "content_type": "application/json"
  },
  "routing_key": "order.created",
  "payload": "{\"orderId\":$ORDER_ID,\"userId\":1,\"restaurantId\":1,\"amount\":500.0}",
  "payload_encoding": "string"
}
EOF
)

# Publish to RabbitMQ
RESPONSE=$(curl -s -u guest:guest -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  http://localhost:15672/api/exchanges/%2F/orders-exchange/publish)

if echo "$RESPONSE" | grep -q "routed.*true"; then
    print_success "Event published successfully to orders-exchange"
else
    print_error "Failed to publish event"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""

# Step 3: Monitor logs
print_step "Step 3: Monitoring Payment Processing"

print_info "Watching logs for 6 seconds..."
echo ""

# Monitor payment service
echo -e "${YELLOW}=== Payment Service ===${NC}"
timeout 3 docker logs -f payment-service 2>&1 | grep --line-buffered -E "Processing payment for order: $ORDER_ID|Payment processed for order $ORDER_ID" || echo "(waiting...)"

echo ""

# Monitor order service  
echo -e "${YELLOW}=== Order Service ===${NC}"
timeout 3 docker logs -f order-service 2>&1 | grep --line-buffered -E "Received payment result for order $ORDER_ID|Order $ORDER_ID status updated" || echo "(waiting...)"

echo ""

# Step 4: Wait
print_step "Step 4: Waiting for Processing"

for i in {4..1}; do
    echo -ne "${YELLOW}⏳ Waiting $i seconds...\r${NC}"
    sleep 1
done
echo -e "${GREEN}⏳ Complete!                    ${NC}"

echo ""

# Step 5: Check result
print_step "Step 5: Checking Final Status"

FINAL_STATUS=$(docker exec mysql_order mysql -uadmin -ppassword -e "USE order_db; SELECT status FROM orders WHERE id=$ORDER_ID;" 2>/dev/null | tail -1)

echo ""
echo -e "Status Transition: ${YELLOW}PENDING${NC} → ${BLUE}$FINAL_STATUS${NC}"
echo ""

if [ "$FINAL_STATUS" = "CONFIRMED" ]; then
    print_success "🎉 ORDER CONFIRMED!"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Order Flow Works Perfectly!       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    print_info "The fix is working! Order transitioned from PENDING to CONFIRMED."
    exit 0
    
elif [ "$FINAL_STATUS" = "CANCELLED" ]; then
    print_success "⚠️  ORDER CANCELLED (Payment Failed)"
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  Payment Failed (~10% expected)   ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════╝${NC}"
    echo ""
    print_info "The fix is working! Order transitioned from PENDING to CANCELLED."
    print_info "This demonstrates the compensation/rollback mechanism."
    exit 0
    
else
    print_error "🔴 ORDER STILL PENDING!"
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ Order Flow Failed!                 ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
    echo ""
    print_error "The order did not transition from PENDING state."
    echo ""
    print_info "Recent Payment Service Logs:"
    docker logs --tail 10 payment-service 2>&1 | grep -E "order.*$ORDER_ID|Processing|Payment"
    echo ""
    print_info "Recent Order Service Logs:"
    docker logs --tail 10 order-service 2>&1 | grep -E "order.*$ORDER_ID|payment|Received"
    exit 1
fi
