package com.foodorder.notification.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {
    private static final Logger logger = LoggerFactory.getLogger(EmailService.class);

    private final JavaMailSender mailSender;

    public EmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public void sendOrderConfirmationEmail(String toEmail, Long orderId, String transactionId) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom("soumikroychoudhury02@gmail.com");
            message.setTo(toEmail);
            message.setSubject("✅ Order Confirmed - Order #" + orderId);
            message.setText(String.format(
                    "Dear Customer,\n\n" +
                            "Great news! Your order has been confirmed.\n\n" +
                            "Order ID: %d\n" +
                            "Transaction ID: %s\n" +
                            "Status: CONFIRMED\n\n" +
                            "Thank you for your order!\n\n" +
                            "Best regards,\n" +
                            "Food Ordering Service Team",
                    orderId, transactionId));

            mailSender.send(message);
            logger.info("✅ Confirmation email sent to {} for order {}", toEmail, orderId);
        } catch (Exception e) {
            logger.error("❌ Failed to send confirmation email for order {}: {}", orderId, e.getMessage());
        }
    }

    public void sendOrderCancellationEmail(String toEmail, Long orderId, String reason) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom("soumikroychoudhury02@gmail.com");
            message.setTo(toEmail);
            message.setSubject("❌ Order Cancelled - Order #" + orderId);
            message.setText(String.format(
                    "Dear Customer,\n\n" +
                            "We regret to inform you that we were unable to process your payment for Order #%d.\n\n" +
                            "This could be due to a temporary issue with your payment method or bank.\n\n" +
                            "Order ID: %d\n" +
                            "Status: CANCELLED\n\n" +
                            "We recommend trying a different payment method or contacting your bank for more details.\n\n"
                            + "We apologize for the inconvenience and hope to serve you soon.\n\n" +
                            "Best regards,\n" +
                            "Food Ordering Service Team",
                    orderId, orderId));

            logger.info("📧 Sending cancellation email body:\n{}", message.getText());
            mailSender.send(message);
            logger.info("✅ Cancellation email sent to {} for order {}", toEmail, orderId);
        } catch (Exception e) {
            logger.error("❌ Failed to send cancellation email for order {}: {}", orderId, e.getMessage());
        }
    }
}
