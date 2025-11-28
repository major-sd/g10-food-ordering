package com.foodorder.order.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PaymentResultEvent {
    public Long orderId;
    public Long userId;
    public boolean success;
    public String transactionId;
    public String reason;
}

