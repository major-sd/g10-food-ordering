# 🎯 Saga Pattern Flow - Sequence Diagram

## Visual Flow Representation

```
┌────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌──────────┐
│ Client │   │ Order   │   │ Payment │   │ Notif.  │   │ RabbitMQ │
│        │   │ Service │   │ Service │   │ Service │   │          │
└───┬────┘   └────┬────┘   └────┬────┘   └────┬────┘   └────┬─────┘
    │             │             │             │             │
    │ POST /orders│             │             │             │
    ├────────────>│             │             │             │
    │             │             │             │             │
    │             │ Create Order│             │             │
    │             │ (PENDING)   │             │             │
    │             │             │             │             │
    │<────────────┤             │             │             │
    │ 201 Created │             │             │             │
    │ {id:1, ...} │             │             │             │
    │             │             │             │             │
    │             │ Publish     │             │             │
    │             │ OrderCreated│             │             │
    │             │ Event       │             │             │
    │             ├────────────────────────────────────────>│
    │             │             │             │             │
    │             │             │             │   orders-exchange
    │             │             │             │   ↓
    │             │             │             │   payment-queue
    │             │             │             │             │
    │             │             │ Consume     │             │
    │             │             │ Event       │             │
    │             │             │<────────────────────────────┤
    │             │             │             │             │
    │             │             │ Process     │             │
    │             │             │ Payment     │             │
    │             │             │ (90% ✅)    │             │
    │             │             │             │             │
    │             │             │ Save Payment│             │
    │             │             │ Record      │             │
    │             │             │             │             │
    │             │             │ Publish     │             │
    │             │             │ PaymentResult             │
    │             │             │ Event       │             │
    │             │             ├────────────────────────────>│
    │             │             │             │             │
    │             │             │             │   payments-exchange
    │             │             │             │   ↓
    │             │             │             │   payment-result-queue
    │             │             │             │   (Fanout to 2 consumers)
    │             │             │             │             │
    │             │ Consume     │             │             │
    │             │ PaymentResult             │             │
    │             │<────────────────────────────────────────┤
    │             │             │             │             │
    │             │ Update Order│             │             │
    │             │ Status:     │             │             │
    │             │ PENDING →   │             │             │
    │             │ CONFIRMED ✅│             │             │
    │             │             │             │             │
    │             │             │             │ Consume     │
    │             │             │             │ PaymentResult
    │             │             │             │<─────────────┤
    │             │             │             │             │
    │             │             │             │ Save Notif. │
    │             │             │             │             │
    │             │             │             │ Send to User│
    │             │             │             │ 📧 "Order   │
    │             │             │             │  Confirmed!"│
    │             │             │             │             │
    │             │             │             │             │
    │ GET /orders/1             │             │             │
    ├────────────>│             │             │             │
    │             │             │             │             │
    │<────────────┤             │             │             │
    │ 200 OK      │             │             │             │
    │ status:     │             │             │             │
    │ "CONFIRMED" │             │             │             │
    │             │             │             │             │
```

---

## Compensation Flow (Payment Failure - 10%)

