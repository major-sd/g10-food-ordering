# 🎯 End-to-End Demo: Order → Payment → Notification Flow

## 📋 Prerequisites

### 1. Start All Services
```bash
cd /Users/I528949/Scalable-services
./quick-redeploy.sh
```

### 2. Verify Services are Running
```bash
# Check Docker containers
docker ps

# You should see:
# - rabbitmq (ports 5672, 15672)
# - mysql_auth, mysql_restaurant, mysql_order, mysql_payment, mysql_notification
# - auth-service (8081)
# - restaurant-service (8082)
# - order-service (8083)
# - payment-service (8084)
# - notification-service (8085)
# - api-gateway (8080)
```

### 3. Environment Variables
Set your base URL:
```bash
export base_url="http://localhost:8080"
```

---

## 🎬 Demo Scenario 1: Complete Automatic Flow (Happy Path)

### Step 1: Register a User
```bash
POST {{base_url}}/api/auth/register

{
  "email": "demo@foodorder.com",
  "password": "password123",
  "name": "Demo User",
  "role": "USER"
}
```

**Expected Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "message": "User registered successfully"
}
```

**Action:** Copy the token for subsequent requests.

---

### Step 2: Login (if already registered)
```bash
POST {{base_url}}/api/auth/login

{
  "email": "demo@foodorder.com",
  "password": "password123"
}
```

**Expected Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": 1,
  "role": "USER"
}
```

---

### Step 3: View Available Restaurants
```bash
GET {{base_url}}/api/restaurants
```

**Expected Response:**
```json
[
  {
    "id": 1,
    "name": "Pizza Palace",
    "address": "Mumbai"
  },
  {
    "id": 2,
    "name": "Curl Bistro",
    "address": "NYC"
  },
  ...
]
```

---

### Step 4: View Restaurant Menu
```bash
GET {{base_url}}/api/restaurants/1/menu
```

**Expected Response:**
```json
[
  {
    "id": 1,
    "name": "Margherita Pizza",
    "price": 250.0,
    "restaurantId": 1
  },
  {
    "id": 2,
    "name": "Pepperoni Pizza",
    "price": 300.0,
    "restaurantId": 1
  }
]
```

---

### Step 5: Create an Order (This triggers the Saga!)
```bash
POST {{base_url}}/api/orders
Authorization: Bearer <your_user_token>

{
  "userId": 1,
  "restaurantId": 1,
  "items": [
    {
      "menuItemId": 1,
      "quantity": 2
    },
    {
      "menuItemId": 2,
      "quantity": 1
    }
  ]
}
```

**Expected Response:**
```json
{
  "id": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0,
  "status": "PENDING",
  "createdAt": "2025-11-28T12:34:56.789",
  "items": [
    {
      "id": 1,
      "menuItemId": 1,
      "quantity": 2,
      "price": 250.0
    },
    {
      "id": 2,
      "menuItemId": 2,
      "quantity": 1,
      "price": 300.0
    }
  ]
}
```

**🔔 What Happens Behind the Scenes:**

1. ✅ **Order Service**: Creates order with status `PENDING`
2. 📤 **Order Service**: Publishes `OrderCreatedEvent` to RabbitMQ
3. 📥 **Payment Service**: Receives event from `payment-queue`
4. 💳 **Payment Service**: Processes payment (90% success rate)
5. 💾 **Payment Service**: Saves payment record
6. 📤 **Payment Service**: Publishes `PaymentResultEvent`
7. 📥 **Order Service**: Receives payment result
8. ✅ **Order Service**: Updates order status to `CONFIRMED` or `CANCELLED`
9. 📥 **Notification Service**: Receives payment result
10. 📧 **Notification Service**: Sends notification to user

---

### Step 6: Wait 2-3 Seconds (for async processing)
```bash
sleep 3
```

---

### Step 7: Check Order Status (Should be CONFIRMED or CANCELLED)
```bash
GET {{base_url}}/api/orders/1
Authorization: Bearer <your_user_token>
```

**Expected Response (90% Success):**
```json
{
  "id": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0,
  "status": "CONFIRMED",  ← Order confirmed!
  "createdAt": "2025-11-28T12:34:56.789",
  "items": [...]
}
```

**Expected Response (10% Failure - Compensation):**
```json
{
  "id": 1,
  "status": "CANCELLED",  ← Order automatically cancelled!
  ...
}
```

---

### Step 8: Check Payment Record
```bash
GET {{base_url}}/api/payments/order/1
```

**Expected Response (Success):**
```json
{
  "id": 1,
  "orderId": 1,
  "success": true,
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "method": "CARD",
  "createdAt": "2025-11-28T12:34:57.123"
}
```

