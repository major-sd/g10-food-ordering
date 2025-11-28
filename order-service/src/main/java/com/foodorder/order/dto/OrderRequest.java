package com.foodorder.order.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderRequest {
    private Long userId; // Will be set from JWT token, not from request body
    private Long restaurantId;
    private List<OrderItemRequest> items;
}

