package com.foodorder.order.dto;

import com.foodorder.order.model.OrderStatus;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderResponse {
    private Long id;
    private Long userId;
    private Long restaurantId;
    private Double amount;
    private OrderStatus status;
    private LocalDateTime createdAt;
    private List<OrderItemResponse> items;
}

