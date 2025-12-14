#!/bin/bash

# Health check script for all services
# Usage: ./scripts/health-check.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Health Check Report"
echo "==================="
echo ""

# Function to check HTTP endpoint
check_http() {
    local service=$1
    local url=$2
    local timeout=${3:-5}
    
    if timeout $timeout curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $service is healthy"
        return 0
    else
        echo -e "${RED}✗${NC} $service is not responding"
        return 1
    fi
}

# Function to check TCP port
check_tcp() {
    local service=$1
    local host=$2
    local port=$3
    
    if nc -z -w5 "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $service is listening on port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $service is not listening on port $port"
        return 1
    fi
}

# Check services
echo "Core Services:"
echo "--------------"
check_http "MLflow" "http://localhost:5000/health"
check_http "Prefect Server" "http://localhost:4200/api/health"
check_http "Serving API" "http://localhost:8000/health"
check_tcp "PostgreSQL" "localhost" 5432
check_tcp "Redis" "localhost" 6379

echo ""
echo "Monitoring Stack:"
echo "-----------------"
check_http "Prometheus" "http://localhost:9090/-/healthy"
check_http "Grafana" "http://localhost:3000/api/health"
check_http "MinIO" "http://localhost:9000/minio/health/live"

echo ""
echo "Database Connectivity:"
echo "----------------------"

# Check PostgreSQL databases
if docker-compose exec -T postgres psql -U mlops -d mlops_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} mlops_db is accessible"
else
    echo -e "${RED}✗${NC} mlops_db is not accessible"
fi

if docker-compose exec -T postgres psql -U mlops -d mlflow_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} mlflow_db is accessible"
else
    echo -e "${RED}✗${NC} mlflow_db is not accessible"
fi

if docker-compose exec -T postgres psql -U mlops -d prefect_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} prefect_db is accessible"
else
    echo -e "${RED}✗${NC} prefect_db is not accessible"
fi

echo ""
echo "Service Details:"
echo "----------------"

# Get MLflow version
mlflow_version=$(curl -sf http://localhost:5000/version 2>/dev/null || echo "N/A")
echo "MLflow Version: $mlflow_version"

# Get serving model info
model_info=$(curl -sf http://localhost:8000/model-info 2>/dev/null || echo "N/A")
echo "Current Model: $model_info"

# Get container status
echo ""
echo "Container Status:"
echo "-----------------"
docker-compose ps

echo ""
echo "Health check complete!"