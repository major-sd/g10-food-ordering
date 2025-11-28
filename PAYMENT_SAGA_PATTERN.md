# Payment Saga Pattern Implementation

## Overview
This implementation uses the **Choreography-based Saga pattern** with RabbitMQ for distributed transaction management in the food ordering system.

## Architecture Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌─────────────────────┐
│   Client    │────▶│ Order Service│────▶│Payment Service  │────▶│Notification Service │
└─────────────┘     └──────────────┘     └─────────────────┘     └─────────────────────┘
                           │                     │                          │
                           │  OrderCreatedEvent  │                          │
                           │────────────────────▶│                          │
                           │                     │   PaymentResultEvent     │
                           │◀────────────────────│─────────────────────────▶│
                           │                     │                          │
                      Update Order           Save Payment              Send Notification
                       Status                   Record                  to User
```

## Saga Steps

### 1. **Order Creation** (Order Service)
- **Endpoint**: `POST /orders`
- **Action**: Creates order with status `PENDING`
- **Event Published**: `OrderCreatedEvent` → `orders-exchange` → `order.created`
- **Queue**: `payment-queue` consumes the event

### 2. **Payment Processing** (Payment Service)
- **Trigger**: Receives `OrderCreatedEvent` from `payment-queue`
- **Action**: 
  - Simulates payment gateway (90% success rate)
  - Saves payment record to database
  - Handles failures gracefully
- **Event Published**: `PaymentResultEvent` → `payments-exchange` → `payment.result`
- **Queues**: 
  - `payment-result-queue` (Order Service listens)
  - `payment-result-queue` (Notification Service listens)

### 3. **Order Status Update** (Order Service)
- **Trigger**: Receives `PaymentResultEvent` from `payment-result-queue`
- **Action**:
  - If payment **success** → Order status: `PENDING` → `CONFIRMED`
  - If payment **failed** → Order status: `PENDING` → `CANCELLED` (Compensation)
- **Compensation**: Automatically cancels order on payment failure

### 4. **User Notification** (Notification Service)
- **Trigger**: Receives `PaymentResultEvent` from `payment-result-queue`
- **Action**:
  - Saves notification to database
  - Sends notification to user (console log in dev)
  - Success: "✅ Order #X confirmed! Payment successful."
  - Failure: "❌ Order #X cancelled. Payment failed: Insufficient funds"

## Manual Payment Trigger

### Endpoint: `POST /payments/process`

**Request Body:**
```json
{
  "orderId": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0
}
```

**Success Response (90% probability):**
```json
{
  "orderId": 1,
  "success": true,
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Payment successful"
}
```

**Failure Response (10% probability):**
```json
{
  "orderId": 1,
  "success": false,
  "transactionId": "550e8400-e29b-41d4-a716-446655440001",
  "message": "Payment failed: Insufficient funds"
}
```

### Field Validation
- **orderId**: Required (must exist)
- **userId**: Required
- **restaurantId**: Required
- **amount**: Required (must be > 0)

### Get Payment Status
**Endpoint**: `GET /payments/order/{orderId}`

**Response:**
```json
{
  "id": 1,
  "orderId": 1,
  "success": true,
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "method": "CARD",
  "createdAt": "2025-11-28T12:34:56.789"
}
```

## Error Handling & Compensation

### Payment Failure Scenarios
1. **Insufficient Funds** (90% → 10% simulated)
2. **Payment Gateway Timeout**
3. **Invalid Payment Details**
4. **Network Errors**

### Compensation Actions
When payment fails:
1. ❌ Payment Service publishes `PaymentResultEvent` with `success=false`
2. ❌ Order Service receives event and updates order status to `CANCELLED`
3. ❌ Notification Service sends cancellation notification to user
4. ✅ System maintains data consistency

### Idempotency
- Payment Service checks if payment already exists for an order
- Prevents duplicate payment processing
- Returns existing payment record if already processed

## RabbitMQ Configuration

### Exchanges
- `orders-exchange` (TopicExchange) - Order events
- `payments-exchange` (TopicExchange) - Payment events

### Queues
- `payment-queue` - Payment Service consumes OrderCreatedEvent
- `payment-result-queue` - Order & Notification Services consume PaymentResultEvent

### Routing Keys
- `order.created` - Routes to payment-queue
- `payment.result` - Routes to payment-result-queue

## Testing the Flow

### 1. Create an Order
```bash
POST {{base_url}}/api/orders
Authorization: Bearer <user_token>

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

**Response:**
```json
{
  "id": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0,
  "status": "PENDING",
  "createdAt": "2025-11-28T07:15:24.49562",
  "items": [...]
}
```

### 2. Automatic Payment Processing
- Payment Service automatically receives the OrderCreatedEvent
- Processes payment (90% success rate)
- Publishes PaymentResultEvent

### 3. (Optional) Manual Payment Trigger
```bash
POST {{base_url}}/api/payments/process

{
  "orderId": 1,
  "userId": 1,
  "restaurantId": 1,
  "amount": 800.0
}
```

### 4. Check Order Status
```bash
GET {{base_url}}/api/orders/1
```

**Response (Success):**
```json
{
  "id": 1,
  "status": "CONFIRMED",
  ...
}
```

**Response (Failure):**
```json
{
  "id": 1,
  "status": "CANCELLED",
  ...
}
```

### 5. Check Payment Record
```bash
GET {{base_url}}/api/payments/order/1
```

### 6. Check Notification Logs
Look for console output:
```
================================================================================
📧 NOTIFICATION TO USER 1
--------------------------------------------------------------------------------
✅ Order #1 confirmed! Payment successful. Transaction ID: 550e8400...
================================================================================
```

## Benefits of This Implementation

✅ **Loose Coupling**: Services communicate via events, not direct calls  
✅ **Fault Tolerance**: Graceful handling of payment failures  
✅ **Automatic Compensation**: Orders automatically cancelled on payment failure  
✅ **Idempotency**: Duplicate payment prevention  
✅ **Auditability**: All events logged and payment records stored  
✅ **Scalability**: Services can scale independently  
✅ **Consistency**: Eventually consistent across all services  

## Production Considerations

1. **Dead Letter Queues (DLQ)**: Handle unprocessable messages
2. **Retry Mechanism**: Exponential backoff for transient failures
3. **Circuit Breaker**: Prevent cascading failures
4. **Distributed Tracing**: Track transactions across services (Zipkin/Jaeger)
5. **Monitoring**: Alert on high failure rates
6. **Real Notifications**: Integrate SMS/Email/Push services
7. **Payment Gateway Integration**: Replace simulation with real gateway (Stripe, Razorpay)

## Deployment

1. Build all services:
```bash
./quick-redeploy.sh
```

2. Verify RabbitMQ is running:
```bash
docker ps | grep rabbitmq
```

3. Access RabbitMQ Management UI:
```
http://localhost:15672
Username: guest
Password: guest
```

4. Check exchanges and queues are created automatically
