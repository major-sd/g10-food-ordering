#!/bin/bash

# Comprehensive API Testing Script
# Tests all endpoints across all microservices

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result tracking
declare -a FAILED_ENDPOINTS

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Comprehensive API Testing - All Microservices         ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Helper function to test API endpoint
test_endpoint() {
    local method=$1
    local url=$2
    local expected_status=$3
    local description=$4
    local auth_token=$5
    local data=$6
    
    ((TOTAL_TESTS++))
    
    # Build curl command
    local curl_cmd="curl -s -w \"\n%{http_code}\" -X $method \"$url\""
    
    if [ ! -z "$auth_token" ]; then
        curl_cmd="$curl_cmd -H \"Authorization: Bearer $auth_token\""
    fi
    
    if [ ! -z "$data" ]; then
        curl_cmd="$curl_cmd -H \"Content-Type: application/json\" -d '$data'"
    fi
    
    # Execute request
    local response=$(eval $curl_cmd 2>/dev/null)
    local status_code=$(echo "$response" | tail -n1)
    
    # Check result
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS${NC} - $description (HTTP $status_code)"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ FAIL${NC} - $description (Expected: $expected_status, Got: $status_code)"
        FAILED_ENDPOINTS+=("$description - Expected: $expected_status, Got: $status_code")
        ((FAILED_TESTS++))
    fi
}

# ============================================================================
# 1. USER SERVICE TESTS
# ============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. USER SERVICE API TESTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Health check
test_endpoint "GET" "http://localhost:8081/api/users/health" "200" "User Service - Health Check"

# Register new user
TIMESTAMP=$(date +%s)
TEST_EMAIL="apitest_${TIMESTAMP}@example.com"
REGISTER_DATA="{\"email\":\"$TEST_EMAIL\",\"password\":\"Test123!\",\"name\":\"API Test User\"}"

REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/users/register \
  -H "Content-Type: application/json" \
  -d "$REGISTER_DATA")

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✅ PASS${NC} - User Service - Register User"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    
    # Extract token
    USER_TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
else
    echo -e "${RED}❌ FAIL${NC} - User Service - Register User"
    FAILED_ENDPOINTS+=("User Service - Register User")
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
fi

# Login
LOGIN_DATA="{\"email\":\"$TEST_EMAIL\",\"password\":\"Test123!\"}"
test_endpoint "POST" "http://localhost:8081/api/users/login" "200" "User Service - Login" "" "$LOGIN_DATA"

