# Quick Reference Guide

## 🚀 Common Commands

### Setup & Initialization
```bash
# Complete setup
make setup

# Manual setup
cp .env.example .env
docker-compose build
docker-compose up -d
make init-db
make init-prefect
```

### Service Management
```bash
# Start all services
make up

# Stop all services
make down

# Restart all services
make restart

# Check service health
make health

# View logs
make logs                # All services
make logs-serving        # Serving only
make logs-training       # Training only
make logs-prefect        # Prefect only
```

### Training & Development
```bash
# Run training
make dev-train

# Access training shell
make shell-training

# Access serving shell
make shell-serving

# Access Prefect shell
make shell-prefect
```

### Monitoring
```bash
# Open monitoring interfaces
make mlflow-ui          # MLflow
make prefect-ui         # Prefect
make dashboards         # Grafana
make metrics            # Prometheus
```

### Database Operations
```bash
# Create backup
make backup-db

# Restore from backup
make restore-db

# Access database
docker-compose exec postgres psql -U mlops -d mlops_db
```

### Scaling
```bash
# Scale serving instances
make scale-serving n=4
```

### Cleanup
```bash
# Remove containers and volumes
make clean

# Remove volumes only
make clean-volumes
```

## 🔗 Service URLs

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| MLflow | http://localhost:5000 | None |
| Prefect | http://localhost:4200 | None |
| API Docs | http://localhost:8000/docs | None |
| Grafana | http://localhost:3000 | admin / (see .env) |
| Prometheus | http://localhost:9090 | None |
| MinIO | http://localhost:9001 | minioadmin / (see .env) |
| PostgreSQL | localhost:5432 | mlops / (see .env) |
| Redis | localhost:6379 | None |

## 📝 API Endpoints

### Health Check
```bash
curl http://localhost:8000/health
```

### Prediction
```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": {
      "feature1": 1.0,
      "feature2": 2.0,
      "feature3": 3.0
    }
  }'
```

### Model Info
```bash
curl http://localhost:8000/model-info
```

### Metrics
```bash
curl http://localhost:8000/metrics
```

## 🗄️ Database Queries

### Check Raw Data
```sql
SELECT COUNT(*) FROM price_data.raw_data;
SELECT * FROM price_data.raw_data LIMIT 5;
```

### Check Models
```sql
SELECT model_name, model_version, stage, created_at 
FROM model_registry.models 
ORDER BY created_at DESC;
```

### Check Predictions
```sql
SELECT COUNT(*), AVG(response_time_ms), AVG(error)
FROM monitoring.predictions
WHERE prediction_timestamp > NOW() - INTERVAL '1 day';
```

### Check Drift Metrics
```sql
SELECT feature_name, drift_score, drift_detected, created_at
FROM monitoring.drift_metrics
WHERE created_at > NOW() - INTERVAL '7 days'
ORDER BY drift_score DESC;
```

### Performance Summary
```sql
SELECT * FROM monitoring.model_performance_summary;
```

## 🔧 Docker Commands

### Container Management
```bash
# List running containers
docker-compose ps

# View container logs
docker-compose logs -f <service-name>

# Restart specific service
docker-compose restart <service-name>

# Execute command in container
docker-compose exec <service-name> <command>

# Remove specific container
docker-compose rm -f <service-name>
```

### Image Management
```bash
# List images
docker images

# Remove unused images
docker image prune -a

# Rebuild specific service
docker-compose build <service-name>

# Build without cache
docker-compose build --no-cache <service-name>
```

### Volume Management
```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect price-prediction_postgres_data

# Remove specific volume
docker volume rm price-prediction_postgres_data
```

### Network Management
```bash
# List networks
docker network ls

# Inspect network
docker network inspect price-prediction_mlops-network

# Check container connectivity
docker-compose exec serving ping postgres
```

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check logs
make logs

# Check Docker resources
docker system df

# Restart everything
make restart

# Clean and rebuild
make clean
make setup
```

### Database Connection Issues
```bash
# Check PostgreSQL health
docker-compose exec postgres pg_isready -U mlops

# Connect to database
docker-compose exec postgres psql -U mlops -d mlops_db