**Expected Response (Failure):**
```json
{
  "id": 1,
  "orderId": 1,
  "success": false,
  "transactionId": "550e8400-e29b-41d4-a716-446655440001",
  "method": "CARD",
  "createdAt": "2025-11-28T12:34:57.123"
}
```

---

### Step 9: Check Notification Service Logs
```bash
# Check notification service container logs
docker logs notification-service

# OR if running locally
# Check the console output of notification-service
```

**Expected Console Output (Success):**
```
================================================================================
📧 NOTIFICATION TO USER 1
--------------------------------------------------------------------------------
✅ Order #1 confirmed! Payment successful. Transaction ID: 550e8400-e29b-41d4-a716-446655440000
================================================================================
```

**Expected Console Output (Failure):**
```
================================================================================
📧 NOTIFICATION TO USER 1
--------------------------------------------------------------------------------
❌ Order #1 cancelled. Payment failed: Payment failed: Insufficient funds
================================================================================
```

---

## 🎬 Demo Scenario 2: Manual Payment Trigger

This scenario shows how to manually trigger payment for an order (useful for testing or retry scenarios).

### Step 1: Create an Order (as before)
```bash
POST {{base_url}}/api/orders
Authorization: Bearer <your_user_token>

{
  "userId": 1,
  "restaurantId": 1,
  "items": [
    {
      "menuItemId": 1,
      "quantity": 1
    }
  ]
}
```

**Response:**
```json
{
  "id": 2,
  "userId": 1,
  "restaurantId": 1,
  "amount": 250.0,
  "status": "PENDING",
  ...
}
```

---

### Step 2: Wait for automatic payment to complete (or skip if testing manual only)
```bash
sleep 3
```

---

### Step 3: Manually Trigger Payment
```bash
POST {{base_url}}/api/payments/process

{
  "orderId": 2,
  "userId": 1,
  "restaurantId": 1,
  "amount": 250.0
}
```

**Expected Response (Success - 90%):**
```json
{
  "orderId": 2,
  "success": true,
  "transactionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "message": "Payment successful"
}
```

**Expected Response (Failure - 10%):**
```json
{
  "orderId": 2,
  "success": false,
  "transactionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567891",
  "message": "Payment failed: Insufficient funds"
}
```

---

### Step 4: Check Order Status Updated
```bash
GET {{base_url}}/api/orders/2
Authorization: Bearer <your_user_token>
```

**Status should be updated to `CONFIRMED` or `CANCELLED` based on payment result**

---

## 🎬 Demo Scenario 3: Payment Validation Errors

### Test 1: Missing Order ID
```bash
POST {{base_url}}/api/payments/process

{
  "userId": 1,
  "restaurantId": 1,
  "amount": 250.0
}
```

**Expected Response:**
```json
{
  "orderId": null,
  "success": false,
  "transactionId": null,
  "message": "Order ID is required"
}
```

---

### Test 2: Invalid Amount
```bash
POST {{base_url}}/api/payments/process

{
  "orderId": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": -100.0
}
```

**Expected Response:**
```json
{
  "orderId": null,
  "success": false,
  "transactionId": null,
  "message": "Valid amount is required"
}
```

---

### Test 3: Duplicate Payment (Idempotency)
```bash
# First payment
POST {{base_url}}/api/payments/process
{
  "orderId": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0
}

# Second payment for same order
POST {{base_url}}/api/payments/process
{
  "orderId": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0
}
```

**Expected Response (Second call):**
```json
{
  "orderId": 1,
  "success": true,
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Payment already processed for this order"
}
```

---

## 🔍 Monitoring & Debugging

### 1. RabbitMQ Management UI
Open in browser:
```
http://localhost:15672
Username: guest
Password: guest
```

**What to Check:**
- **Exchanges**: `orders-exchange`, `payments-exchange`
- **Queues**: `payment-queue`, `payment-result-queue`
- **Message Rates**: See messages being published and consumed in real-time
- **Consumers**: Verify all services are connected

---

### 2. Check Service Logs

#### Order Service
```bash
docker logs order-service -f

# Look for:
# - "Creating order for user X"
# - "Publishing OrderCreatedEvent"
# - "Received payment result for order X: success=true"
# - "Order X status updated successfully"
```

#### Payment Service
```bash
docker logs payment-service -f

# Look for:
# - "Processing payment for order: X"
# - "Payment processed for order X: success=true, txnId=..."
# - "Published payment result event for order X"
```

#### Notification Service
```bash
docker logs notification-service -f

# Look for:
# - "Processing notification for order X: success=true"
# - "📧 [ORDER_CONFIRMED] Notification sent to User X"
# - The formatted notification message
```

