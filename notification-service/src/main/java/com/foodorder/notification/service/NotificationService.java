package com.foodorder.notification.service;

import com.foodorder.notification.dto.PaymentResultEvent;
import com.foodorder.notification.model.Notification;
import com.foodorder.notification.repository.NotificationRepository;
import org.springframework.stereotype.Service;

@Service
public class NotificationService {
    private final NotificationRepository notificationRepository;

    public NotificationService(NotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    public void handlePaymentResult(PaymentResultEvent event) {
        String message;
        if (event.isSuccess()) {
            message = "Order " + event.getOrderId() + " confirmed";
        } else {
            message = "Order " + event.getOrderId() + " failed";
        }

        Notification notification = new Notification();
        notification.setOrderId(event.getOrderId());
        notification.setMessage(message);
        notification.setSent(true);

        notificationRepository.save(notification);
        
        // In production, send actual notification (SMS, email, push)
        System.out.println("Notification: " + message);
    }
}

