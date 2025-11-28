# Bruno Setup Guide

This guide explains how to use the Postman collection with Bruno API client.

## Quick Import Files

Two files are provided for Bruno/Postman import:

- `Food_Ordering_Microservices.postman_collection.json` – complete collection with auto token scripts
- `Food_Ordering_Bruno_Environment.postman_environment.json` – environment with `base_url`, `user_token`, `admin_token`

### Import Steps
1. Import the environment file first (`Collection → Import → Environment`)
2. Select the **Food Ordering Bruno Environment** after import
3. Then import the collection file (instructions below)

## Importing the Collection

1. Open Bruno
2. Click **Import** or use the menu: `Collection → Import`
3. Select `Food_Ordering_Microservices.postman_collection.json`
4. The collection will be imported with all requests and variables

## Environment Variables Setup

After importing, you need to create an environment in Bruno:

1. **Create Environment:**
   - Click on **Environments** in the sidebar
   - Click **+ New Environment**
   - Name it: `Food Ordering Local`

2. **Set Variables:**
   - Add the following variables:
     ```
     base_url = http://localhost:8080
     user_token = (leave empty, will be auto-set)
     admin_token = (leave empty, will be auto-set)
     ```

3. **Select Environment:**
   - Select the environment you just created from the environment dropdown

## Automatic Token Management

The collection is configured to automatically extract and save tokens:

### How It Works:

1. **Register User** or **Login User**
   - Executes test script after response
   - Extracts `token` from JSON response
   - Saves to `user_token` variable (both environment and collection level)

2. **Register Admin** or **Login Admin**
   - Executes test script after response
   - Extracts `token` from JSON response
   - Saves to `admin_token` variable (both environment and collection level)

### Token Usage:

All protected endpoints automatically use the appropriate token:
- **User endpoints** use `{{user_token}}`
- **Admin endpoints** use `{{admin_token}}`

The token is included in the `Authorization` header:
```
Authorization: Bearer {{user_token}}
```

## Testing Flow

### Recommended Order:

1. **Register User** (optional - auto-saves token)
   - Creates user account
   - Automatically saves token

2. **Register Admin** (optional - auto-saves token)
   - Creates admin account
   - Automatically saves token

3. **Login User** (if needed)
   - Gets new user token
   - Updates `user_token` variable

4. **Login Admin** (if needed)
   - Gets new admin token
   - Updates `admin_token` variable

5. **Create Restaurant** (requires admin token)
   - Uses `{{admin_token}}` automatically

6. **Add Menu Items** (requires admin token)
   - Uses `{{admin_token}}` automatically

7. **Create Order** (requires user token)
   - Uses `{{user_token}}` automatically

8. **Get Order** (requires user token)
   - Uses `{{user_token}}` automatically

## Bruno-Specific Features

### Viewing Variables

1. Click on **Environments** in sidebar
2. Select your environment
3. View/Edit variable values
4. Variables are automatically updated by test scripts

### Debugging Token Issues

If tokens aren't being set:

1. **Check Response:**
   - Open the request in Bruno
   - View the **Response** tab
   - Verify `token` field exists in JSON

2. **Check Console:**
   - Open Bruno's console/logs
   - Look for token-related messages
   - Error messages will show if token extraction failed

3. **Manual Token Set:**
   - If auto-set fails, manually copy token from response
   - Paste into environment variable

### Token Expiration

- Tokens expire after 24 hours
- If you get 401 Unauthorized:
  1. Run **Login User** or **Login Admin** again
  2. Token will be automatically updated

## Testing Scripts

The collection includes test scripts that run after each login/register request:

```javascript
if (pm.response.code === 200) {
    try {
        var jsonData = pm.response.json();
        if (jsonData.token) {
            pm.environment.set("user_token", jsonData.token);
            pm.collectionVariables.set("user_token", jsonData.token);
            console.log("User token saved successfully");
        }
    } catch (e) {
        console.log("Error extracting token:", e);
    }
}
```

These scripts:
- Check for successful response (200)
- Extract token from JSON response
- Save to both environment and collection variables
- Log success/errors to console

## Troubleshooting

### Issue: Token not being saved

**Solution:**
- Verify response has `token` field
- Check Bruno console for errors
- Manually set token in environment if needed

### Issue: 401 Unauthorized errors

**Solution:**
1. Token may be expired (24-hour expiration)
2. Re-run Login request to get new token
3. Verify token variable is set correctly

### Issue: Variables not resolving

**Solution:**
- Ensure environment is selected
- Check variable names match exactly: `{{user_token}}` and `{{admin_token}}`
- Verify variable exists in selected environment

### Issue: Import errors

**Solution:**
- Ensure you're using Postman Collection v2.1 format
- Bruno supports this format natively
- Try re-importing the collection

## Alternative: Manual Token Setup

If automatic token extraction doesn't work:

1. **Run Login request**
2. **Copy token from response:**
   ```json
   {
     "token": "eyJhbGciOiJIUzM4NCJ9..."
   }
   ```
3. **Set in environment:**
   - Go to Environments
   - Find `user_token` or `admin_token`
   - Paste the token value
   - Save environment

## Collection Structure

```
Food Ordering Microservices
├── Auth Service
│   ├── Health Check
│   ├── Register User (saves token)
│   ├── Register Admin (saves token)
│   ├── Login User (saves token)
│   └── Login Admin (saves token)
├── Restaurant Service
│   ├── Health Check
│   ├── Get All Restaurants
│   ├── Create Restaurant (uses {{admin_token}})
│   ├── Get Menu Item
│   └── Add Menu Item (uses {{admin_token}})
├── Order Service
│   ├── Health Check
│   ├── Create Order (uses {{user_token}})
│   └── Get Order (uses {{user_token}})
├── Payment Service
│   └── Health Check
├── Notification Service
│   └── Health Check
└── Direct Service Health Checks
```

## Quick Start Checklist

- [ ] Import collection into Bruno
- [ ] Create environment with `base_url` variable
- [ ] Select the environment
- [ ] Run **Register User** or **Login User**
- [ ] Verify `user_token` is set in environment
- [ ] Run **Register Admin** or **Login Admin**
- [ ] Verify `admin_token` is set in environment
- [ ] Test protected endpoints

## Tips

1. **Save Responses:** Bruno saves response history, useful for debugging
2. **Collections:** Organize requests into folders as needed
3. **Variables:** Use collection-level variables for shared values
4. **Scripts:** Test scripts run automatically after each request
5. **Environment Switching:** Easy to switch between dev/staging/prod

## Support

If you encounter issues:
1. Check Bruno documentation: https://docs.usebruno.com
2. Verify API is running: `curl http://localhost:8080/api/auth/health`
3. Check service logs: `docker-compose logs`

---

**Note:** This collection is compatible with both Postman and Bruno. The token extraction scripts work in both tools.

## Bruno Workspace Import

If you prefer Bruno's workspace format, use **bruno.json** (added at repo root).

1. In Bruno, choose **Collection → Open Workspace**
2. Select `bruno.json`
3. Bruno loads both the collection (`Food_Ordering_Microservices.bru`) and environment (`Food_Ordering_Bruno_Environment.bru`) automatically

This is especially useful on Bruno v2.9.1+ which supports workspace files out of the box.

