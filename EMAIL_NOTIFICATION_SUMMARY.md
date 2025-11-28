# Email Notification System Summary

## Overview
The Notification Service has been enhanced to send real-time email notifications to users for order confirmations and cancellations.

## Features
- **Order Confirmation**: Sends an email when payment is successful and order is confirmed.
- **Order Cancellation**: Sends a polite email when payment fails and order is cancelled.
- **User Integration**: Fetches user email dynamically from the Auth Service.

## Configuration
The service uses Gmail SMTP for sending emails.
- **Host**: `smtp.gmail.com`
- **Port**: `587`
- **Username**: `soumikroychoudhury02@gmail.com`

## Email Templates

### Confirmation Email
```text
Subject: ✅ Order Confirmed - Order #{orderId}

Dear Customer,

Great news! Your order has been confirmed.

Order ID: {orderId}
Transaction ID: {transactionId}
Status: CONFIRMED

Thank you for your order!

Best regards,
Food Ordering Service Team
```

### Cancellation Email
```text
Subject: ❌ Order Cancelled - Order #{orderId}

Dear Customer,

We regret to inform you that we were unable to process your payment for Order #{orderId}.

This could be due to a temporary issue with your payment method or bank.

Order ID: {orderId}
Status: CANCELLED

We recommend trying a different payment method or contacting your bank for more details.

We apologize for the inconvenience and hope to serve you soon.

Best regards,
Food Ordering Service Team
```

## Testing
The system has been verified with end-to-end tests:
1. Created orders via API.
2. Verified `CONFIRMED` orders triggered confirmation emails.
3. Verified `CANCELLED` orders triggered the new polite cancellation email.