# Check connections
docker-compose exec postgres psql -U mlops -d mlops_db \
  -c "SELECT * FROM pg_stat_activity;"
```

### MLflow Issues
```bash
# Check MLflow logs
make logs-mlflow

# Verify backend connection
docker-compose exec mlflow env | grep MLFLOW

# Test MLflow API
curl http://localhost:5000/api/2.0/mlflow/experiments/list
```

### Serving API Issues
```bash
# Check serving logs
make logs-serving

# Verify model loading
docker-compose exec serving ls -la /mlflow/artifacts

# Test health endpoint
curl -v http://localhost:8000/health

# Check model info
curl http://localhost:8000/model-info
```

### Prefect Issues
```bash
# Check Prefect logs
make logs-prefect

# List work pools
docker-compose exec prefect-worker prefect work-pool ls

# Check flow runs
docker-compose exec prefect-worker prefect flow-run ls

# Test Prefect API
curl http://localhost:4200/api/health
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Check disk space
docker system df

# Check PostgreSQL performance
docker-compose exec postgres psql -U mlops -d mlops_db \
  -c "SELECT * FROM pg_stat_user_tables;"

# Vacuum database
docker-compose exec postgres psql -U mlops -d mlops_db \
  -c "VACUUM ANALYZE;"
```

### Network Issues
```bash
# Check network connectivity
docker-compose exec serving ping postgres
docker-compose exec serving ping mlflow

# Check DNS resolution
docker-compose exec serving nslookup postgres

# Inspect network
docker network inspect price-prediction_mlops-network
```

## 📊 Monitoring Queries

### Prometheus Queries

**Request Rate**:
```promql
rate(http_requests_total[5m])
```

**P95 Latency**:
```promql
histogram_quantile(0.95, rate(prediction_latency_seconds_bucket[5m]))
```

**Error Rate**:
```promql
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

**Model Accuracy**:
```promql
model_accuracy
```

### Database Monitoring
```sql
-- Table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables 
WHERE schemaname IN ('price_data', 'model_registry', 'monitoring')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Active connections
SELECT count(*), state FROM pg_stat_activity GROUP BY state;

-- Long running queries
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 minute';
```

## 🔐 Security Checklist

### Production Deployment
- [ ] Change all default passwords in `.env`
- [ ] Use secrets management (Docker secrets, Vault)
- [ ] Enable HTTPS/TLS
- [ ] Implement authentication (OAuth2, JWT)
- [ ] Set up firewall rules
- [ ] Enable audit logging
- [ ] Configure backup strategy
- [ ] Implement rate limiting
- [ ] Use non-root users in containers
- [ ] Regular security updates

### Environment Variables to Change
```bash
# Generate secure passwords
openssl rand -base64 32

# Update in .env
POSTGRES_PASSWORD=<your-secure-password>
GRAFANA_ADMIN_PASSWORD=<your-secure-password>
MINIO_ROOT_PASSWORD=<your-secure-password>
```

## 📚 Additional Resources

### Documentation
- [Architecture Overview](./ARCHITECTURE.md)
- [API Documentation](http://localhost:8000/docs)
- [MLflow Docs](https://mlflow.org/docs/latest/index.html)
- [Prefect Docs](https://docs.prefect.io/)
- [FastAPI Docs](https://fastapi.tiangolo.com/)

### Monitoring Dashboards
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- MLflow: http://localhost:5000

### Development Tools
- API Docs: http://localhost:8000/docs
- Prefect UI: http://localhost:4200
- MinIO Console: http://localhost:9001

## 💡 Tips & Best Practices

### Performance
- Use connection pooling for database
- Implement caching strategy (Redis)
- Batch predictions when possible
- Monitor and optimize slow queries
- Use indexes on frequently queried columns

### Development
- Use `.env.example` for sensitive data
- Write tests for critical paths
- Use type hints in Python code
- Document API endpoints
- Version control your data

### Operations
- Monitor system resources
- Set up alerting rules
- Regular backups (automated)
- Test disaster recovery plan
- Keep dependencies updated

### ML Best Practices
- Track all experiments in MLflow
- Validate data quality before training
- Monitor model drift continuously
- A/B test model changes
- Document model assumptions    