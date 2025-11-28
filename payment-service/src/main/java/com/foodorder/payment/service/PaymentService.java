package com.foodorder.payment.service;

import com.foodorder.payment.dto.*;
import com.foodorder.payment.model.PaymentRecord;
import com.foodorder.payment.repository.PaymentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class PaymentService {
    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);
    
    private final PaymentRepository paymentRepository;
    private final RabbitTemplate rabbitTemplate;

    public PaymentService(PaymentRepository paymentRepository, RabbitTemplate rabbitTemplate) {
        this.paymentRepository = paymentRepository;
        this.rabbitTemplate = rabbitTemplate;
    }

    /**
     * Process payment automatically when OrderCreatedEvent is received
     */
    @Transactional
    public void processPayment(OrderCreatedEvent event) {
        logger.info("Processing payment for order: {}", event.getOrderId());
        
        try {
            // Simulate payment processing (90% success rate)
            boolean success = simulatePaymentGateway();
            String transactionId = UUID.randomUUID().toString();
            String reason = success ? "Payment successful" : "Payment failed: Insufficient funds";

            // Save payment record
            PaymentRecord paymentRecord = createPaymentRecord(
                event.getOrderId(), 
                success, 
                transactionId, 
                "CARD"
            );

            // Publish PaymentResultEvent to update order and notify user
            publishPaymentResult(
                event.getOrderId(), 
                event.getUserId(),
                success, 
                transactionId, 
                reason
            );
            
            logger.info("Payment processed for order {}: success={}, txnId={}", 
                event.getOrderId(), success, transactionId);
                
        } catch (Exception e) {
            logger.error("Error processing payment for order {}: {}", event.getOrderId(), e.getMessage(), e);
            
            // Publish failure event to trigger compensation
            publishPaymentResult(
                event.getOrderId(), 
                event.getUserId(),
                false, 
                null, 
                "Payment processing error: " + e.getMessage()
            );
        }
    }

    /**
     * Process payment manually via REST API
     */
    @Transactional
    public PaymentResponse processPaymentManually(PaymentRequest request) {
        logger.info("Manual payment processing for order: {}", request.getOrderId());
        
        try {
            // Check if payment already exists for this order
            Optional<PaymentRecord> existingPayment = paymentRepository.findByOrderId(request.getOrderId());
            if (existingPayment.isPresent()) {
                PaymentRecord existing = existingPayment.get();
                return new PaymentResponse(
                    existing.getOrderId(),
                    existing.getSuccess(),
                    existing.getTransactionId(),
                    "Payment already processed for this order"
                );
            }

            // Simulate payment processing
            boolean success = simulatePaymentGateway();
            String transactionId = UUID.randomUUID().toString();
            String message = success ? "Payment successful" : "Payment failed: Insufficient funds";

            // Save payment record
            PaymentRecord paymentRecord = createPaymentRecord(
                request.getOrderId(), 
                success, 
                transactionId, 
                "CARD"
            );

            // Publish PaymentResultEvent
            publishPaymentResult(
                request.getOrderId(), 
                request.getUserId(),
                success, 
                transactionId, 
                message
            );

            logger.info("Manual payment processed for order {}: success={}", request.getOrderId(), success);
            
            return new PaymentResponse(
                request.getOrderId(),
                success,
                transactionId,
                message
            );
            
        } catch (Exception e) {
            logger.error("Error in manual payment processing for order {}: {}", 
                request.getOrderId(), e.getMessage(), e);
                
            return new PaymentResponse(
                request.getOrderId(),
                false,
                null,
                "Payment processing error: " + e.getMessage()
            );
        }
    }

    /**
     * Get payment record by order ID
     */
    public Optional<PaymentRecord> getPaymentByOrderId(Long orderId) {
        return paymentRepository.findByOrderId(orderId);
    }

    /**
     * Simulate payment gateway (90% success rate)
     */
    private boolean simulatePaymentGateway() {
        // Simulate processing delay
        try {
            Thread.sleep(ThreadLocalRandom.current().nextInt(500, 1500));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        return ThreadLocalRandom.current().nextInt(100) < 90;
    }

    /**
     * Create and save payment record
     */
    private PaymentRecord createPaymentRecord(Long orderId, boolean success, 
                                             String transactionId, String method) {
        PaymentRecord paymentRecord = new PaymentRecord();
        paymentRecord.setOrderId(orderId);
        paymentRecord.setSuccess(success);
        paymentRecord.setTransactionId(transactionId);
        paymentRecord.setMethod(method);
        return paymentRepository.save(paymentRecord);
    }

    /**
     * Publish payment result event to RabbitMQ
     */
    private void publishPaymentResult(Long orderId, Long userId, boolean success, 
                                     String transactionId, String reason) {
        PaymentResultEvent resultEvent = new PaymentResultEvent();
        resultEvent.setOrderId(orderId);
        resultEvent.setUserId(userId);
        resultEvent.setSuccess(success);
        resultEvent.setTransactionId(transactionId);
        resultEvent.setReason(reason);

        rabbitTemplate.convertAndSend("payments-exchange", "payment.result", resultEvent);
        logger.info("Published payment result event for order {}: success={}", orderId, success);
    }
}

