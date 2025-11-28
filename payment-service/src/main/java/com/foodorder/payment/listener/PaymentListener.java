package com.foodorder.payment.listener;

import com.foodorder.payment.dto.OrderCreatedEvent;
import com.foodorder.payment.service.PaymentService;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class PaymentListener {
    private final PaymentService paymentService;

    public PaymentListener(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @RabbitListener(queues = "payment-queue")
    public void handleOrderCreated(OrderCreatedEvent event) {
        paymentService.processPayment(event);
    }
}

