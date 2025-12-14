.PHONY: help build up down restart logs clean test init-db init-prefect health

# Default target
help:
	@echo "Price Prediction Pipeline - Make Commands"
	@echo "=========================================="
	@echo "setup          : Initial setup (copy .env, build, init)"
	@echo "build          : Build all Docker images"
	@echo "up             : Start all services"
	@echo "down           : Stop all services"
	@echo "restart        : Restart all services"
	@echo "logs           : Show logs from all services"
	@echo "logs-serving   : Show serving service logs"
	@echo "logs-training  : Show training service logs"
	@echo "logs-prefect   : Show Prefect logs"
	@echo "clean          : Remove all containers, volumes, and images"
	@echo "test           : Run tests"
	@echo "init-db        : Initialize database"
	@echo "init-prefect   : Initialize Prefect"
	@echo "health         : Check health of all services"
	@echo "scale-serving  : Scale serving service (usage: make scale-serving n=4)"
	@echo "backup-db      : Backup database"
	@echo "restore-db     : Restore database from backup"

# Initial setup
setup:
	@echo "Setting up Price Prediction Pipeline..."
	@cp .env.example .env
	@echo ".env file created. Please update with your values."
	@make build
	@make up
	@sleep 10
	@make init-db
	@make init-prefect
	@make health
	@echo "Setup complete! Access services at:"
	@echo "  - MLflow: http://localhost:5000"
	@echo "  - Prefect: http://localhost:4200"
	@echo "  - Serving API: http://localhost:8000"
	@echo "  - Grafana: http://localhost:3000"
	@echo "  - Prometheus: http://localhost:9090"

# Build all images
build:
	@echo "Building Docker images..."
	docker-compose build --parallel

# Start services
up:
	@echo "Starting services..."
	docker-compose up -d
	@echo "Services started. Waiting for health checks..."
	@sleep 5
	@make health

# Stop services
down:
	@echo "Stopping services..."
	docker-compose down

# Restart services
restart:
	@echo "Restarting services..."
	@make down
	@make up

# Show logs
logs:
	docker-compose logs -f

logs-serving:
	docker-compose logs -f serving

logs-training:
	docker-compose logs -f training

logs-prefect:
	docker-compose logs -f prefect-server prefect-worker

logs-mlflow:
	docker-compose logs -f mlflow

# Clean everything
clean:
	@echo "Cleaning up everything..."
	docker-compose down -v --rmi all
	@echo "Cleanup complete!"

clean-volumes:
	@echo "Removing volumes only..."
	docker-compose down -v
	@echo "Volumes removed!"

# Run tests
test:
	@echo "Running tests..."
	docker-compose exec training pytest /app/tests -v
	@echo "Tests complete!"

# Initialize database
init-db:
	@echo "Initializing database..."
	@sleep 5
	docker-compose exec postgres psql -U mlops -d mlops_db -c "SELECT 'Database initialized successfully';"
	@echo "Database initialized!"

# Initialize Prefect
init-prefect:
	@echo "Initializing Prefect..."
	docker-compose exec prefect-worker prefect work-pool create default-pool --type process || true
	@echo "Prefect initialized!"

# Health checks
health:
	@echo "Checking service health..."
	@echo -n "PostgreSQL: "
	@docker-compose exec -T postgres pg_isready -U mlops && echo "✓" || echo "✗"
	@echo -n "MLflow: "
	@curl -sf http://localhost:5000/health > /dev/null && echo "✓" || echo "✗"
	@echo -n "Prefect: "
	@curl -sf http://localhost:4200/api/health > /dev/null && echo "✓" || echo "✗"
	@echo -n "Serving: "
	@curl -sf http://localhost:8000/health > /dev/null && echo "✓" || echo "✗"
	@echo -n "Redis: "
	@docker-compose exec -T redis redis-cli ping > /dev/null && echo "✓" || echo "✗"
	@echo -n "Prometheus: "
	@curl -sf http://localhost:9090/-/healthy > /dev/null && echo "✓" || echo "✗"
	@echo -n "Grafana: "
	@curl -sf http://localhost:3000/api/health > /dev/null && echo "✓" || echo "✗"

# Scale serving service
scale-serving:
	@echo "Scaling serving service to $(n) instances..."
	docker-compose up -d --scale serving=$(n)

# Database backup
backup-db:
	@echo "Creating database backup..."
	@mkdir -p backups
	docker-compose exec -T postgres pg_dump -U mlops mlops_db > backups/mlops_db_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Backup created in backups/ directory"

# Database restore
restore-db:
	@echo "Restoring database from backup..."
	@read -p "Enter backup filename: " backup_file; \
	docker-compose exec -T postgres psql -U mlops mlops_db < backups/$$backup_file
	@echo "Database restored!"

# Development helpers
dev-train:
	@echo "Running training locally..."
	docker-compose run --rm training python train.py

dev-serve:
	@echo "Starting serving in development mode..."
	docker-compose up serving

shell-training:
	docker-compose exec training /bin/bash

shell-serving:
	docker-compose exec serving /bin/bash

shell-prefect:
	docker-compose exec prefect-worker /bin/bash

# Monitoring
metrics:
	@echo "Opening Prometheus..."
	@open http://localhost:9090 || xdg-open http://localhost:9090

dashboards:
	@echo "Opening Grafana..."
	@open http://localhost:3000 || xdg-open http://localhost:3000

mlflow-ui:
	@echo "Opening MLflow..."
	@open http://localhost:5000 || xdg-open http://localhost:5000

prefect-ui:
	@echo "Opening Prefect..."
	@open http://localhost:4200 || xdg-open http://localhost:4200

# Production deployment
deploy-prod:
	@echo "Deploying to production..."
	@make build
	@make down
	@make up
	@make health
	@echo "Production deployment complete!"

# Update dependencies
update-deps:
	@echo "Updating dependencies..."
	docker-compose build --no-cache --pull