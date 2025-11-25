package com.foodordering.order.event;

import java.math.BigDecimal;
import java.util.List;

public class OrderCreatedEvent {
    private String orderId;
    private String userId;
    private Double totalAmount;
    private String paymentMethod;

    public OrderCreatedEvent() {
    }

    public OrderCreatedEvent(String orderId, String userId, Double totalAmount, String paymentMethod) {
        this.orderId = orderId;
        this.userId = userId;
        this.totalAmount = totalAmount;
        this.paymentMethod = paymentMethod;
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public Double getTotalAmount() {
        return totalAmount;
    }

    public void setTotalAmount(Double totalAmount) {
        this.totalAmount = totalAmount;
    }

    public String getPaymentMethod() {
        return paymentMethod;
    }

    public void setPaymentMethod(String paymentMethod) {
        this.paymentMethod = paymentMethod;
    }
}
