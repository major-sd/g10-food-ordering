# Quick Start Guide - Food Ordering Microservices

## Prerequisites

Before starting, ensure you have the following installed:

- **Java 17** or higher
  ```bash
  java -version
  ```

- **Maven 3.6+**
  ```bash
  mvn -version
  ```

- **Docker** and **Docker Compose**
  ```bash
  docker --version
  docker-compose --version
  ```

## Step-by-Step Setup

### Step 1: Verify Project Structure

Ensure you're in the project root directory:
```bash
cd /Users/I528949/Scalable-services
ls -la
```

You should see:
- `auth-service/`
- `restaurant-service/`
- `order-service/`
- `payment-service/`
- `notification-service/`
- `api-gateway/`
- `docker-compose.yml`

### Step 2: Build All Services

Build all Spring Boot services using Maven:

```bash
# Option 1: Build all services using a loop
for service in auth-service restaurant-service order-service payment-service notification-service api-gateway; do
  echo "Building $service..."
  cd $service
  mvn clean package -DskipTests
  cd ..
  echo "✓ $service built successfully"
done

# Option 2: Build individually (if loop doesn't work)
cd auth-service && mvn clean package -DskipTests && cd ..
cd restaurant-service && mvn clean package -DskipTests && cd ..
cd order-service && mvn clean package -DskipTests && cd ..
cd payment-service && mvn clean package -DskipTests && cd ..
cd notification-service && mvn clean package -DskipTests && cd ..
cd api-gateway && mvn clean package -DskipTests && cd ..
```

**Expected Output:** Each service should build successfully with `BUILD SUCCESS` message.

**Troubleshooting:**
- If build fails, check Java version: `java -version` (should be 17+)
- If Maven not found, install Maven or add to PATH
- For permission issues, use `chmod +x` or check file permissions

### Step 3: Clean Previous Docker Containers (Optional)

If you've run this before, clean up old containers:

```bash
docker-compose down -v
docker system prune -f
```

This removes:
- All containers
- All volumes (databases)
- Unused images

### Step 4: Start All Services with Docker Compose

Start all services, databases, and RabbitMQ:

```bash
docker-compose up --build
```

**What this does:**
- Builds Docker images for all services
- Starts 5 MySQL databases (one per service)
- Starts RabbitMQ with management UI
- Starts all 6 microservices
- Creates a Docker network for inter-service communication

**Expected Output:** You should see logs from all services starting up.

**First Time Setup:** This may take 5-10 minutes as it downloads images and builds services.

### Step 5: Wait for Services to Start

Wait for all services to be healthy. You'll know they're ready when you see:

```
✓ mysql_auth is healthy
✓ mysql_restaurant is healthy
✓ mysql_order is healthy
✓ mysql_payment is healthy
✓ mysql_notification is healthy
✓ rabbitmq is healthy
✓ auth-service started
✓ restaurant-service started
✓ order-service started
✓ payment-service started
✓ notification-service started
✓ api-gateway started
```

**Check Service Status:**
```bash
# In a new terminal window
docker-compose ps
```

All services should show `Up` status.

### Step 6: Verify Services are Running

Test health endpoints:

```bash
# Test Auth Service
curl http://localhost:8081/health

# Test Restaurant Service
curl http://localhost:8082/health

# Test Order Service
curl http://localhost:8083/health

# Test Payment Service
curl http://localhost:8084/health

# Test Notification Service
curl http://localhost:8085/health

# Test API Gateway
curl http://localhost:8080/actuator/health
```

**Expected Response:**
```json
{
  "status": "UP",
  "service": "auth-service",
  "timestamp": 1234567890
}
```

### Step 7: Access Management UIs

**RabbitMQ Management UI:**
- URL: http://localhost:15672
- Username: `guest`
- Password: `guest`

You can monitor:
- Exchanges (`orders-exchange`, `payments-exchange`)
- Queues (`payment-queue`, `payment-result-queue`)
- Message flow

## Testing the System

### Option 1: Using Postman Collection (Recommended)

1. **Import Postman Collection:**
   - Open Postman
   - Click **Import**
   - Select `Food_Ordering_Microservices.postman_collection.json`
   - Click **Import**

2. **Set Environment:**
   - The collection uses `base_url` variable (default: `http://localhost:8080`)
   - No additional setup needed

3. **Test Flow:**
   ```
   1. Register User → Saves token to user_token
   2. Register Admin → Saves token to admin_token
   3. Login User → Updates user_token
   4. Login Admin → Updates admin_token
   5. Create Restaurant (as Admin)
   6. Add Menu Items (as Admin)
   7. Create Order (as User)
   8. View Order (as User)
   ```

### Option 2: Using cURL Commands

#### 1. Register a User
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "12345",
    "role": "USER"
  }'
```

**Save the token from response** (you'll need it for authenticated requests).

#### 2. Register an Admin
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Admin User",
    "email": "admin@example.com",
    "password": "admin123",
    "role": "ADMIN"
  }'
```

#### 3. Login as User
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "12345"
  }'
