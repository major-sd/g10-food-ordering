package com.foodorder.order.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderCreatedEvent {
    public Long orderId;
    public Long userId;
    public Long restaurantId;
    public double amount;
}

