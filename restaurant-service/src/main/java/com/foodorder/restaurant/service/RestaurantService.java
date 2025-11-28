package com.foodorder.restaurant.service;

import com.foodorder.restaurant.dto.MenuItemDTO;
import com.foodorder.restaurant.dto.MenuItemRequest;
import com.foodorder.restaurant.dto.RestaurantDTO;
import com.foodorder.restaurant.dto.RestaurantRequest;
import com.foodorder.restaurant.model.MenuItem;
import com.foodorder.restaurant.model.Restaurant;
import com.foodorder.restaurant.repository.MenuItemRepository;
import com.foodorder.restaurant.repository.RestaurantRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class RestaurantService {
    private final RestaurantRepository restaurantRepository;
    private final MenuItemRepository menuItemRepository;

    public RestaurantService(RestaurantRepository restaurantRepository, MenuItemRepository menuItemRepository) {
        this.restaurantRepository = restaurantRepository;
        this.menuItemRepository = menuItemRepository;
    }

    public RestaurantDTO createRestaurant(RestaurantRequest request) {
        Restaurant restaurant = new Restaurant();
        restaurant.setName(request.getName());
        restaurant.setAddress(request.getAddress());
        Restaurant saved = restaurantRepository.save(restaurant);
        return toDTO(saved);
    }

    public List<RestaurantDTO> getAllRestaurants() {
        return restaurantRepository.findAll().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public MenuItemDTO createMenuItem(Long restaurantId, MenuItemRequest request) {
        MenuItem menuItem = new MenuItem();
        menuItem.setName(request.getName());
        menuItem.setPrice(request.getPrice());
        menuItem.setRestaurantId(restaurantId);
        MenuItem saved = menuItemRepository.save(menuItem);
        return toDTO(saved);
    }

    public MenuItemDTO getMenuItem(Long menuItemId) {
        MenuItem menuItem = menuItemRepository.findById(menuItemId)
                .orElseThrow(() -> new RuntimeException("MenuItem not found"));
        return toDTO(menuItem);
    }

    private RestaurantDTO toDTO(Restaurant restaurant) {
        return new RestaurantDTO(restaurant.getId(), restaurant.getName(), restaurant.getAddress());
    }

    private MenuItemDTO toDTO(MenuItem menuItem) {
        return new MenuItemDTO(menuItem.getId(), menuItem.getName(), menuItem.getPrice(), menuItem.getRestaurantId());
    }
}

