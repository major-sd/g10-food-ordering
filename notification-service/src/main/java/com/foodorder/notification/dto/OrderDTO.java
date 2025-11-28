package com.foodorder.notification.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderDTO {
    private Long id;
    private Long userId;
    private Long restaurantId;
    private Double amount;
    private String status;
    private LocalDateTime createdAt;
    private List<OrderItemDTO> items;
}
