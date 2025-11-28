package com.foodorder.order.listener;

import com.foodorder.order.dto.PaymentResultEvent;
import com.foodorder.order.model.OrderEntity;
import com.foodorder.order.model.OrderStatus;
import com.foodorder.order.repository.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class PaymentResultListener {
    private static final Logger logger = LoggerFactory.getLogger(PaymentResultListener.class);

    private final OrderRepository orderRepository;

    public PaymentResultListener(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @RabbitListener(queues = "payment-result-queue")
    @Transactional
    public void handlePaymentResult(PaymentResultEvent event) {
        logger.info("Received payment result for order {}: success={}", event.getOrderId(), event.isSuccess());

        try {
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
            logger.info("Order {} status updated successfully", event.getOrderId());

        } catch (Exception e) {
            logger.error("Error handling payment result for order {}: {}",
                    event.getOrderId(), e.getMessage(), e);
            // In production, you might want to publish a dead letter queue event here
        }
    }
}
