# Quick Test Commands - Copy & Paste Ready

## Environment Setup
```bash
export BASE_URL="http://localhost:8080"
export USER_TOKEN=""  # Will be filled after login
```

---

## 1️⃣ Register User
```bash
curl -X POST "${BASE_URL}/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@foodorder.com",
    "password": "password123",
    "name": "Demo User",
    "role": "USER"
  }'
```

---

## 2️⃣ Login
```bash
USER_TOKEN=$(curl -X POST "${BASE_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@foodorder.com",
    "password": "password123"
  }' | jq -r '.token')

echo "Token: $USER_TOKEN"
```

---

## 3️⃣ View Restaurants
```bash
curl -X GET "${BASE_URL}/api/restaurants" | jq
```

---

## 4️⃣ View Restaurant Menu (Restaurant ID 1)
```bash
curl -X GET "${BASE_URL}/api/restaurants/1/menu" | jq
```

---

## 5️⃣ Create Order (Start Saga Flow!) 🚀
```bash
ORDER_ID=$(curl -X POST "${BASE_URL}/api/orders" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
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
  }' | jq -r '.id')

echo "Created Order ID: $ORDER_ID"
```

---

## 6️⃣ Wait for Async Processing
```bash
echo "Waiting for payment processing..."
sleep 3
```

---

## 7️⃣ Check Order Status (Should be CONFIRMED or CANCELLED)
```bash
curl -X GET "${BASE_URL}/api/orders/${ORDER_ID}" \
  -H "Authorization: Bearer ${USER_TOKEN}" | jq
```

---

## 8️⃣ Check Payment Record
```bash
curl -X GET "${BASE_URL}/api/payments/order/${ORDER_ID}" | jq
```

---

## 9️⃣ Manual Payment Trigger (Optional)
```bash
curl -X POST "${BASE_URL}/api/payments/process" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": 2,
    "userId": 1,
    "restaurantId": 1,
    "amount": 250.0
  }' | jq
```

---

## 🔍 Monitor Services

### Order Service Logs
```bash
docker logs order-service -f --tail 50
```

### Payment Service Logs
```bash
docker logs payment-service -f --tail 50
```

### Notification Service Logs
```bash
docker logs notification-service -f --tail 50
```

### RabbitMQ Management UI
```bash
open http://localhost:15672
# Username: guest
# Password: guest
```

---

## 🗄️ Database Queries

### Check Orders
```bash
docker exec -it mysql_order mysql -u admin -ppassword order_db \
  -e "SELECT id, user_id, restaurant_id, amount, status, created_at FROM orders ORDER BY id DESC LIMIT 5;"
```

### Check Payments
```bash
docker exec -it mysql_payment mysql -u admin -ppassword payment_db \
  -e "SELECT id, order_id, success, transaction_id, method, created_at FROM payment_records ORDER BY id DESC LIMIT 5;"
```

### Check Notifications
```bash
docker exec -it mysql_notification mysql -u admin -ppassword notification_db \
  -e "SELECT id, order_id, message, sent, created_at FROM notifications ORDER BY id DESC LIMIT 5;"
```

---

## 🎯 Complete Flow in One Script

```bash
#!/bin/bash
set -e

BASE_URL="http://localhost:8080"

echo "🔐 Step 1: Login..."
USER_TOKEN=$(curl -s -X POST "${BASE_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@foodorder.com",
    "password": "password123"
  }' | jq -r '.token')

echo "✅ Token: ${USER_TOKEN:0:20}..."

echo ""
echo "🍕 Step 2: View restaurants..."
curl -s -X GET "${BASE_URL}/api/restaurants" | jq -r '.[] | "\(.id): \(.name) - \(.address)"'

echo ""
echo "📋 Step 3: View menu for Restaurant 1..."
curl -s -X GET "${BASE_URL}/api/restaurants/1/menu" | jq -r '.[] | "\(.id): \(.name) - ₹\(.price)"'

echo ""
echo "🛒 Step 4: Creating order..."
ORDER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/orders" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "restaurantId": 1,
    "items": [
      {"menuItemId": 1, "quantity": 2},
      {"menuItemId": 2, "quantity": 1}
    ]
  }')

ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.id')
ORDER_AMOUNT=$(echo $ORDER_RESPONSE | jq -r '.amount')
echo "✅ Order created: ID=$ORDER_ID, Amount=₹$ORDER_AMOUNT, Status=PENDING"

echo ""
echo "⏳ Step 5: Waiting for payment processing (3 seconds)..."
sleep 3

echo ""
echo "✅ Step 6: Checking order status..."
ORDER_STATUS=$(curl -s -X GET "${BASE_URL}/api/orders/${ORDER_ID}" \
  -H "Authorization: Bearer ${USER_TOKEN}" | jq -r '.status')
echo "Order Status: $ORDER_STATUS"

echo ""
echo "💳 Step 7: Checking payment record..."
PAYMENT=$(curl -s -X GET "${BASE_URL}/api/payments/order/${ORDER_ID}")
PAYMENT_SUCCESS=$(echo $PAYMENT | jq -r '.success')
PAYMENT_TXN=$(echo $PAYMENT | jq -r '.transactionId')

if [ "$PAYMENT_SUCCESS" == "true" ]; then
  echo "✅ Payment Successful!"
  echo "   Transaction ID: $PAYMENT_TXN"
  echo "   Order Status: $ORDER_STATUS"
else
  echo "❌ Payment Failed"
  echo "   Order Status: $ORDER_STATUS (Automatically Cancelled)"
fi

echo ""
echo "🎉 Demo Complete!"
echo ""
echo "📊 Summary:"
echo "   Order ID: $ORDER_ID"
echo "   Amount: ₹$ORDER_AMOUNT"
echo "   Payment: $PAYMENT_SUCCESS"
echo "   Status: $ORDER_STATUS"
echo "   Transaction: $PAYMENT_TXN"
```

**Save as:** `run_demo.sh` and execute:
```bash
chmod +x run_demo.sh
./run_demo.sh
```

---

## 🎪 Live Demo One-Liner

```bash
# Complete flow in one command (after login)
ORDER_ID=$(curl -s -X POST "http://localhost:8080/api/orders" -H "Authorization: Bearer $USER_TOKEN" -H "Content-Type: application/json" -d '{"userId":1,"restaurantId":1,"items":[{"menuItemId":1,"quantity":2}]}' | jq -r '.id') && sleep 3 && echo "Order Status:" && curl -s "http://localhost:8080/api/orders/$ORDER_ID" -H "Authorization: Bearer $USER_TOKEN" | jq '.status' && echo "Payment:" && curl -s "http://localhost:8080/api/payments/order/$ORDER_ID" | jq '{success,transactionId}'
```
