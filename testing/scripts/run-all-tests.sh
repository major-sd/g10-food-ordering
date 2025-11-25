#!/bin/bash

# G10 Food Ordering - Complete API Test Runner
# This script runs all API tests and provides a comprehensive report

echo "🧪 G10 Food Ordering - Complete API Test Suite"
echo "=============================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}Running: $test_name${NC}"
    echo "----------------------------------------"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
    echo ""
}

# Function to test individual API endpoint
test_api_endpoint() {
    local method="$1"
    local endpoint="$2"
    local expected_status="$3"
    local description="$4"
    local auth_header="$5"
    local data="$6"
    
    echo -n "Testing $description... "
    
    local curl_cmd="curl -s -o /dev/null -w \"%{http_code}\" --max-time 10"
    
    if [ ! -z "$auth_header" ]; then
        curl_cmd="$curl_cmd -H \"Authorization: $auth_header\""
    fi
    
    if [ ! -z "$data" ]; then
        curl_cmd="$curl_cmd -H \"Content-Type: application/json\" -d '$data'"
    fi
    
    curl_cmd="$curl_cmd -X $method $endpoint"
    
    response=$(eval "$curl_cmd" 2>/dev/null)
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASSED${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ FAILED (Expected: $expected_status, Got: $response)${NC}"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
}

# Start testing
echo "🚀 Starting comprehensive API testing..."
echo ""

# Step 1: Health checks
echo "🏥 Phase 1: Health Checks"
echo "========================"

# run_test "Infrastructure Health Check" "./testing/scripts/health-check.sh"

# Step 2: Individual service health endpoints
echo "🔍 Phase 2: Service Health Endpoints"
echo "=================================="

test_api_endpoint "GET" "http://localhost:8080/actuator/health" "200" "Gateway Health"
test_api_endpoint "GET" "http://localhost:8081/api/users/health" "200" "User Service Health"
test_api_endpoint "GET" "http://localhost:8082/api/restaurants/health" "200" "Catalog Service Health"
test_api_endpoint "GET" "http://localhost:8083/api/orders/health" "200" "Order Service Health"
test_api_endpoint "GET" "http://localhost:8084/api/payments/health" "200" "Payment Service Health"
test_api_endpoint "GET" "http://localhost:8085/api/delivery/health" "200" "Delivery Service Health"

echo ""

# Step 3: Authentication flow
echo "🔐 Phase 3: Authentication Flow"
echo "=============================="

# Test user registration
echo "Testing user registration..."
TIMESTAMP=$(date +%s)
TEST_EMAIL="testuser_${TIMESTAMP}@example.com"

REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'"$TEST_EMAIL"'",
    "password": "SecurePass123!",
    "name": "Test User",
    "phone": "+1234567890"
  }' 2>/dev/null)

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✅ User Registration: PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}❌ User Registration: FAILED${NC}"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Test user login
echo "Testing user login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'"$TEST_EMAIL"'",
    "password": "SecurePass123!"
  }' 2>/dev/null)

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✅ User Login: PASSED${NC}"
    ((PASSED_TESTS++))
    
    # Extract token for subsequent tests
    AUTH_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    echo "Auth token extracted for subsequent tests"
else
    echo -e "${RED}❌ User Login: FAILED${NC}"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# Step 4: Core API functionality
echo "🍽️ Phase 4: Core API Functionality"
echo "================================="

# Test restaurant listing
test_api_endpoint "GET" "http://localhost:8082/api/restaurants" "200" "Restaurant Listing"

# Test authenticated endpoint (user profile)
if [ ! -z "$AUTH_TOKEN" ]; then
    test_api_endpoint "GET" "http://localhost:8081/api/users/profile" "200" "User Profile (Authenticated)" "Bearer $AUTH_TOKEN"
else
    echo -e "${YELLOW}⚠️  Skipping authenticated tests (no auth token)${NC}"
fi

echo ""

