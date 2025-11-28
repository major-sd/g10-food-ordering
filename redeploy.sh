#!/bin/bash

# Food Ordering Microservices - Redeploy Script
# This script builds all services and redeploys using docker-compose

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICES=("auth-service" "restaurant-service" "order-service" "payment-service" "notification-service" "api-gateway")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Food Ordering Microservices Redeploy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v mvn &> /dev/null; then
    print_error "Maven is not installed. Please install Maven first."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_success "Prerequisites check passed"
echo ""

# Step 1: Stop existing containers
print_info "Step 1: Stopping existing containers..."
cd "$SCRIPT_DIR"
if docker-compose ps | grep -q "Up"; then
    docker-compose down
    print_success "Containers stopped"
else
    print_warning "No running containers found"
fi
echo ""

# Step 2: Clean previous builds (optional)
read -p "Do you want to clean previous Maven builds? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cleaning previous builds..."
    for service in "${SERVICES[@]}"; do
        if [ -d "$SCRIPT_DIR/$service" ]; then
            print_info "Cleaning $service..."
            cd "$SCRIPT_DIR/$service"
            mvn clean -q || print_warning "Failed to clean $service (may not exist)"
        fi
    done
    cd "$SCRIPT_DIR"
    print_success "Clean completed"
    echo ""
fi

# Step 3: Build all services
print_info "Step 2: Building all services with Maven..."
echo ""

BUILD_FAILED=0
for service in "${SERVICES[@]}"; do
    if [ ! -d "$SCRIPT_DIR/$service" ]; then
        print_warning "Directory $service not found, skipping..."
        continue
    fi
    
    print_info "Building $service..."
    cd "$SCRIPT_DIR/$service"
    
    if mvn clean package -DskipTests; then
        print_success "$service built successfully"
    else
        print_error "Failed to build $service"
        BUILD_FAILED=1
    fi
    echo ""
done

cd "$SCRIPT_DIR"

if [ $BUILD_FAILED -eq 1 ]; then
    print_error "One or more services failed to build. Aborting deployment."
    exit 1
fi

print_success "All services built successfully"
echo ""

# Step 4: Verify JAR files exist
print_info "Step 3: Verifying JAR files..."
MISSING_JARS=0
for service in "${SERVICES[@]}"; do
    JAR_FILE="$SCRIPT_DIR/$service/target/${service}-1.0.0.jar"
    if [ ! -f "$JAR_FILE" ]; then
        print_error "JAR file not found: $JAR_FILE"
        MISSING_JARS=1
    else
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        print_info "  ✓ $service: $JAR_SIZE"
    fi
done

if [ $MISSING_JARS -eq 1 ]; then
    print_error "One or more JAR files are missing. Aborting deployment."
    exit 1
fi

print_success "All JAR files verified"
echo ""

# Step 5: Deploy with docker-compose
print_info "Step 4: Deploying with docker-compose..."
echo ""

cd "$SCRIPT_DIR"

# Check if docker-compose or docker compose should be used
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

print_info "Using: $COMPOSE_CMD"
echo ""

# Build and start all services
if $COMPOSE_CMD up --build -d; then
    print_success "Services deployed successfully"
    echo ""
    
    # Wait for services to start
    print_info "Waiting for services to start..."
    sleep 5
    
    # Show status
    print_info "Service status:"
    $COMPOSE_CMD ps
    echo ""
    
    print_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check health endpoints
    print_info "Checking service health..."
    echo ""
    
    SERVICES_PORTS=(
        "auth-service:8081"
        "restaurant-service:8082"
        "order-service:8083"
        "payment-service:8084"
        "notification-service:8085"
        "api-gateway:8080"
    )
    
    HEALTHY=0
    for service_port in "${SERVICES_PORTS[@]}"; do
        SERVICE_NAME=$(echo $service_port | cut -d: -f1)
        PORT=$(echo $service_port | cut -d: -f2)
        
        if curl -s -f "http://localhost:$PORT/health" > /dev/null 2>&1 || curl -s -f "http://localhost:$PORT/actuator/health" > /dev/null 2>&1; then
            print_success "  ✓ $SERVICE_NAME is responding"
            HEALTHY=$((HEALTHY + 1))
        else
            print_warning "  ⚠ $SERVICE_NAME not responding yet (may need more time)"
        fi
    done
    
    echo ""
    print_info "Health check: $HEALTHY/${#SERVICES_PORTS[@]} services responding"
    echo ""
    
    print_success "=========================================="
    print_success "Redeploy completed successfully!"
    print_success "=========================================="
    echo ""
    print_info "Access points:"
    echo "  - API Gateway: http://localhost:8080"
    echo "  - RabbitMQ Management: http://localhost:15672 (guest/guest)"
    echo "  - Service Logs: $COMPOSE_CMD logs -f [service-name]"
    echo ""
    print_info "To view logs: $COMPOSE_CMD logs -f"
    print_info "To stop services: $COMPOSE_CMD down"
    echo ""
    
else
    print_error "Failed to deploy services"
    print_info "Check logs with: $COMPOSE_CMD logs"
    exit 1
fi