```
┌────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌──────────┐
│ Client │   │ Order   │   │ Payment │   │ Notif.  │   │ RabbitMQ │
│        │   │ Service │   │ Service │   │ Service │   │          │
└───┬────┘   └────┬────┘   └────┬────┘   └────┬────┘   └────┬─────┘
    │             │             │             │             │
    │ POST /orders│             │             │             │
    ├────────────>│             │             │             │
    │             │             │             │             │
    │             │ Create Order│             │             │
    │             │ (PENDING)   │             │             │
    │             │             │             │             │
    │<────────────┤             │             │             │
    │ 201 Created │             │             │             │
    │             │             │             │             │
    │             │ Publish     │             │             │
    │             │ OrderCreated│             │             │
    │             ├────────────────────────────────────────>│
    │             │             │             │             │
    │             │             │ Consume     │             │
    │             │             │<────────────────────────────┤
    │             │             │             │             │
    │             │             │ Process     │             │
    │             │             │ Payment     │             │
    │             │             │ (10% ❌)    │             │
    │             │             │ FAILED!     │             │
    │             │             │             │             │
    │             │             │ Save Payment│             │
    │             │             │ Record      │             │
    │             │             │ (success=   │             │
    │             │             │  false)     │             │
    │             │             │             │             │
    │             │             │ Publish     │             │
    │             │             │ PaymentResult             │
    │             │             │ (success=   │             │
    │             │             │  false)     │             │
    │             │             ├────────────────────────────>│
    │             │             │             │             │
    │             │ Consume     │             │             │
    │             │<────────────────────────────────────────┤
    │             │             │             │             │
    │             │ 🔄 COMPENSATION!          │             │
    │             │ Update Order│             │             │
    │             │ Status:     │             │             │
    │             │ PENDING →   │             │             │
    │             │ CANCELLED ❌│             │             │
    │             │             │             │             │
    │             │             │             │ Consume     │
    │             │             │             │<─────────────┤
    │             │             │             │             │
    │             │             │             │ Save Notif. │
    │             │             │             │             │
    │             │             │             │ Send to User│
    │             │             │             │ 📧 "Order   │
    │             │             │             │  Cancelled" │
    │             │             │             │             │
    │ GET /orders/1             │             │             │
    ├────────────>│             │             │             │
    │             │             │             │             │
    │<────────────┤             │             │             │
    │ 200 OK      │             │             │             │
    │ status:     │             │             │             │
    │ "CANCELLED" │             │             │             │
    │             │             │             │             │
```

---

## Manual Payment Flow

```
┌────────┐   ┌─────────┐   ┌─────────┐   ┌──────────┐
│ Client │   │ Payment │   │ Order   │   │ RabbitMQ │
│        │   │ Service │   │ Service │   │          │
└───┬────┘   └────┬────┘   └────┬────┘   └────┬─────┘
    │             │             │             │
    │ POST        │             │             │
    │ /payments/  │             │             │
    │ process     │             │             │
    ├────────────>│             │             │
    │             │             │             │
    │             │ Check if    │             │
    │             │ payment     │             │
    │             │ exists      │             │
    │             │             │             │
    │             │ Process     │             │
    │             │ Payment     │             │
    │             │             │             │
    │             │ Save Record │             │
    │             │             │             │
    │             │ Publish     │             │
    │             │ PaymentResult             │
    │             ├────────────────────────────>│
    │             │             │             │
    │             │             │ Consume     │
    │             │             │<─────────────┤
    │             │             │             │
    │             │             │ Update Order│
    │             │             │ Status      │
    │             │             │             │
    │<────────────┤             │             │
    │ 200 OK      │             │             │
    │ {success:   │             │             │
    │  true, ...} │             │             │
    │             │             │             │
```

---

## State Transitions

```
Order Lifecycle:
┌─────────┐
│ PENDING │ ← Initial state when order is created
└────┬────┘
     │
     │ Payment Processing...
     │
     ├─────────────┬─────────────┐
     │             │             │
     ▼             ▼             ▼
┌──────────┐  ┌─────────┐  ┌─────────┐
│CONFIRMED │  │CANCELLED│  │ PENDING │
│  (90%)   │  │  (10%)  │  │(if error)│
└──────────┘  └─────────┘  └─────────┘
   ✅             ❌             ⏳
 Payment       Payment       Payment
 Success       Failed        Retry
```

---

## Message Flow Timing

```
Time →

0ms:    Client sends POST /orders
        ↓
50ms:   Order Service creates order (PENDING)
        ↓
100ms:  Order Service publishes OrderCreatedEvent
        ↓
150ms:  Payment Service receives event
        ↓
500ms:  Payment Service processes payment (simulated delay)
        ↓
1500ms: Payment Service publishes PaymentResultEvent
        ↓
1550ms: Order Service receives PaymentResultEvent
        ↓
1600ms: Order Service updates status → CONFIRMED/CANCELLED
        ↓
1650ms: Notification Service receives PaymentResultEvent
        ↓
1700ms: Notification Service sends notification
        ↓
1750ms: Client queries GET /orders/{id} → sees updated status

Total: ~1.75 seconds (end-to-end)
```

