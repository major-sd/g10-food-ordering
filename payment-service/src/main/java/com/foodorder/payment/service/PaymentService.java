package com.foodorder.payment.service;

import com.foodorder.payment.dto.OrderCreatedEvent;
import com.foodorder.payment.dto.PaymentResultEvent;
import com.foodorder.payment.model.PaymentRecord;
import com.foodorder.payment.repository.PaymentRepository;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class PaymentService {
    private final PaymentRepository paymentRepository;
    private final RabbitTemplate rabbitTemplate;

    public PaymentService(PaymentRepository paymentRepository, RabbitTemplate rabbitTemplate) {
        this.paymentRepository = paymentRepository;
        this.rabbitTemplate = rabbitTemplate;
    }

    public void processPayment(OrderCreatedEvent event) {
        // Simulate 90% success rate
        boolean success = ThreadLocalRandom.current().nextInt(100) < 90;
        String transactionId = UUID.randomUUID().toString();
        String reason = success ? "Payment successful" : "Insufficient funds";

        // Save payment record
        PaymentRecord paymentRecord = new PaymentRecord();
        paymentRecord.setOrderId(event.getOrderId());
        paymentRecord.setSuccess(success);
        paymentRecord.setTransactionId(transactionId);
        paymentRecord.setMethod("CARD");
        paymentRepository.save(paymentRecord);

        // Publish PaymentResultEvent
        PaymentResultEvent resultEvent = new PaymentResultEvent();
        resultEvent.setOrderId(event.getOrderId());
        resultEvent.setSuccess(success);
        resultEvent.setTransactionId(transactionId);
        resultEvent.setReason(reason);

        rabbitTemplate.convertAndSend("payments-exchange", "payment.result", resultEvent);
    }
}

