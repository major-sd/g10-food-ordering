package com.foodorder.order.service;

import com.foodorder.order.dto.*;
import com.foodorder.order.model.OrderEntity;
import com.foodorder.order.model.OrderItem;
import com.foodorder.order.model.OrderStatus;
import com.foodorder.order.repository.OrderItemRepository;
import com.foodorder.order.repository.OrderRepository;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final WebClient.Builder webClientBuilder;
    private final RabbitTemplate rabbitTemplate;

    @Autowired
    public OrderService(OrderRepository orderRepository, OrderItemRepository orderItemRepository,
                       WebClient.Builder webClientBuilder, RabbitTemplate rabbitTemplate) {
        this.orderRepository = orderRepository;
        this.orderItemRepository = orderItemRepository;
        this.webClientBuilder = webClientBuilder;
        this.rabbitTemplate = rabbitTemplate;
    }

    public OrderResponse createOrder(OrderRequest request) {
        // Calculate total amount by calling restaurant-service
        double totalAmount = 0.0;
        WebClient webClient = webClientBuilder.build();

        for (OrderItemRequest itemRequest : request.getItems()) {
            MenuItemDTO menuItem = webClient.get()
                    .uri("http://restaurant-service:8082/restaurants/menu/" + itemRequest.getMenuItemId())
                    .retrieve()
                    .bodyToMono(MenuItemDTO.class)
                    .block();

            if (menuItem == null) {
                throw new RuntimeException("MenuItem not found: " + itemRequest.getMenuItemId());
            }

            totalAmount += menuItem.getPrice() * itemRequest.getQuantity();
        }

        // Create order
        OrderEntity order = new OrderEntity();
        order.setUserId(request.getUserId());
        order.setRestaurantId(request.getRestaurantId());
        order.setAmount(totalAmount);
        order.setStatus(OrderStatus.PENDING);
        OrderEntity savedOrder = orderRepository.save(order);

        // Create order items
        for (OrderItemRequest itemRequest : request.getItems()) {
            MenuItemDTO menuItem = webClient.get()
                    .uri("http://restaurant-service:8082/restaurants/menu/" + itemRequest.getMenuItemId())
                    .retrieve()
                    .bodyToMono(MenuItemDTO.class)
                    .block();

            OrderItem orderItem = new OrderItem();
            orderItem.setOrderId(savedOrder.getId());
            orderItem.setMenuItemId(itemRequest.getMenuItemId());
            orderItem.setQuantity(itemRequest.getQuantity());
            orderItem.setPrice(menuItem.getPrice());
            orderItemRepository.save(orderItem);
        }

        // Publish OrderCreatedEvent
        OrderCreatedEvent event = new OrderCreatedEvent();
        event.setOrderId(savedOrder.getId());
        event.setUserId(savedOrder.getUserId());
        event.setRestaurantId(savedOrder.getRestaurantId());
        event.setAmount(savedOrder.getAmount());

        rabbitTemplate.convertAndSend("orders-exchange", "order.created", event);

        return getOrderResponse(savedOrder);
    }

    public OrderResponse getOrder(Long orderId) {
        OrderEntity order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        return getOrderResponse(order);
    }

    private OrderResponse getOrderResponse(OrderEntity order) {
        List<OrderItem> orderItems = orderItemRepository.findByOrderId(order.getId());
        List<OrderItemResponse> itemResponses = orderItems.stream()
                .map(item -> new OrderItemResponse(item.getId(), item.getMenuItemId(), item.getQuantity(), item.getPrice()))
                .collect(Collectors.toList());

        return new OrderResponse(
                order.getId(),
                order.getUserId(),
                order.getRestaurantId(),
                order.getAmount(),
                order.getStatus(),
                order.getCreatedAt(),
                itemResponses
        );
    }
}

