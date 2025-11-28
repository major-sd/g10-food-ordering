package com.foodorder.restaurant.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<Map<String, String>> handleRuntimeException(RuntimeException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", ex.getMessage());
        
        // If it's a "not found", "no such", "no restaurant", or "no menu" error, return 404
        if (ex.getMessage() != null && 
            (ex.getMessage().toLowerCase().contains("not found") || 
             ex.getMessage().toLowerCase().contains("no such") ||
             ex.getMessage().toLowerCase().contains("no restaurant") ||
             ex.getMessage().toLowerCase().contains("no menu"))) {
            error.put("status", "404");
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error);
        }
        
        // Otherwise return 500
        error.put("status", "500");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}
