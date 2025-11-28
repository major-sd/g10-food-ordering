# Order Flow Documentation

## Overview
This document explains how orders are processed in the food ordering system after they are created in PENDING state.

## Complete Order Flow

### 1️⃣ **Order Creation** (Order Service)

**Endpoint:** `POST /orders`

**Process:**
1. User sends order request with restaurant ID and menu items
2. Order Service validates menu items by calling Restaurant Service
3. Order Service calculates total amount based on menu item prices
4. Order is created with status `PENDING` and saved to database
5. `OrderCreatedEvent` is published to RabbitMQ

**Code Location:** `order-service/src/main/java/com/foodorder/order/service/OrderService.java`

```java
// Order is created with PENDING status
order.setStatus(OrderStatus.PENDING);
OrderEntity savedOrder = orderRepository.save(order);

// Event is published to trigger payment processing
OrderCreatedEvent event = new OrderCreatedEvent();
event.setOrderId(savedOrder.getId());
event.setUserId(savedOrder.getUserId());
event.setRestaurantId(savedOrder.getRestaurantId());
event.setAmount(savedOrder.getAmount());

rabbitTemplate.convertAndSend("orders-exchange", "order.created", event);
```

**RabbitMQ Configuration:**
- **Exchange:** `orders-exchange` (TopicExchange)
- **Routing Key:** `order.created`

---

### 2️⃣ **Payment Processing** (Payment Service)

**Trigger:** Listens to `payment-queue` which is bound to `orders-exchange` with routing key `order.created`

**Process:**
1. `PaymentListener` receives `OrderCreatedEvent`
2. Payment Service processes payment (simulates payment gateway with 90% success rate)
3. Payment record is saved to database
4. `PaymentResultEvent` is published to RabbitMQ

**Code Location:** `payment-service/src/main/java/com/foodorder/payment/listener/PaymentListener.java`

```java
@RabbitListener(queues = "payment-queue")
public void handleOrderCreated(OrderCreatedEvent event) {
    paymentService.processPayment(event);
}
```

**Payment Service Logic:** `payment-service/src/main/java/com/foodorder/payment/service/PaymentService.java`

```java
// Simulate payment processing (90% success rate)
boolean success = simulatePaymentGateway();
String transactionId = UUID.randomUUID().toString();

// Save payment record
PaymentRecord paymentRecord = createPaymentRecord(
    event.getOrderId(), 
    success, 
    transactionId, 
    "CARD"
);

// Publish result back to Order Service
publishPaymentResult(
    event.getOrderId(), 
    event.getUserId(),
    success, 
    transactionId, 
    reason
);
```

**RabbitMQ Configuration:**
- **Input Queue:** `payment-queue` (bound to `orders-exchange` with `order.created`)
- **Output Exchange:** `payments-exchange` (TopicExchange)
- **Output Routing Key:** `payment.result`

---

### 3️⃣ **Order Status Update** (Order Service)

**Trigger:** Listens to `payment-result-queue` which is bound to `payments-exchange` with routing key `payment.result`

**Process:**
1. `PaymentResultListener` receives `PaymentResultEvent`
2. Order is retrieved from database
3. Order status is updated based on payment result:
   - **Success:** Status → `CONFIRMED`
   - **Failure:** Status → `CANCELLED` (compensation/rollback)
4. Updated order is saved to database

**Code Location:** `order-service/src/main/java/com/foodorder/order/listener/PaymentResultListener.java`

```java
@RabbitListener(queues = "payment-result-queue")
@Transactional
public void handlePaymentResult(PaymentResultEvent event) {
    OrderEntity order = orderRepository.findById(event.getOrderId())
            .orElseThrow(() -> new RuntimeException("Order not found: " + event.getOrderId()));

    if (event.isSuccess()) {
        // Payment successful - update order status to CONFIRMED
        order.setStatus(OrderStatus.CONFIRMED);
        logger.info("Order {} payment successful. Status updated to CONFIRMED. TxnId: {}",
                event.getOrderId(), event.getTransactionId());
    } else {
        // Payment failed - update order status to CANCELLED (compensation)
        order.setStatus(OrderStatus.CANCELLED);
        logger.warn("Order {} payment failed. Status updated to CANCELLED. Reason: {}",
                event.getOrderId(), event.getReason());
    }

    orderRepository.save(order);
}
```

**RabbitMQ Configuration:**
- **Input Queue:** `payment-result-queue` (bound to `payments-exchange` with `payment.result`)

---

## Order Status States

```
PENDING → Order created, waiting for payment
    ↓
    ├─→ CONFIRMED (Payment successful)
    └─→ CANCELLED (Payment failed - compensation)
```

---

## RabbitMQ Architecture

### Exchanges
1. **orders-exchange** (TopicExchange)
   - Used by Order Service to publish order creation events
   
2. **payments-exchange** (TopicExchange)
   - Used by Payment Service to publish payment results

### Queues
1. **payment-queue**
   - Bound to: `orders-exchange` with routing key `order.created`
   - Consumer: Payment Service
   
2. **payment-result-queue**
   - Bound to: `payments-exchange` with routing key `payment.result`
   - Consumer: Order Service

3. **notification-payment-result-queue**
   - Bound to: `payments-exchange` with routing key `payment.result`
   - Consumer: Notification Service
   - *Note: Separate queue ensures both Order and Notification services receive the event (Pub/Sub)*