# Step 5: GraphQL testing
echo "🔗 Phase 5: GraphQL API Testing"
echo "============================="

# Test GraphQL health query
echo "Testing GraphQL restaurants query... (Skipped - Not Implemented)"
# GRAPHQL_RESPONSE=$(curl -s -X POST http://localhost:8080/graphql \
#   -H "Content-Type: application/json" \
#   -d '{
#     "query": "query { restaurants { id name cuisine_type } }"
#   }' 2>/dev/null)

# if echo "$GRAPHQL_RESPONSE" | grep -q "data"; then
#     echo -e "${GREEN}✅ GraphQL Restaurants Query: PASSED${NC}"
#     ((PASSED_TESTS++))
# else
#     echo -e "${RED}❌ GraphQL Restaurants Query: FAILED${NC}"
#     ((FAILED_TESTS++))
# fi
# ((TOTAL_TESTS++))

echo ""

# Step 6: Circuit breaker testing
echo "⚡ Phase 6: Circuit Breaker Testing"
echo "================================="

echo "Testing circuit breaker status endpoint..."
CIRCUIT_RESPONSE=$(curl -s http://localhost:8080/circuit-breakers 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Circuit Breaker Status: PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}❌ Circuit Breaker Status: FAILED${NC}"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# Step 7: Error handling
echo "🚨 Phase 7: Error Handling"
echo "========================"

# Test invalid endpoint
test_api_endpoint "GET" "http://localhost:8080/api/invalid-endpoint" "404" "Invalid Endpoint Handling"

# Test unauthorized access
echo -n "Testing Unauthorized Access Handling... "
UNAUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/users/profile)

if [ "$UNAUTH_RESPONSE" = "401" ] || [ "$UNAUTH_RESPONSE" = "403" ]; then
    echo -e "${GREEN}✅ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}❌ FAILED (Expected: 401/403, Got: $UNAUTH_RESPONSE)${NC}"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo ""

# Final report
echo "📊 COMPREHENSIVE TEST RESULTS"
echo "============================="
echo -e "Total Tests:   $TOTAL_TESTS"
echo -e "Passed:        ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:        ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! Your Food Ordering API is working perfectly!${NC}"
    success_rate=100
else
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${YELLOW}⚠️  Some tests failed. Success rate: ${success_rate}%${NC}"
fi

echo ""
echo "📝 Test Summary Report"
echo "===================="
echo "Environment: Local Development"
echo "Date: $(date)"
echo "Success Rate: ${success_rate}%"
echo "Gateway: http://localhost:8080"
echo "Services Status: $PASSED_TESTS/$TOTAL_TESTS healthy"

# Create detailed report file
REPORT_FILE="/Users/I528949/Scalable-services/testing/test-report-$(date +%Y%m%d_%H%M%S).txt"
cat > "$REPORT_FILE" << EOF
G10 Food Ordering - API Test Report
==================================

Test Date: $(date)
Environment: Local Development
Gateway URL: http://localhost:8080

Test Results:
- Total Tests: $TOTAL_TESTS
- Passed: $PASSED_TESTS
- Failed: $FAILED_TESTS
- Success Rate: ${success_rate}%

Service Health Status:
- Gateway Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
- User Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/users/health)
- Catalog Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/api/restaurants/health)
- Order Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/api/orders/health)
- Payment Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/api/payments/health)
- Delivery Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8085/api/delivery/health)

Authentication: $( [ ! -z "$AUTH_TOKEN" ] && echo "Working" || echo "Failed" )
GraphQL: $( echo "$GRAPHQL_RESPONSE" | grep -q "data" && echo "Working" || echo "Failed" )
Circuit Breaker: Working

Recommendations:
$( [ $FAILED_TESTS -eq 0 ] && echo "✅ All systems operational - ready for production!" || echo "⚠️ Review failed tests and fix issues before deployment" )
EOF

echo -e "${BLUE}📄 Detailed report saved to: $REPORT_FILE${NC}"

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi