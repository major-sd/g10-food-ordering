package com.foodorder.order.controller;

import com.foodorder.order.dto.OrderRequest;
import com.foodorder.order.dto.OrderResponse;
import com.foodorder.order.service.OrderService;
import com.foodorder.order.util.SecurityUtil;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/orders")
public class OrderController {
    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(@RequestBody OrderRequest request) {
        Long userId = SecurityUtil.getCurrentUserId();
        request.setUserId(userId); // Set userId from JWT token
        OrderResponse response = orderService.createOrder(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<OrderResponse> getOrder(@PathVariable Long orderId) {
        OrderResponse response = orderService.getOrder(orderId);
        return ResponseEntity.ok(response);
    }
}