### Message Flow Diagram

```
Order Service                    Payment Service
     |                                 |
     | 1. Create Order (PENDING)       |
     |                                 |
     | 2. Publish OrderCreatedEvent    |
     |─────────────────────────────────>|
     |   (orders-exchange,              |
     |    order.created)                |
     |                                 |
     |                          3. Process Payment
     |                                 |
     |                          4. Save PaymentRecord
     |                                 |
     | 5. Receive PaymentResultEvent   |
     |<─────────────────────────────────|
     |   (payments-exchange,            |
     |    payment.result)               |
     |                                 |
     | 6. Update Order Status           |
     |    (CONFIRMED/CANCELLED)         |
     |                                 |
```

---

## Event DTOs

### OrderCreatedEvent
```java
public class OrderCreatedEvent {
    public Long orderId;
    public Long userId;
    public Long restaurantId;
    public double amount;
}
```

### PaymentResultEvent
```java
public class PaymentResultEvent {
    public Long orderId;
    public Long userId;
    public boolean success;
    public String transactionId;
    public String reason;
}
```

---

## Testing the Flow

### 1. Create an Order
```bash
curl -X POST http://localhost:8083/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
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

**Expected Response:**
```json
{
  "id": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 25.98,
  "status": "PENDING",
  "createdAt": "2025-11-28T23:22:59",
  "items": [...]
}
```

### 2. Check Order Status (after a few seconds)
```bash
curl http://localhost:8083/orders/1 \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

**Expected Response (if payment succeeded):**
```json
{
  "id": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 25.98,
  "status": "CONFIRMED",  // ✅ Status updated!
  "createdAt": "2025-11-28T23:22:59",
  "items": [...]
}
```

**Expected Response (if payment failed - 10% chance):**
```json
{
  "id": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 25.98,
  "status": "CANCELLED",  // ❌ Status updated to cancelled
  "createdAt": "2025-11-28T23:22:59",
  "items": [...]
}
```

---

## Troubleshooting

### Issue: Order stays in PENDING state

**Possible Causes:**

1. **RabbitMQ not running**
   - Check: `docker ps | grep rabbitmq`
   - Solution: Start RabbitMQ container

2. **Payment Service not running**
   - Check: `curl http://localhost:8084/health`
   - Solution: Start payment service

3. **Queue bindings not created**
   - Check RabbitMQ Management UI: http://localhost:15672
   - Verify exchanges and queue bindings exist

4. **Listener not registered (FIXED)**
   - The `PaymentResultListener` had incorrect package declaration
   - Fixed: Changed from `package main.java.com.foodorder.order.listener;` to `package com.foodorder.order.listener;`

### Monitoring Logs

**Order Service Logs:**
```bash
docker logs -f order-service
```

Look for:
- `Publishing OrderCreatedEvent for order: X`
- `Received payment result for order X: success=true/false`
- `Order X status updated successfully`

**Payment Service Logs:**
```bash
docker logs -f payment-service
```

Look for:
- `Processing payment for order: X`
- `Payment processed for order X: success=true/false`
- `Published payment result event for order X`

---

## Key Design Patterns

### 1. **Event-Driven Architecture**
- Services communicate asynchronously via events
- Loose coupling between Order and Payment services

### 2. **Saga Pattern (Choreography)**
- Distributed transaction across Order and Payment services
- Each service listens to events and performs its part
- Compensation logic: Order is cancelled if payment fails

### 3. **Message Queue (RabbitMQ)**
- Reliable message delivery
- Decouples services
- Enables scalability

### 4. **Eventual Consistency**
- Order status is eventually consistent with payment result
- Small delay between order creation and status update

---

## Future Enhancements

1. **Dead Letter Queue (DLQ)**
   - Handle failed message processing
   - Retry mechanism for transient failures

2. **Idempotency**
   - Prevent duplicate payment processing
   - Already implemented: Payment Service checks for existing payment

3. **Timeout Handling**
   - Cancel order if payment doesn't complete within X minutes
   - Scheduled job to check PENDING orders

4. **Notification Service**
   - Send email/SMS when order is confirmed/cancelled
   - Listen to payment-result events

5. **Order Tracking**
   - Add more states: PREPARING, OUT_FOR_DELIVERY, DELIVERED
   - Integrate with restaurant and delivery services

---

## Configuration Files

### Order Service - application.properties
```properties
spring.rabbitmq.host=rabbitmq
spring.rabbitmq.port=5672
spring.rabbitmq.username=guest
spring.rabbitmq.password=guest
```

### Payment Service - application.properties
```properties
spring.rabbitmq.host=rabbitmq
spring.rabbitmq.port=5672
spring.rabbitmq.username=guest
spring.rabbitmq.password=guest
```

---

## Summary

The order flow is a **choreography-based saga** where:

1. ✅ Order Service creates order in PENDING state
2. ✅ Payment Service processes payment automatically
3. ✅ Order Service updates status based on payment result
4. ✅ Compensation (CANCELLED) happens if payment fails

**The main issue was fixed:** Incorrect package declaration in `PaymentResultListener.java` prevented the listener from being registered by Spring, causing orders to stay in PENDING state indefinitely.