---

### 3. Database Verification

#### Check Orders Table
```bash
docker exec -it mysql_order mysql -u admin -ppassword order_db

mysql> SELECT id, user_id, restaurant_id, amount, status, created_at FROM orders;
```

#### Check Payment Records Table
```bash
docker exec -it mysql_payment mysql -u admin -ppassword payment_db

mysql> SELECT id, order_id, success, transaction_id, method, created_at FROM payment_records;
```

#### Check Notifications Table
```bash
docker exec -it mysql_notification mysql -u admin -ppassword notification_db

mysql> SELECT id, order_id, message, sent, created_at FROM notifications;
```

---

## 🎭 Live Demo Script (For Presentation)

### Setup (Before Demo)
```bash
# 1. Start all services
./quick-redeploy.sh

# 2. Open 4 terminal windows:
# Terminal 1: Order Service logs
docker logs order-service -f

# Terminal 2: Payment Service logs
docker logs payment-service -f

# Terminal 3: Notification Service logs
docker logs notification-service -f

# Terminal 4: API calls (using curl or Postman)

# 5. Open RabbitMQ Management UI in browser
open http://localhost:15672
```

---

### Demo Flow (5 minutes)

**[Terminal 4] Create Order**
```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Authorization: Bearer <token>" \
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

**[Say]** "I just created an order for User 1 at Pizza Palace..."

---

**[Point to Terminal 1 - Order Service]**
- "Order Service created the order with PENDING status"
- "Published OrderCreatedEvent to RabbitMQ"

---

**[Point to RabbitMQ UI]**
- "Message routed through orders-exchange to payment-queue"
- "See the message count increasing..."

---

**[Point to Terminal 2 - Payment Service]**
- "Payment Service received the event"
- "Processing payment... simulating payment gateway..."
- "Payment successful! Transaction ID generated"
- "Publishing PaymentResultEvent"

---

**[Point to RabbitMQ UI]**
- "Message routed through payments-exchange to payment-result-queue"
- "Two consumers listening: Order Service and Notification Service"

---

**[Point to Terminal 1 - Order Service]**
- "Order Service received payment result"
- "Updating order status from PENDING to CONFIRMED"

---

**[Point to Terminal 3 - Notification Service]**
- "Notification Service received payment result"
- "Sending notification to User 1..."
- "✅ Order confirmed! Payment successful!"

---

**[Terminal 4] Verify Order Status**
```bash
curl -X GET http://localhost:8080/api/orders/1 \
  -H "Authorization: Bearer <token>"
```

**[Say]** "Order status is now CONFIRMED! The entire flow completed in less than 2 seconds."

---

**[Terminal 4] Manual Payment Demo**
```bash
curl -X POST http://localhost:8080/api/payments/process \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": 2,
    "userId": 1,
    "restaurantId": 1,
    "amount": 250.0
  }'
```

**[Say]** "We can also trigger payments manually for retry scenarios or testing..."

---

## 📊 Success Metrics

After running the demo, you should observe:

✅ **Order Creation**: ~100ms  
✅ **Payment Processing**: 500-1500ms (simulated)  
✅ **Status Update**: ~50ms  
✅ **Notification Sent**: ~100ms  
✅ **Total E2E Time**: < 2 seconds  
✅ **Success Rate**: ~90%  
✅ **Compensation Rate**: ~10% (automatic cancellation)  

---

## 🎯 Key Talking Points

1. **Saga Pattern**: "We use choreography-based saga for distributed transactions"
2. **Event-Driven**: "Services communicate via events, not direct calls - loose coupling"
3. **Fault Tolerance**: "Payment failures automatically trigger compensation"
4. **Idempotency**: "Duplicate payments are prevented"
5. **Async Processing**: "Non-blocking, scalable architecture"
6. **Observability**: "Full audit trail in logs and databases"

---

## 🐛 Troubleshooting

### Issue: Order status not updating
**Check**: 
- Order Service is connected to RabbitMQ
- `payment-result-queue` has consumers
- Check Order Service logs for errors

### Issue: Notification not sent
**Check**:
- Notification Service is running
- Check notification-service logs
- Verify RabbitMQ connection

### Issue: Payment always fails
**Solution**: Payment service uses 90% success rate (random). Create multiple orders to see both success and failure.

---

## 📝 Notes

- Payment success rate: 90% (configurable in `PaymentService.simulatePaymentGateway()`)
- Payment processing delay: 500-1500ms (simulated)
- All events are logged for debugging
- Payment records are persisted regardless of success/failure

---

**🎉 Demo Complete! Questions?**
