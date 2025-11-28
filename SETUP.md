# Setup Instructions

## Quick Start

1. **Prerequisites Check**
   ```bash
   java -version  # Should be 17+
   mvn -version   # Should be 3.6+
   docker --version
   docker-compose --version
   ```

2. **Build All Services**
   ```bash
   # Build all services (takes a few minutes)
   for dir in auth-service restaurant-service order-service payment-service notification-service api-gateway; do
     echo "Building $dir..."
     cd $dir && mvn clean package -DskipTests && cd ..
   done
   ```

3. **Start Everything**
   ```bash
   docker-compose up --build
   ```

4. **Verify Services are Running**
   ```bash
   docker-compose ps
   ```

   All services should show as "Up" and "healthy".

5. **Check Logs**
   ```bash
   # View all logs
   docker-compose logs -f

   # View specific service logs
   docker-compose logs -f order-service
   ```

## Testing the System

### 1. Register a User
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com", "password": "12345"}'
```

### 2. Create a Restaurant
```bash
curl -X POST http://localhost:8080/api/restaurants \
  -H "Content-Type: application/json" \
  -d '{"name": "Pizza Palace", "address": "Mumbai"}'
```

Note the restaurant ID from the response (e.g., `{"id": 1, ...}`)

### 3. Add Menu Items
```bash
# Add first menu item
curl -X POST http://localhost:8080/api/restaurants/1/menu \
  -H "Content-Type: application/json" \
  -d '{"name": "Veg Pizza", "price": 250}'

# Add second menu item
curl -X POST http://localhost:8080/api/restaurants/1/menu \
  -H "Content-Type: application/json" \
  -d '{"name": "Margherita Pizza", "price": 300}'
```

Note the menu item IDs from responses.

### 4. Create an Order
```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "restaurantId": 1,
    "items": [
      {"menuItemId": 1, "quantity": 2},
      {"menuItemId": 2, "quantity": 1}
    ]
  }'
```

### 5. Check Order Status
```bash
# Use the order ID from the previous response
curl http://localhost:8080/api/orders/1
```

### 6. Verify Event Flow
```bash
# Check payment service logs
docker-compose logs payment-service

# Check notification service logs
docker-compose logs notification-service
```

You should see:
- Payment service consuming `OrderCreatedEvent`
- Payment processing (90% success simulation)
- Payment service publishing `PaymentResultEvent`
- Notification service consuming `PaymentResultEvent`
- Notification being created

## Troubleshooting

### Services won't start
- Check if ports are already in use
- Verify MySQL containers are healthy: `docker-compose ps`
- Check service logs: `docker-compose logs <service-name>`

### Database connection errors
- Wait for MySQL containers to be fully initialized (can take 30-60 seconds)
- Check MySQL logs: `docker-compose logs mysql_auth`

### RabbitMQ connection errors
- Verify RabbitMQ is running: `docker-compose ps rabbitmq`
- Check RabbitMQ management UI: http://localhost:15672 (guest/guest)
- Verify exchanges and queues are created in the UI

### Inter-service communication failures
- Ensure all services are on the same Docker network
- Check service names match in application.properties and docker-compose.yml
- Verify services are using container names (not localhost) for communication

### Build failures
- Ensure Java 17 is installed and JAVA_HOME is set
- Clear Maven cache: `mvn clean`
- Check pom.xml files for syntax errors

## Stopping the System

```bash
# Stop all services
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop and remove containers and volumes (deletes databases)
docker-compose down -v
```

## Development Mode

### Rebuild a Single Service
```bash
cd auth-service
mvn clean package
docker-compose up --build auth-service
```

### View Service Health
```bash
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
# etc.
```

### Access RabbitMQ Management
- URL: http://localhost:15672
- Username: guest
- Password: guest

In the management UI, you can:
- View exchanges (`orders-exchange`, `payments-exchange`)
- View queues (`payment-queue`, `payment-result-queue`)
- Monitor message flow
- Test message publishing/consuming

## Architecture Overview

```
Client
  |
  v
API Gateway (8080)
  |
  +---> Auth Service (8081) ---> MySQL (auth_db)
  |
  +---> Restaurant Service (8082) ---> MySQL (restaurant_db)
  |
  +---> Order Service (8083) ---> MySQL (order_db)
         |
         +---> REST call ---> Restaurant Service
         |
         +---> RabbitMQ ---> orders-exchange
                              |
                              v
                         payment-queue
                              |
                              v
                         Payment Service (8084) ---> MySQL (payment_db)
                              |
                              +---> RabbitMQ ---> payments-exchange
                                                   |
                                                   v
                                              payment-result-queue
                                                   |
                                                   v
                                              Notification Service (8085) ---> MySQL (notification_db)
```

## Next Steps

1. Add authentication/authorization middleware to API Gateway
2. Add distributed tracing (Zipkin/Jaeger)
3. Add service discovery (Eureka/Consul)
4. Add API documentation (Swagger/OpenAPI)
5. Add comprehensive error handling
6. Add integration tests
7. Add CI/CD pipeline
8. Add monitoring and alerting (Prometheus/Grafana)

