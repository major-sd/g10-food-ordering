# Deployment Scripts Guide

This project includes deployment scripts to simplify building and redeploying all microservices.

## Available Scripts

### 1. `redeploy.sh` (Full-featured, Unix/Linux/macOS)

Comprehensive redeployment script with error checking, health monitoring, and user prompts.

**Features:**
- ✅ Prerequisites checking (Maven, Docker, Docker Compose)
- ✅ Stops existing containers gracefully
- ✅ Builds all services with Maven
- ✅ Verifies JAR files are created
- ✅ Deploys with docker-compose
- ✅ Health check monitoring
- ✅ Colored output for better readability

**Usage:**
```bash
./redeploy.sh
```

**What it does:**
1. Checks if Maven, Docker, and Docker Compose are installed
2. Stops existing running containers
3. Optionally cleans previous Maven builds (prompts for confirmation)
4. Builds all 6 services using Maven
5. Verifies all JAR files are created successfully
6. Deploys all services using docker-compose
7. Checks service health endpoints
8. Displays service status

### 2. `quick-redeploy.sh` (Quick version, Unix/Linux/macOS)

Minimal redeployment script without prompts - ideal for CI/CD or quick redeploys.

**Features:**
- ✅ No user prompts
- ✅ Fast execution
- ✅ Silent Maven builds

**Usage:**
```bash
./quick-redeploy.sh
```

### 3. `redeploy.bat` (Windows)

Windows batch script equivalent to the full-featured Unix script.

**Usage:**
```cmd
redeploy.bat
```

## Manual Deployment Steps

If you prefer to deploy manually or the scripts don't work in your environment:

### Step 1: Build All Services
```bash
for service in auth-service restaurant-service order-service payment-service notification-service api-gateway; do
  echo "Building $service..."
  cd $service
  mvn clean package -DskipTests
  cd ..
done
```

### Step 2: Stop Existing Containers
```bash
docker-compose down
# or
docker compose down
```

### Step 3: Deploy
```bash
docker-compose up --build -d
# or
docker compose up --build -d
```

### Step 4: Check Status
```bash
docker-compose ps
```

### Step 5: View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f auth-service
```

## Prerequisites

Before running the scripts, ensure you have:

1. **Java 17+**
   ```bash
   java -version
   ```

2. **Maven 3.6+**
   ```bash
   mvn -version
   ```

3. **Docker**
   ```bash
   docker --version
   ```

4. **Docker Compose**
   ```bash
   docker-compose --version
   # or
   docker compose version
   ```

## Troubleshooting

### Script Permission Denied (Unix/macOS)
```bash
chmod +x redeploy.sh
chmod +x quick-redeploy.sh
```

### Maven Build Fails
- Check Java version: `java -version` (should be 17+)
- Clean Maven cache: `mvn clean`
- Check internet connection (Maven needs to download dependencies)

### Docker Compose Issues
- Verify Docker is running: `docker ps`
- Check port availability: `lsof -i :8080` (macOS/Linux)
- Try `docker compose` instead of `docker-compose` (newer Docker versions)

### Services Not Starting
- Check logs: `docker-compose logs [service-name]`
- Verify database containers are healthy: `docker-compose ps`
- Wait longer (first start takes time for databases to initialize)

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '17'
      - uses: actions/setup-node@v3
      - name: Deploy
        run: |
          chmod +x redeploy.sh
          ./quick-redeploy.sh
```

### Jenkins Pipeline Example
```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh './quick-redeploy.sh'
            }
        }
    }
}
```

## Monitoring Deployment

### Check Service Health
```bash
curl http://localhost:8081/health  # Auth service
curl http://localhost:8082/health  # Restaurant service
curl http://localhost:8083/health  # Order service
curl http://localhost:8084/health  # Payment service
curl http://localhost:8085/health  # Notification service
curl http://localhost:8080/actuator/health  # API Gateway
```

### Watch Service Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f order-service

# Last 100 lines
docker-compose logs --tail=100 order-service
```

### Service Status
```bash
docker-compose ps
```

## Rollback

To rollback to a previous version:

1. **Stop current services:**
   ```bash
   docker-compose down
   ```

2. **Checkout previous version:**
   ```bash
   git checkout <previous-commit>
   ```

3. **Rebuild and redeploy:**
   ```bash
   ./redeploy.sh
   ```

## Production Deployment

For production deployment, consider:

1. **Environment Variables**: Use `.env` file for configuration
2. **Secrets Management**: Don't hardcode passwords or API keys
3. **Health Checks**: Configure proper health check intervals
4. **Resource Limits**: Set CPU and memory limits in docker-compose
5. **Backup Strategy**: Regularly backup database volumes
6. **Monitoring**: Set up monitoring and alerting
7. **Logging**: Configure centralized logging

Example production docker-compose override:
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  auth-service:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
    restart: always
```

Deploy with:
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Best Practices

1. **Always test locally first** before deploying to production
2. **Use version tags** for Docker images in production
3. **Monitor logs** during deployment
4. **Have a rollback plan** ready
5. **Deploy during low-traffic periods**
6. **Backup databases** before deployment
7. **Verify health checks** after deployment

## Additional Commands

### Rebuild Single Service
```bash
cd auth-service
mvn clean package -DskipTests
docker-compose up --build -d auth-service
```

### Update Dependencies
```bash
# Update Maven dependencies
mvn clean install -U

# Rebuild and redeploy
./redeploy.sh
```

### Clean Everything
```bash
docker-compose down -v  # Remove volumes too
docker system prune -a  # Clean Docker system
```

---

**Need help?** Check the logs or refer to the main README.md for more information.