```

**Copy the token from the response** and use it in the next commands as `<TOKEN>`.

#### 4. Create a Restaurant (Admin)
```bash
curl -X POST http://localhost:8080/api/restaurants \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -d '{
    "name": "Pizza Palace",
    "address": "Mumbai"
  }'
```

#### 5. Add Menu Item (Admin)
```bash
curl -X POST http://localhost:8080/api/restaurants/1/menu \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -d '{
    "name": "Veg Pizza",
    "price": 250
  }'
```

#### 6. Create an Order (User)
```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <USER_TOKEN>" \
  -d '{
    "restaurantId": 1,
    "items": [
      {
        "menuItemId": 1,
        "quantity": 2
      }
    ]
  }'
```

#### 7. View Order (User)
```bash
curl -X GET http://localhost:8080/api/orders/1 \
  -H "Authorization: Bearer <USER_TOKEN>"
```

## Service URLs

### Via API Gateway (Port 8080)
- Base URL: `http://localhost:8080/api`
- Auth: `http://localhost:8080/api/auth/**`
- Restaurants: `http://localhost:8080/api/restaurants/**`
- Orders: `http://localhost:8080/api/orders/**`

### Direct Service Access
- Auth Service: `http://localhost:8081`
- Restaurant Service: `http://localhost:8082`
- Order Service: `http://localhost:8083`
- Payment Service: `http://localhost:8084`
- Notification Service: `http://localhost:8085`

### Database Ports (for direct connection if needed)
- Auth DB: `localhost:33061`
- Restaurant DB: `localhost:33062`
- Order DB: `localhost:33063`
- Payment DB: `localhost:33064`
- Notification DB: `localhost:33065`

## Monitoring and Logs

### View All Logs
```bash
docker-compose logs -f
```

### View Specific Service Logs
```bash
docker-compose logs -f auth-service
docker-compose logs -f order-service
docker-compose logs -f payment-service
```

### Check Service Status
```bash
docker-compose ps
```

### Check Resource Usage
```bash
docker stats
```

## Stopping the System

### Stop Services (Keep Data)
```bash
docker-compose stop
```

### Stop and Remove Containers
```bash
docker-compose down
```

### Stop and Remove Everything (Including Databases)
```bash
docker-compose down -v
```

## Troubleshooting

### Services Won't Start

1. **Check Port Availability:**
   ```bash
   # Check if ports are in use
   lsof -i :8080
   lsof -i :8081
   # etc.
   ```

2. **Check Docker is Running:**
   ```bash
   docker ps
   ```

3. **Check Logs:**
   ```bash
   docker-compose logs <service-name>
   ```

### Database Connection Errors

1. **Wait for MySQL to Initialize:**
   - MySQL containers take 30-60 seconds to fully initialize
   - Wait for "healthy" status in `docker-compose ps`

2. **Check Database Logs:**
   ```bash
   docker-compose logs mysql_auth
   ```

### Build Errors

1. **Java Version:**
   ```bash
   java -version  # Should be 17+
   ```

2. **Maven Version:**
   ```bash
   mvn -version  # Should be 3.6+
   ```

3. **Clean and Rebuild:**
   ```bash
   mvn clean install
   ```

### RabbitMQ Connection Issues

1. **Check RabbitMQ is Running:**
   ```bash
   docker-compose ps rabbitmq
   ```

2. **Access Management UI:**
   - http://localhost:15672 (guest/guest)
   - Verify exchanges and queues are created

### JWT Token Issues

1. **Token Expired:**
   - Tokens expire after 24 hours
   - Login again to get a new token

2. **Invalid Token:**
   - Check token is in correct format: `Bearer <token>`
   - Verify token wasn't corrupted during copy-paste

### Permission Denied Errors

1. **Check User Role:**
   - Some endpoints require ADMIN role
   - Verify you're using the correct token

2. **Check Authorization Header:**
   ```bash
   -H "Authorization: Bearer <your-token>"
   ```

## Quick Verification Checklist

- [ ] All services built successfully
- [ ] All containers are running (`docker-compose ps`)
- [ ] Health endpoints return 200 OK
- [ ] RabbitMQ management UI accessible
- [ ] Can register users
- [ ] Can login and get tokens
- [ ] Can create restaurants (as admin)
- [ ] Can create orders (as user)

## Next Steps

Once everything is running:

1. **Explore the API** using Postman collection
2. **Monitor Events** in RabbitMQ management UI
3. **Check Logs** to see event flow
4. **Test Different Scenarios:**
   - Order creation triggers payment
   - Payment success triggers notification
   - Payment failure triggers notification

## Common Commands Cheat Sheet

```bash
# Start everything
docker-compose up --build

# Start in background
docker-compose up -d --build

# Stop everything
docker-compose down

# View logs
docker-compose logs -f

# Restart a service
docker-compose restart auth-service

# Rebuild a service
docker-compose up --build auth-service

# Check status
docker-compose ps

# Clean everything
docker-compose down -v
docker system prune -a
```

## Support

If you encounter issues:
1. Check the logs: `docker-compose logs -f <service-name>`
2. Verify prerequisites are installed
3. Check port availability
4. Review the troubleshooting section above

Happy coding! 🚀

