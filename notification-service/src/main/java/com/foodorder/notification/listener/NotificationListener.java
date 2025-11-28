package com.foodorder.notification.listener;

import com.foodorder.notification.dto.PaymentResultEvent;
import com.foodorder.notification.service.NotificationService;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class NotificationListener {
    private final NotificationService notificationService;

    public NotificationListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @RabbitListener(queues = "payment-result-queue")
    public void handlePaymentResult(PaymentResultEvent event) {
        notificationService.handlePaymentResult(event);
    }
}

