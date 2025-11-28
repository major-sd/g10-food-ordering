# Security Configuration Guide

## Overview

All microservices have been configured with Spring Security and JWT-based authentication. This document describes the security setup and role-based access control (RBAC).

## Authentication Flow

1. **Registration/Login**: Users register or login through `auth-service`
2. **JWT Token Generation**: Auth service generates JWT tokens containing:
   - User ID
   - Role (USER or ADMIN)
   - Email
   - Expiration time (24 hours)
3. **Token Validation**: Other services validate JWT tokens from the `Authorization: Bearer <token>` header
4. **Role-Based Access**: Services enforce role-based access control on endpoints

## Roles

### USER Role
- Default role for all registered users
- Can create and view their own orders
- Can view restaurants and menu items

### ADMIN Role
- Can create restaurants
- Can add menu items to restaurants
- Has all USER privileges

## Service Security Configurations

### Auth Service (Port 8081)
**Public Endpoints:**
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login user
- `GET /auth/health` - Health check
- `GET /health` - Health check
- `GET /actuator/**` - Actuator endpoints

**Protected Endpoints:**
- All other endpoints require authentication

### Restaurant Service (Port 8082)
**Public Endpoints:**
- `GET /restaurants` - Get all restaurants
- `GET /restaurants/menu/{menuItemId}` - Get menu item
- `GET /health` - Health check
- `GET /actuator/**` - Actuator endpoints

**Protected Endpoints (ADMIN only):**
- `POST /restaurants` - Create restaurant (requires ADMIN role)
- `POST /restaurants/{id}/menu` - Add menu item (requires ADMIN role)

### Order Service (Port 8083)
**Public Endpoints:**
- `GET /health` - Health check
- `GET /actuator/**` - Actuator endpoints

**Protected Endpoints (USER or ADMIN):**
- `POST /orders` - Create order (requires USER or ADMIN role)
- `GET /orders/{orderId}` - Get order (requires USER or ADMIN role)

**Note:** User ID is automatically extracted from JWT token, so it should not be sent in the request body.

### Payment Service (Port 8084)
**Public Endpoints:**
- All endpoints are public (internal service)
- `GET /health` - Health check
- `GET /actuator/**` - Actuator endpoints

**Note:** Payment service is primarily accessed via RabbitMQ events, not directly via REST.

### Notification Service (Port 8085)
**Public Endpoints:**
- All endpoints are public (internal service)
- `GET /health` - Health check
- `GET /actuator/**` - Actuator endpoints

**Note:** Notification service is primarily accessed via RabbitMQ events, not directly via REST.

## JWT Token Structure

```json
{
  "sub": "1",
  "userId": 1,
  "role": "USER",
  "email": "john@example.com",
  "iat": 1234567890,
  "exp": 1234654290
}
```

## Security Configuration Details

### JWT Secret Key
All services use the same JWT secret key for token validation:
```
mySecretKeyForJWTTokenGeneration12345678901234567890
```

**⚠️ Important:** In production, this should be:
- Stored in environment variables
- Different per environment (dev, staging, prod)
- Managed via a secrets management service (e.g., Vault, AWS Secrets Manager)

### Token Validation

Each service validates tokens using:
1. **JwtUtil**: Parses and validates JWT tokens
2. **JwtAuthenticationFilter**: Intercepts requests and extracts user context
3. **SecurityConfig**: Configures endpoint access rules

## API Gateway Security

The API Gateway (Spring Cloud Gateway) currently routes requests without authentication. In production, you should:
- Add JWT validation filter at gateway level
- Implement rate limiting
- Add request logging and monitoring

## Health Check Endpoints

All services expose health check endpoints:
- `/health` - Custom health endpoint (returns service status)
- `/actuator/health` - Spring Boot Actuator health endpoint

These endpoints are **public** and do not require authentication.

## Testing Security

### 1. Register a User
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "12345",
    "role": "USER"
  }'
```

### 2. Register an Admin
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Admin User",
    "email": "admin@example.com",
    "password": "admin123",
    "role": "ADMIN"
  }'
```

### 3. Login and Get Token
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "12345"
  }'
```

### 4. Access Protected Endpoint
```bash
curl -X POST http://localhost:8080/api/restaurants \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-token>" \
  -d '{
    "name": "Pizza Palace",
    "address": "Mumbai"
  }'
```

## Error Responses

### 401 Unauthorized
```json
{
  "timestamp": "2024-01-01T00:00:00",
  "status": 401,
  "error": "Unauthorized",
  "message": "Full authentication is required to access this resource"
}
```

### 403 Forbidden
```json
{
  "timestamp": "2024-01-01T00:00:00",
  "status": 403,
  "error": "Forbidden",
  "message": "Access Denied"
}
```

## Production Security Recommendations

1. **HTTPS**: Use HTTPS for all API communications
2. **Token Expiration**: Reduce token expiration time (currently 24 hours)
3. **Refresh Tokens**: Implement refresh token mechanism
4. **Rate Limiting**: Add rate limiting on authentication endpoints
5. **CORS**: Configure CORS properly for web clients
6. **Input Validation**: Add comprehensive input validation
7. **SQL Injection**: Already protected by JPA, but ensure parameterized queries
8. **XSS Protection**: Add XSS protection headers
9. **Security Headers**: Add security headers (HSTS, CSP, etc.)
10. **Audit Logging**: Log all authentication and authorization attempts
11. **Secret Management**: Use proper secret management for JWT keys
12. **Token Revocation**: Implement token blacklist/revocation mechanism

## Role Assignment

Currently, roles are assigned during registration. In production, consider:
- Role assignment by administrators only
- Role hierarchy and permissions
- Temporary role elevation for specific operations

## Monitoring and Alerting

Monitor:
- Failed authentication attempts
- Token validation failures
- Unauthorized access attempts
- Role-based access violations