---

## RabbitMQ Topology

```
                 ┌──────────────────┐
                 │ orders-exchange  │
                 │   (TopicExchange)│
                 └────────┬─────────┘
                          │
         Routing Key: order.created
                          │
                          ▼
                 ┌────────────────┐
                 │ payment-queue  │
                 └────────┬───────┘
                          │
                 Consumer: Payment Service
                          
                          
                 ┌──────────────────────┐
                 │ payments-exchange    │
                 │   (TopicExchange)    │
                 └──────────┬───────────┘
                            │
          Routing Key: payment.result
                            │
                            ▼
                 ┌──────────────────────┐
                 │ payment-result-queue │
                 └──────────┬───────────┘
                            │
               ┌────────────┴────────────┐
               │                         │
        Consumer:                  Consumer:
    Order Service              Notification Service
```

---

## Error Handling & Compensation

```
┌─────────────────┐
│ Payment Fails   │
└────────┬────────┘
         │
         ▼
┌────────────────────────────┐
│ Publish PaymentResultEvent │
│ with success=false         │
└────────┬───────────────────┘
         │
         ├────────────────┬────────────────┐
         │                │                │
         ▼                ▼                ▼
┌────────────────┐  ┌──────────────┐  ┌──────────────┐
│ Order Service  │  │ Notification │  │ Audit Log    │
│ Cancels Order  │  │ Sends Alert  │  │ Records      │
└────────────────┘  └──────────────┘  └──────────────┘
         │
         ▼
┌─────────────────┐
│ Compensation    │
│ Complete ✅     │
└─────────────────┘
```

---

## Key Design Patterns Used

1. **Saga Pattern (Choreography)**
   - Each service publishes events
   - Other services react independently
   - No central orchestrator

2. **Event Sourcing**
   - All state changes via events
   - Audit trail automatically maintained
   - Can replay events if needed

3. **Compensation Transaction**
   - Payment failure → Order cancellation
   - Automatic rollback of business transaction

4. **Idempotency**
   - Duplicate payment requests detected
   - Same result returned without re-processing

5. **Eventual Consistency**
   - Order status eventually becomes consistent
   - Acceptable delay (< 2 seconds)

6. **Publisher-Subscriber (Pub-Sub)**
   - One event → Multiple consumers
   - Loose coupling between services

---

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| Order Creation | ~50ms | Synchronous DB write |
| Event Publishing | ~50ms | RabbitMQ publish |
| Payment Processing | 500-1500ms | Simulated (configurable) |
| Status Update | ~50ms | Synchronous DB write |
| Notification | ~100ms | Async, non-blocking |
| **Total E2E** | **< 2 seconds** | Mostly payment simulation |

---

## Scalability Considerations

```
Load: 1000 orders/second

┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│Order Service │       │Order Service │       │Order Service │
│  Instance 1  │       │  Instance 2  │       │  Instance 3  │
└──────┬───────┘       └──────┬───────┘       └──────┬───────┘
       │                      │                      │
       └──────────────────────┼──────────────────────┘
                              │
                         RabbitMQ
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
┌──────▼───────┐       ┌──────▼───────┐       ┌──────▼───────┐
│Payment Svc   │       │Payment Svc   │       │Payment Svc   │
│  Instance 1  │       │  Instance 2  │       │  Instance 3  │
└──────────────┘       └──────────────┘       └──────────────┘

Each instance consumes from the same queue → Load balanced automatically
```

---

**📝 Note:** This is a simplified representation. In production, you'd also need:
- Dead Letter Queues (DLQ)
- Retry mechanisms
- Circuit breakers
- Distributed tracing
- Monitoring & alerting
