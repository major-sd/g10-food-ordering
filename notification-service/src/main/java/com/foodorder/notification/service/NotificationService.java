package com.foodorder.notification.service;

import com.foodorder.notification.dto.PaymentResultEvent;
import com.foodorder.notification.dto.UserDTO;
import com.foodorder.notification.model.Notification;
import com.foodorder.notification.repository.NotificationRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

@Service
public class NotificationService {
    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationRepository notificationRepository;
    private final EmailService emailService;
    private final WebClient.Builder webClientBuilder;

    public NotificationService(NotificationRepository notificationRepository,
            EmailService emailService,
            WebClient.Builder webClientBuilder) {
        this.notificationRepository = notificationRepository;
        this.emailService = emailService;
        this.webClientBuilder = webClientBuilder;
    }

    @Transactional
    public void handlePaymentResult(PaymentResultEvent event) {
        logger.info("Processing notification for order {}: success={}", event.getOrderId(), event.isSuccess());

        String message;
        String notificationType;

        if (event.isSuccess()) {
            message = String.format("✅ Order #%d confirmed! Payment successful. Transaction ID: %s",
                    event.getOrderId(), event.getTransactionId());
            notificationType = "ORDER_CONFIRMED";
        } else {
            message = String.format("❌ Order #%d cancelled. Payment failed: %s",
                    event.getOrderId(), event.getReason());
            notificationType = "ORDER_CANCELLED";
        }

        // Save notification to database
        Notification notification = new Notification();
        notification.setOrderId(event.getOrderId());
        notification.setMessage(message);
        notification.setSent(true);
        notificationRepository.save(notification);

        // Log notification
        logger.info("📧 [{}] Notification sent to User {}: {}", notificationType, event.getUserId(), message);
        System.out.println("=".repeat(80));
        System.out.println(String.format("📧 NOTIFICATION TO USER %d", event.getUserId()));
        System.out.println("-".repeat(80));
        System.out.println(message);
        System.out.println("=".repeat(80));

        // Send email notification
        sendEmailNotification(event, notificationType);
    }

    private void sendEmailNotification(PaymentResultEvent event, String notificationType) {
        try {
            // Fetch user email from Auth Service
            WebClient webClient = webClientBuilder.build();
            UserDTO user = webClient.get()
                    .uri("http://auth-service:8081/api/users/" + event.getUserId())
                    .retrieve()
                    .bodyToMono(UserDTO.class)
                    .block();

            if (user == null || user.getEmail() == null) {
                logger.warn("⚠️  User {} not found or email missing, skipping email notification", event.getUserId());
                return;
            }

            // Send appropriate email
            if ("ORDER_CONFIRMED".equals(notificationType)) {
                // Fetch full order details
                com.foodorder.notification.dto.OrderDTO order = webClient.get()
                        .uri("http://order-service:8083/orders/" + event.getOrderId())
                        .retrieve()
                        .bodyToMono(com.foodorder.notification.dto.OrderDTO.class)
                        .block();

                if (order != null) {
                    emailService.sendOrderConfirmationEmail(
                            user.getEmail(),
                            order,
                            event.getTransactionId());
                } else {
                    logger.warn("⚠️  Order {} details not found, skipping confirmation email", event.getOrderId());
                }
            } else {
                emailService.sendOrderCancellationEmail(
                        user.getEmail(),
                        event.getOrderId(),
                        event.getReason());
            }
        } catch (Exception e) {
            logger.error("❌ Failed to send email for order {}: {}", event.getOrderId(), e.getMessage());
        }
    }
}
