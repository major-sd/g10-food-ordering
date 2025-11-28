package com.foodorder.payment.controller;

import com.foodorder.payment.dto.PaymentRequest;
import com.foodorder.payment.dto.PaymentResponse;
import com.foodorder.payment.service.PaymentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/payments")
public class PaymentController {
    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    /**
     * Manual payment trigger endpoint
     * POST /payments/process
     * Body: { "orderId": 1, "userId": 1, "restaurantId": 1, "amount": 800.0 }
     */
    @PostMapping("/process")
    public ResponseEntity<PaymentResponse> processPayment(@RequestBody PaymentRequest request) {
        // Validate fields
        if (request.getOrderId() == null) {
            return ResponseEntity.badRequest().body(
                new PaymentResponse(null, false, null, "Order ID is required")
            );
        }
        if (request.getUserId() == null) {
            return ResponseEntity.badRequest().body(
                new PaymentResponse(null, false, null, "User ID is required")
            );
        }
        if (request.getRestaurantId() == null) {
            return ResponseEntity.badRequest().body(
                new PaymentResponse(null, false, null, "Restaurant ID is required")
            );
        }
        if (request.getAmount() == null || request.getAmount() <= 0) {
            return ResponseEntity.badRequest().body(
                new PaymentResponse(null, false, null, "Valid amount is required")
            );
        }

        PaymentResponse response = paymentService.processPaymentManually(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Get payment status by order ID
     */
    @GetMapping("/order/{orderId}")
    public ResponseEntity<?> getPaymentByOrderId(@PathVariable Long orderId) {
        return paymentService.getPaymentByOrderId(orderId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
