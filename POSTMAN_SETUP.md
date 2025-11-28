# Postman Collection Setup Guide

## Importing the Collection

1. Open Postman
2. Click **Import** button (top left)
3. Select the file: `Food_Ordering_Microservices.postman_collection.json`
4. Click **Import**

## Environment Variables

The collection uses the following variables:
- `base_url`: Base URL for API Gateway (default: `http://localhost:8080`)
- `user_token`: JWT token for regular users (auto-populated after login)
- `admin_token`: JWT token for admin users (auto-populated after login)

## Using the Collection

### Step 1: Register Users

1. **Register User**: Create a regular user account
   - Email: `john@example.com`
   - Password: `12345`
   - Role: `USER`

2. **Register Admin**: Create an admin account
   - Email: `admin@example.com`
   - Password: `admin123`
   - Role: `ADMIN`

### Step 2: Login

1. **Login User**: This will automatically save the token to `user_token` variable
2. **Login Admin**: This will automatically save the token to `admin_token` variable

### Step 3: Test Endpoints

#### Health Checks
- All services have health check endpoints
- Access directly via service ports or through gateway

#### Restaurant Operations
- **Get All Restaurants**: Public endpoint (no auth required)
- **Create Restaurant**: Requires ADMIN token
- **Add Menu Item**: Requires ADMIN token

#### Order Operations
- **Create Order**: Requires USER or ADMIN token
  - Note: User ID is extracted from JWT token automatically
- **Get Order**: Requires USER or ADMIN token

## Testing Flow

1. Register a user and admin
2. Login to get tokens
3. Create a restaurant (as admin)
4. Add menu items (as admin)
5. Create an order (as user)
6. View the order (as user)

## Direct Service Access

For health checks and testing, you can also access services directly:
- Auth Service: `http://localhost:8081`
- Restaurant Service: `http://localhost:8082`
- Order Service: `http://localhost:8083`
- Payment Service: `http://localhost:8084`
- Notification Service: `http://localhost:8085`

## Troubleshooting

### Token Not Saved
- Check the **Tests** tab in login requests
- Verify the response contains a `token` field

### 401 Unauthorized
- Check if token is expired (tokens expire after 24 hours)
- Verify token is being sent in `Authorization: Bearer <token>` header
- Try logging in again to get a new token

### 403 Forbidden
- Verify your user has the correct role (USER vs ADMIN)
- Check that you're using the correct token for the operation

### 404 Not Found
- Verify the service is running
- Check the base URL is correct
- Ensure the endpoint path is correct

## Collection Structure

```
Food Ordering Microservices
├── Auth Service
│   ├── Health Check
│   ├── Register User
│   ├── Register Admin
│   ├── Login User (saves token)
│   └── Login Admin (saves token)
├── Restaurant Service
│   ├── Health Check
│   ├── Get All Restaurants
│   ├── Create Restaurant (Admin)
│   ├── Get Menu Item
│   └── Add Menu Item (Admin)
├── Order Service
│   ├── Health Check
│   ├── Create Order (User)
│   └── Get Order (User)
├── Payment Service
│   └── Health Check
├── Notification Service
│   └── Health Check
└── Direct Service Health Checks
    ├── Auth Service Direct
    ├── Restaurant Service Direct
    ├── Order Service Direct
    ├── Payment Service Direct
    └── Notification Service Direct
```

## Sample Request Bodies

### Register User
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "12345",
  "role": "USER"
}
```

### Register Admin
```json
{
  "name": "Admin User",
  "email": "admin@example.com",
  "password": "admin123",
  "role": "ADMIN"
}
```

### Create Restaurant
```json
{
  "name": "Pizza Palace",
  "address": "Mumbai"
}
```

### Add Menu Item
```json
{
  "name": "Veg Pizza",
  "price": 250
}
```

### Create Order
```json
{
  "restaurantId": 1,
  "items": [
    {
      "menuItemId": 1,
      "quantity": 2
    },
    {
      "menuItemId": 2,
      "quantity": 1
    }
  ]
}
```

Note: `userId` is automatically extracted from JWT token, so don't include it in the request.

