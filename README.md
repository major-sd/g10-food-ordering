# Food Ordering Microservices System

A complete production-structured microservices system built with Spring Boot 3.x, featuring 6 microservices communicating via REST and RabbitMQ.

## Architecture

### Services

1. **auth-service** (Port 8081) - User authentication and authorization
2. **restaurant-service** (Port 8082) - Restaurant and menu management
3. **order-service** (Port 8083) - Order processing
4. **payment-service** (Port 8084) - Payment processing
5. **notification-service** (Port 8085) - Notification handling
6. **api-gateway** (Port 8080) - Spring Cloud Gateway for routing

### Infrastructure

- **RabbitMQ** - Message broker for async communication (Management UI on 15672)
- **MySQL** - 5 separate databases (one per service)
  - mysql_auth (33061)
  - mysql_restaurant (33062)
  - mysql_order (33063)
  - mysql_payment (33064)
  - mysql_notification (33065)

## Technology Stack

- Java 17
- Spring Boot 3.2.0
- Spring Data JPA
- Spring Cloud Gateway
- RabbitMQ
- MySQL 8.0
- Docker & Docker Compose
- Lombok
- WebClient (for inter-service REST calls)

## Prerequisites

- Java 17+
- Maven 3.6+
- Docker & Docker Compose

## Building the Project

### Build Individual Services

```bash
cd auth-service && mvn clean package
cd ../restaurant-service && mvn clean package
cd ../order-service && mvn clean package
cd ../payment-service && mvn clean package
cd ../notification-service && mvn clean package
cd ../api-gateway && mvn clean package
```

### Build All Services at Once

```bash
# From root directory
for service in auth-service restaurant-service order-service payment-service notification-service api-gateway; do
  echo "Building $service..."
  cd $service && mvn clean package && cd ..
done
```

## Running the System

### Start All Services with Docker Compose

```bash
docker-compose up --build
```

This will:
- Start all MySQL databases
- Start RabbitMQ with management UI
- Build and start all 6 microservices
- Create Docker network for inter-service communication

### Access Points

- **API Gateway**: http://localhost:8080
- **RabbitMQ Management UI**: http://localhost:15672 (guest/guest)
- **Direct Service Access**:
  - Auth Service: http://localhost:8081
  - Restaurant Service: http://localhost:8082
  - Order Service: http://localhost:8083
  - Payment Service: http://localhost:8084
  - Notification Service: http://localhost:8085

## API Endpoints

### Via API Gateway (Port 8080)

#### Authentication
```
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/health
```

#### Restaurants
```
POST /api/restaurants
GET  /api/restaurants
POST /api/restaurants/{id}/menu
GET  /api/restaurants/menu/{menuItemId}
```

#### Orders
```
POST /api/orders
GET  /api/orders/{orderId}
```

## Example API Usage

### 1. Register a User

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "12345"
  }'
```

Response:
```json
{
  "token": "jwt-token-here"
}
```

### 2. Create a Restaurant

```bash
curl -X POST http://localhost:8080/api/restaurants \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Pizza Palace",
    "address": "Mumbai"
  }'
```

### 3. Add Menu Item

```bash
curl -X POST http://localhost:8080/api/restaurants/1/menu \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Veg Pizza",
    "price": 250
  }'
```

### 4. Create an Order

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "restaurantId": 1,
    "items": [
      {
        "menuItemId": 1,
        "quantity": 2
      }
    ]
  }'
```

## Event Flow

1. **Order Created Event Flow**:
   - Order Service creates order → Publishes `OrderCreatedEvent` to `orders-exchange`
   - Payment Service consumes event from `payment-queue`
   - Payment Service processes payment (90% success rate simulation)
   - Payment Service publishes `PaymentResultEvent` to `payments-exchange`

2. **Payment Result Event Flow**:
   - Notification Service consumes `PaymentResultEvent` from `payment-result-queue`
   - Notification Service creates and saves notification
   - Notification message: "Order {id} confirmed" or "Order {id} failed"

## Database Schema

Each service has its own MySQL database:

- **auth_db**: users table
- **restaurant_db**: restaurants, menu_items tables
- **order_db**: orders, order_items tables
- **payment_db**: payment_records table
- **notification_db**: notifications table

## Inter-Service Communication

### Synchronous (REST)
- Order Service → Restaurant Service (via WebClient)
  - URL: `http://restaurant-service:8082/restaurants/menu/{menuItemId}`

### Asynchronous (RabbitMQ)
- **Exchanges**:
  - `orders-exchange` (Topic)
  - `payments-exchange` (Topic)

- **Queues**:
  - `payment-queue` (bound to orders-exchange with routing key `order.created`)
  - `payment-result-queue` (bound to payments-exchange with routing key `payment.result`)

## Stopping the System

```bash
docker-compose down
```

To remove volumes (databases):

```bash
docker-compose down -v
```

## Development

### Project Structure

Each service follows this structure:
```
service-name/
├── src/main/java/com/foodorder/{service}/
│   ├── controller/
│   ├── service/
│   ├── repository/
│   ├── model/
│   ├── dto/
│   ├── config/
│   └── {Service}Application.java
├── src/main/resources/
│   └── application.properties
├── Dockerfile
└── pom.xml
```

### Configuration

All services use `application.properties` with:
- Database connection to respective MySQL container
- RabbitMQ connection
- Server port
- JPA/Hibernate settings

## Notes

- All services use constructor injection
- Lombok is used for reducing boilerplate code
- Jackson JSON message converter for RabbitMQ
- Docker containers communicate using container names
- Health checks configured for all databases and RabbitMQ

## Troubleshooting

1. **Services not starting**: Check if MySQL databases are healthy
2. **RabbitMQ connection issues**: Verify RabbitMQ container is running
3. **Inter-service calls failing**: Ensure all services are on the same Docker network
4. **Port conflicts**: Check if ports are already in use

## License

This is a demonstration project for microservices architecture.