# Get profile (authenticated)
if [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8081/api/users/profile" "200" "User Service - Get Profile" "$USER_TOKEN"
fi

# Login as admin for admin tests
ADMIN_LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@foodordering.com","password":"AdminPass123!"}')

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Test admin endpoint (update role)
if [ ! -z "$ADMIN_TOKEN" ] && [ ! -z "$USER_ID" ]; then
    test_endpoint "PUT" "http://localhost:8081/api/users/$USER_ID/role" "200" "User Service - Update Role (Admin)" "$ADMIN_TOKEN" '{"role":"DRIVER"}'
fi

# Test logout
test_endpoint "POST" "http://localhost:8081/api/users/logout" "200" "User Service - Logout" "$USER_TOKEN"

# ============================================================================
# 2. CATALOG SERVICE TESTS
# ============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. CATALOG SERVICE API TESTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Health check
test_endpoint "GET" "http://localhost:8082/api/restaurants/health" "200" "Catalog Service - Health Check"

# Get all restaurants (public)
test_endpoint "GET" "http://localhost:8082/api/restaurants" "200" "Catalog Service - List Restaurants"

# Get restaurants with pagination
test_endpoint "GET" "http://localhost:8082/api/restaurants?page=0&size=5&sortBy=name&sortDir=asc" "200" "Catalog Service - List Restaurants (Paginated)"

# Create restaurant (authenticated)
if [ ! -z "$USER_TOKEN" ]; then
    RESTAURANT_DATA='{"name":"Test Restaurant","description":"A test restaurant","cuisineType":"Italian","address":{"street":"123 Main St","city":"New York","state":"NY","zipCode":"10001","country":"USA"},"phone":"+1234567890","email":"test@restaurant.com","openingHours":"9:00 AM - 10:00 PM"}'
    
    CREATE_RESTAURANT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8082/api/restaurants \
      -H "Authorization: Bearer $USER_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$RESTAURANT_DATA")
    
    RESTAURANT_STATUS=$(echo "$CREATE_RESTAURANT_RESPONSE" | tail -n1)
    
    if [ "$RESTAURANT_STATUS" = "201" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Catalog Service - Create Restaurant"
        ((PASSED_TESTS++))
        
        # Extract restaurant ID
        RESTAURANT_ID=$(echo "$CREATE_RESTAURANT_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    else
        echo -e "${RED}❌ FAIL${NC} - Catalog Service - Create Restaurant (Expected: 201, Got: $RESTAURANT_STATUS)"
        FAILED_ENDPOINTS+=("Catalog Service - Create Restaurant")
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
fi

# Get restaurant by ID
if [ ! -z "$RESTAURANT_ID" ]; then
    test_endpoint "GET" "http://localhost:8082/api/restaurants/$RESTAURANT_ID" "200" "Catalog Service - Get Restaurant by ID"
    
    # Update restaurant
    UPDATE_DATA='{"name":"Updated Test Restaurant","description":"Updated description","cuisineType":"Italian","address":{"street":"123 Main St","city":"New York","state":"NY","zipCode":"10001","country":"USA"},"phone":"+1234567890","email":"test@restaurant.com","openingHours":"9:00 AM - 11:00 PM"}'
    test_endpoint "PUT" "http://localhost:8082/api/restaurants/$RESTAURANT_ID" "200" "Catalog Service - Update Restaurant" "$USER_TOKEN" "$UPDATE_DATA"
fi

# Search restaurants
test_endpoint "GET" "http://localhost:8082/api/restaurants/search?query=test" "200" "Catalog Service - Search Restaurants"

# Get by cuisine
test_endpoint "GET" "http://localhost:8082/api/restaurants/cuisine/Italian" "200" "Catalog Service - Filter by Cuisine"

# Get by city
test_endpoint "GET" "http://localhost:8082/api/restaurants/city/New%20York" "200" "Catalog Service - Filter by City"

# Get by rating
test_endpoint "GET" "http://localhost:8082/api/restaurants/rating/4.0" "200" "Catalog Service - Filter by Rating"

# ============================================================================
# 3. ORDER SERVICE TESTS
# ============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. ORDER SERVICE API TESTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Health check
test_endpoint "GET" "http://localhost:8083/api/orders/health" "200" "Order Service - Health Check"

# Create order (authenticated)
if [ ! -z "$USER_TOKEN" ] && [ ! -z "$RESTAURANT_ID" ]; then
    ORDER_DATA="{\"userId\":\"$USER_ID\",\"restaurantId\":\"$RESTAURANT_ID\",\"items\":[{\"menuItemId\":\"item123\",\"name\":\"Pizza\",\"quantity\":2,\"price\":15.99}],\"deliveryAddress\":{\"street\":\"456 Oak Ave\",\"city\":\"New York\",\"state\":\"NY\",\"zipCode\":\"10002\",\"country\":\"USA\"},\"totalAmount\":31.98}"
    
    CREATE_ORDER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8083/api/orders \
      -H "Authorization: Bearer $USER_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$ORDER_DATA")
    
    ORDER_STATUS=$(echo "$CREATE_ORDER_RESPONSE" | tail -n1)
    
    if [ "$ORDER_STATUS" = "201" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Order Service - Create Order"
        ((PASSED_TESTS++))
        
        # Extract order ID
        ORDER_ID=$(echo "$CREATE_ORDER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    else
        echo -e "${RED}❌ FAIL${NC} - Order Service - Create Order (Expected: 201, Got: $ORDER_STATUS)"
        FAILED_ENDPOINTS+=("Order Service - Create Order")
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
fi

# Get my orders
if [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8083/api/orders/my-orders" "200" "Order Service - Get My Orders" "$USER_TOKEN"
fi

# Get order by ID
if [ ! -z "$ORDER_ID" ] && [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8083/api/orders/$ORDER_ID" "200" "Order Service - Get Order by ID" "$USER_TOKEN"
fi

# Get all orders (admin)
if [ ! -z "$ADMIN_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8083/api/orders" "200" "Order Service - Get All Orders (Admin)" "$ADMIN_TOKEN"
fi

# Update order status
if [ ! -z "$ORDER_ID" ] && [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "PUT" "http://localhost:8083/api/orders/$ORDER_ID/status" "200" "Order Service - Update Order Status" "$USER_TOKEN" '{"status":"CONFIRMED"}'
fi

# Get recent orders (admin)
if [ ! -z "$ADMIN_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8083/api/orders/recent" "200" "Order Service - Get Recent Orders (Admin)" "$ADMIN_TOKEN"
fi

# Get order stats (admin)
if [ ! -z "$ADMIN_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8083/api/orders/stats" "200" "Order Service - Get Order Stats (Admin)" "$ADMIN_TOKEN"
fi

# ============================================================================
# 4. PAYMENT SERVICE TESTS
# ============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. PAYMENT SERVICE API TESTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Health check
test_endpoint "GET" "http://localhost:8084/api/payments/health" "200" "Payment Service - Health Check"

# Get payment methods (public)
test_endpoint "GET" "http://localhost:8084/api/payments/methods" "200" "Payment Service - Get Payment Methods"

# Process payment (authenticated)
if [ ! -z "$USER_TOKEN" ] && [ ! -z "$ORDER_ID" ]; then
    PAYMENT_DATA="{\"orderId\":\"$ORDER_ID\",\"amount\":31.98,\"paymentMethod\":\"CREDIT_CARD\",\"cardNumber\":\"4111111111111111\",\"cardHolder\":\"Test User\"}"
    
    PAYMENT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8084/api/payments/process \
      -H "Authorization: Bearer $USER_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$PAYMENT_DATA")
    
    PAYMENT_STATUS=$(echo "$PAYMENT_RESPONSE" | tail -n1)
    
    if [ "$PAYMENT_STATUS" = "200" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Payment Service - Process Payment"
        ((PASSED_TESTS++))
        
        # Extract transaction ID
        TRANSACTION_ID=$(echo "$PAYMENT_RESPONSE" | grep -o '"transactionId":"[^"]*"' | cut -d'"' -f4)
    else
        echo -e "${RED}❌ FAIL${NC} - Payment Service - Process Payment (Expected: 200, Got: $PAYMENT_STATUS)"
        FAILED_ENDPOINTS+=("Payment Service - Process Payment")
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
fi

# Get payment status
if [ ! -z "$TRANSACTION_ID" ] && [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8084/api/payments/status/$TRANSACTION_ID" "200" "Payment Service - Get Payment Status" "$USER_TOKEN"
fi

# Process refund
if [ ! -z "$TRANSACTION_ID" ] && [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "POST" "http://localhost:8084/api/payments/refund/$TRANSACTION_ID" "200" "Payment Service - Process Refund" "$USER_TOKEN" '{"amount":31.98,"reason":"Customer request"}'
fi

# ============================================================================
# 5. DELIVERY SERVICE TESTS
# ============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. DELIVERY SERVICE API TESTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Health check
test_endpoint "GET" "http://localhost:8085/api/delivery/health" "200" "Delivery Service - Health Check"

# Create delivery (authenticated)
if [ ! -z "$USER_TOKEN" ] && [ ! -z "$ORDER_ID" ]; then
    DELIVERY_DATA="{\"orderId\":\"$ORDER_ID\",\"pickupAddress\":{\"street\":\"123 Main St\",\"city\":\"New York\",\"state\":\"NY\",\"zipCode\":\"10001\",\"country\":\"USA\"},\"deliveryAddress\":{\"street\":\"456 Oak Ave\",\"city\":\"New York\",\"state\":\"NY\",\"zipCode\":\"10002\",\"country\":\"USA\"}}"
    
    DELIVERY_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8085/api/delivery \
      -H "Authorization: Bearer $USER_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$DELIVERY_DATA")
    
    DELIVERY_STATUS=$(echo "$DELIVERY_RESPONSE" | tail -n1)
    
    if [ "$DELIVERY_STATUS" = "201" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Delivery Service - Create Delivery"
        ((PASSED_TESTS++))
        
        # Extract delivery ID
        DELIVERY_ID=$(echo "$DELIVERY_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    else
        echo -e "${RED}❌ FAIL${NC} - Delivery Service - Create Delivery (Expected: 201, Got: $DELIVERY_STATUS)"
        FAILED_ENDPOINTS+=("Delivery Service - Create Delivery")
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
fi

# Track delivery (public)
if [ ! -z "$DELIVERY_ID" ]; then
    test_endpoint "GET" "http://localhost:8085/api/delivery/$DELIVERY_ID/track" "200" "Delivery Service - Track Delivery (Public)"
fi

# Get delivery by ID
if [ ! -z "$DELIVERY_ID" ] && [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8085/api/delivery/$DELIVERY_ID" "200" "Delivery Service - Get Delivery by ID" "$USER_TOKEN"
fi

# Get available drivers (authenticated)
if [ ! -z "$USER_TOKEN" ]; then
    test_endpoint "GET" "http://localhost:8085/api/delivery/drivers/available" "200" "Delivery Service - Get Available Drivers" "$USER_TOKEN"
fi

# ============================================================================
# 6. GATEWAY TESTS
# ============================================================================
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}6. GATEWAY SERVICE API TESTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Health checks
test_endpoint "GET" "http://localhost:8080/actuator/health" "200" "Gateway - Actuator Health"
test_endpoint "GET" "http://localhost:8080/fallback/health" "200" "Gateway - Fallback Health"

# Test shortcut routes
GATEWAY_REGISTER_DATA="{\"email\":\"gateway_${TIMESTAMP}@example.com\",\"password\":\"Test123!\",\"name\":\"Gateway Test\"}"
test_endpoint "POST" "http://localhost:8080/register" "201" "Gateway - Register Shortcut" "" "$GATEWAY_REGISTER_DATA"

GATEWAY_LOGIN_DATA="{\"email\":\"admin@foodordering.com\",\"password\":\"AdminPass123!\"}"
test_endpoint "POST" "http://localhost:8080/login" "200" "Gateway - Login Shortcut" "" "$GATEWAY_LOGIN_DATA"

# Test routing through gateway
test_endpoint "GET" "http://localhost:8080/api/restaurants" "200" "Gateway - Route to Catalog Service"
test_endpoint "GET" "http://localhost:8080/actuator/circuitbreakers" "200" "Gateway - Circuit Breaker Status"

# ============================================================================
# FINAL REPORT
# ============================================================================
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TEST RESULTS SUMMARY                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

echo -e "Total Tests:    ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:         ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:         ${RED}$FAILED_TESTS${NC}"
echo -e "Success Rate:   ${BLUE}$SUCCESS_RATE%${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED! All APIs are working correctly!${NC}\n"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Details:${NC}\n"
    for endpoint in "${FAILED_ENDPOINTS[@]}"; do
        echo -e "${RED}  ❌ $endpoint${NC}"
    done
    echo ""
    exit 1
fi
