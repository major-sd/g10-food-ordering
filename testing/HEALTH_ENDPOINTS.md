# Food Ordering Microservices - Health Endpoints

## Service Health Check URLs

All services are accessible via their respective ports on localhost.

### Gateway Service
- **Port:** 8080
- **Health Endpoint:** `http://localhost:8080/health`
- **Status:** TBD

### User Service  
- **Port:** 8081
- **Health Endpoint:** `http://localhost:8081/api/users/health`
- **Status:** ✅ Working (200 OK)

### Catalog Service
- **Port:** 8082
- **Health Endpoint:** `http://localhost:8082/api/restaurants/health`
- **Status:** ✅ Working (200 OK)

### Order Service
- **Port:** 8083
- **Health Endpoint:** `http://localhost:8083/api/orders/health`
- **Status:** ✅ Working (200 OK)

### Payment Service
- **Port:** 8084
- **Health Endpoint:** `http://localhost:8084/api/payments/health`
- **Status:** ✅ Working (200 OK)

### Delivery Service
- **Port:** 8085
- **Health Endpoint:** `http://localhost:8085/api/delivery/health`
- **Status:** ✅ Working (200 OK)

## Quick Test All Health Endpoints

```bash
# Test all service health endpoints
echo "=== Testing All Service Health Endpoints ==="
echo ""

echo "User Service:"
curl -s http://localhost:8081/api/users/health | jq
echo ""

echo "Catalog Service:"
curl -s http://localhost:8082/api/restaurants/health | jq
echo ""

echo "Order Service:"
curl -s http://localhost:8083/api/orders/health | jq
echo ""

echo "Payment Service:"
curl -s http://localhost:8084/api/payments/health | jq
echo ""

echo "Delivery Service:"
curl -s http://localhost:8085/api/delivery/health | jq
```

## Notes

- All health endpoints require the service-specific path prefix (e.g., `/api/users/`, `/api/delivery/`)
- The root `/health` endpoint is not available on individual services
- All endpoints are now publicly accessible (no authentication required)
- Health checks return JSON with status information

## Security Configuration

Each service's `SecurityConfig.java` has been updated to allow public access to:
- `/actuator/**` - Spring Boot Actuator endpoints
- `/health` - Root health endpoint (if controller exists)
- `/api/{service}/health` - Service-specific health endpoint
- `/api-docs/**`, `/swagger-ui/**` - API documentation

## Last Updated
2025-11-25
