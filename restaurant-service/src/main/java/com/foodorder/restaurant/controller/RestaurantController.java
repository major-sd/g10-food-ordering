package com.foodorder.restaurant.controller;

import com.foodorder.restaurant.dto.MenuItemDTO;
import com.foodorder.restaurant.dto.MenuItemRequest;
import com.foodorder.restaurant.dto.RestaurantDTO;
import com.foodorder.restaurant.dto.RestaurantRequest;
import com.foodorder.restaurant.service.RestaurantService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/restaurants")
public class RestaurantController {
    private final RestaurantService restaurantService;

    public RestaurantController(RestaurantService restaurantService) {
        this.restaurantService = restaurantService;
    }

    @PostMapping
    public ResponseEntity<RestaurantDTO> createRestaurant(@RequestBody RestaurantRequest request) {
        RestaurantDTO restaurant = restaurantService.createRestaurant(request);
        return ResponseEntity.ok(restaurant);
    }

    @GetMapping
    public ResponseEntity<List<RestaurantDTO>> getAllRestaurants() {
        List<RestaurantDTO> restaurants = restaurantService.getAllRestaurants();
        return ResponseEntity.ok(restaurants);
    }

    @PostMapping("/{id}/menu")
    public ResponseEntity<MenuItemDTO> createMenuItem(@PathVariable Long id, @RequestBody MenuItemRequest request) {
        MenuItemDTO menuItem = restaurantService.createMenuItem(id, request);
        return ResponseEntity.ok(menuItem);
    }

    @GetMapping("/menu/{menuItemId}")
    public ResponseEntity<MenuItemDTO> getMenuItem(@PathVariable Long menuItemId) {
        MenuItemDTO menuItem = restaurantService.getMenuItem(menuItemId);
        return ResponseEntity.ok(menuItem);
    }
}

