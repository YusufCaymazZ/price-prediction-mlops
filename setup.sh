#!/bin/bash

# Price Prediction Pipeline Setup Script
# This script sets up the entire ML pipeline infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║   Price Prediction ML Pipeline - Setup Script         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose found${NC}"

# Create necessary directories
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p data/{raw,processed,models}
mkdir -p logs
mkdir -p backups
mkdir -p monitoring/grafana/dashboards/json
mkdir -p tests

# Create .gitkeep files
touch data/raw/.gitkeep
touch data/processed/.gitkeep
touch logs/.gitkeep
touch backups/.gitkeep

echo -e "${GREEN}✓ Directory structure created${NC}"

# Setup environment file
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cp .env.example .env
    
    # Generate secure passwords
    if command -v openssl &> /dev/null; then
        PG_PASS=$(openssl rand -base64 32)
        GRAFANA_PASS=$(openssl rand -base64 32)
        MINIO_PASS=$(openssl rand -base64 32)
        
        sed -i.bak "s/mlops_secure_2024/$PG_PASS/g" .env
        sed -i.bak "s/admin_secure_2024/$GRAFANA_PASS/g" .env
        sed -i.bak "s/minioadmin_secure_2024/$MINIO_PASS/g" .env
        rm .env.bak
        
        echo -e "${GREEN}✓ .env file created with secure passwords${NC}"
        echo -e "${YELLOW}Important: Save these credentials!${NC}"
        echo -e "PostgreSQL Password: ${PG_PASS}"
        echo -e "Grafana Password: ${GRAFANA_PASS}"
        echo -e "MinIO Password: ${MINIO_PASS}"
    else
        echo -e "${YELLOW}⚠ OpenSSL not found. Using default passwords.${NC}"
        echo -e "${RED}WARNING: Please change passwords in .env file before production use!${NC}"
    fi
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Build Docker images
echo -e "${YELLOW}Building Docker images...${NC}"
docker-compose build --parallel

echo -e "${GREEN}✓ Docker images built${NC}"

# Start services
echo -e "${YELLOW}Starting services...${NC}"
docker-compose up -d

echo -e "${GREEN}✓ Services started${NC}"

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
sleep 15

# Check service health
echo -e "${YELLOW}Checking service health...${NC}"

check_service() {
    SERVICE=$1
    URL=$2
    if curl -sf "$URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $SERVICE is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ $SERVICE is not responding${NC}"
        return 1
    fi
}

HEALTH_OK=true

check_service "PostgreSQL" "http://localhost:5432" || HEALTH_OK=false
check_service "MLflow" "http://localhost:5000/health" || HEALTH_OK=false
check_service "Prefect" "http://localhost:4200/api/health" || HEALTH_OK=false
check_service "Serving API" "http://localhost:8000/health" || HEALTH_OK=false
check_service "Prometheus" "http://localhost:9090/-/healthy" || HEALTH_OK=false
check_service "Grafana" "http://localhost:3000/api/health" || HEALTH_OK=false

# Initialize Prefect work pool
echo -e "${YELLOW}Initializing Prefect work pool...${NC}"
docker-compose exec -T prefect-worker prefect work-pool create default-pool --type process 2>/dev/null || true
echo -e "${GREEN}✓ Prefect work pool initialized${NC}"

# Display access information
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Setup Complete! 🎉                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Access your services at:${NC}"
echo ""
echo -e "  ${GREEN}MLflow UI:${NC}      http://localhost:5000"
echo -e "  ${GREEN}Prefect UI:${NC}     http://localhost:4200"
echo -e "  ${GREEN}API Docs:${NC}       http://localhost:8000/docs"
echo -e "  ${GREEN}Grafana:${NC}        http://localhost:3000"
echo -e "  ${GREEN}Prometheus:${NC}     http://localhost:9090"
echo -e "  ${GREEN}MinIO:${NC}          http://localhost:9001"
echo ""

echo -e "${YELLOW}Default credentials:${NC}"
echo -e "  Grafana: admin / (check .env file)"
echo -e "  MinIO: minioadmin / (check .env file)"
echo ""

echo -e "${YELLOW}Quick commands:${NC}"
echo -e "  ${GREEN}make logs${NC}           - View all logs"
echo -e "  ${GREEN}make health${NC}         - Check service health"
echo -e "  ${GREEN}make dev-train${NC}      - Run training"
echo -e "  ${GREEN}make down${NC}           - Stop all services"
echo ""

if [ "$HEALTH_OK" = false ]; then
    echo -e "${RED}⚠ Some services are not healthy. Check logs with: make logs${NC}"
    exit 1
fi

echo -e "${GREEN}All services are running! Happy ML Engineering! 🚀${NC}"