package com.foodorder.auth.exception;

public class UserAlreadyExistsException extends RuntimeException {
    public UserAlreadyExistsException(String email) {
        super(String.format("User already exists with email %s", email));
    }
}
