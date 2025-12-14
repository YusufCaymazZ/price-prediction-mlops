# Price Prediction E2E ML Pipeline

Production-ready end-to-end machine learning pipeline for price prediction with automated training, deployment, and monitoring.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Data Sources                             │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              Prefect Orchestration Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  ETL Flow    │  │ Training Flow│  │  Drift Check │      │
│  │   (Cron)     │  │    (CT)      │  │     Flow     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   Training Pipeline                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Data Processing → Feature Eng → Model Training      │   │
│  │  → Validation → MLflow Tracking → Model Registry     │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    MLflow Registry                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Staging   │→ │  Production  │← │   Archive    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   Model Serving (FastAPI)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  /predict  /health  /metrics  /model-info           │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              Monitoring & Observability                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Prometheus  │→ │   Grafana    │← │  PostgreSQL  │      │
│  │   (Metrics)  │  │ (Dashboards) │  │   (Logs)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose (v2.0+)
- Make (optional, for convenience)
- 8GB+ RAM recommended

### Initial Setup

```bash
# Clone repository
git clone <your-repo>
cd price-prediction

# Setup everything (one command)
make setup

# Or manually:
cp .env.example .env
docker-compose build
docker-compose up -d
make init-db
make init-prefect
```

### Access Services

After startup, access the following services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **MLflow UI** | http://localhost:5000 | - |
| **Prefect UI** | http://localhost:4200 | - |
| **API Docs** | http://localhost:8000/docs | - |
| **Grafana** | http://localhost:3000 | admin / your_grafana_password |
| **Prometheus** | http://localhost:9090 | - |
| **MinIO** | http://localhost:9001 | minioadmin / your_minio_password |

## 📦 Services

### Core Services

1. **PostgreSQL** - Central database for all metadata
2. **MLflow** - Experiment tracking and model registry
3. **Prefect Server & Worker** - Workflow orchestration
4. **Training Service** - Model training pipeline
5. **Serving Service** - FastAPI model serving
6. **Redis** - Caching and queue management

### Monitoring Stack

7. **Prometheus** - Metrics collection
8. **Grafana** - Visualization dashboards
9. **MinIO** - S3-compatible artifact storage (optional)

## 🔧 Common Operations

### Training

```bash
# Trigger manual training
make dev-train

# Check training logs
make logs-training

# Access training shell
make shell-training
```

### Serving

```bash
# Check serving logs
make logs-serving

# Scale serving instances
make scale-serving n=4

# Test prediction endpoint
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [1.0, 2.0, 3.0]}'
```

### Monitoring

```bash
# Check all service health
make health

# Open Grafana dashboards
make dashboards

# Open Prometheus
make metrics

# View MLflow experiments
make mlflow-ui
```

### Database Operations

```bash
# Create backup
make backup-db

# Restore from backup
make restore-db

# Access database shell
docker-compose exec postgres psql -U mlops -d mlops_db
```

## 📊 Database Schema

The system uses PostgreSQL with the following schemas:

- **price_data** - Raw and processed feature data
- **model_registry** - Model metadata and deployment history
- **monitoring** - Predictions, metrics, and drift detection

Key tables:
- `price_data.raw_data` - Incoming raw data
- `price_data.processed_features` - Engineered features
- `model_registry.models` - Model versions and metadata
- `monitoring.predictions` - Prediction logs with actuals
- `monitoring.drift_metrics` - Feature drift tracking

## 🔄 Continuous Training (CT)

The pipeline supports automated retraining through Prefect flows:

1. **Data Collection Flow** - Runs on schedule (e.g., daily)
2. **Drift Detection Flow** - Monitors feature/target drift
3. **Training Flow** - Triggers when drift detected or scheduled
4. **Model Promotion Flow** - Validates and promotes models

### Deployment Strategies

- **Manual Rollout** - Requires approval in MLflow UI
- **Auto Rollout** - Automatic if metrics exceed threshold
- **Canary Deployment** - Gradual traffic shifting
- **Blue-Green** - Instant rollback capability

## 🔐 Security Considerations

### Production Checklist

- [x] Change all default passwords in `.env`
- [ ] Use secrets management (e.g., Docker secrets, Vault)
- [ ] Enable HTTPS/TLS for external endpoints
- [ ] Implement authentication (OAuth2, JWT)
- [ ] Set up network isolation
- [ ] Enable audit logging
- [ ] Configure backup strategies
- [ ] Implement rate limiting
- [ ] Use non-root users in containers

### Recommended Changes

```bash
# Generate secure passwords
openssl rand -base64 32

# Update in .env file
POSTGRES_PASSWORD=<your-secure-password>
GRAFANA_ADMIN_PASSWORD=<your-secure-password>
MINIO_ROOT_PASSWORD=<your-secure-password>
```

## 📈 Performance Tuning

### Serving Optimization

```yaml
# In docker-compose.yml, adjust:
serving:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 4G
  environment:
    WORKERS: 4  # CPU cores * 2
```

### Database Optimization

```sql
-- Create additional indexes for your queries
CREATE INDEX idx_custom ON monitoring.predictions(your_column);

-- Partition large tables
CREATE TABLE monitoring.predictions_2024 
  PARTITION OF monitoring.predictions
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

## 🧪 Testing

```bash
# Run all tests
make test

# Run specific test suite
docker-compose exec training pytest tests/test_training.py -v

# Run with coverage
docker-compose exec training pytest --cov=training tests/
```

## 📝 Development Workflow

1. **Feature Development**
   ```bash
   # Create feature branch
   git checkout -b feature/new-model
   
   # Develop locally
   docker-compose up -d
   make shell-training
   ```

2. **Testing**
   ```bash
   make test
   ```

3. **Deployment**
   ```bash
   git push origin feature/new-model
   # CI/CD pipeline triggers automatically
   ```

## 🐛 Troubleshooting

### Common Issues

**Services won't start**
```bash
# Check logs
make logs

# Restart services
make restart

# Clean and rebuild
make clean
make setup
```

**Database connection errors**
```bash
# Check database health
docker-compose exec postgres pg_isready -U mlops

# Reinitialize database
make init-db
```

**MLflow artifacts not loading**
```bash
# Check MLflow logs
make logs-mlflow

# Verify artifact location
docker-compose exec mlflow ls -la /mlflow/artifacts
```

## 📚 Project Structure

```
price-prediction/
├── infra/                    # Infrastructure configs
│   ├── init-db.sql          # Database initialization
│   └── mlflow/
│       └── Dockerfile       # MLflow container
├── airflow-or-prefect/      # Orchestration
│   ├── flows/               # Prefect flow definitions
│   │   ├── etl.py
│   │   ├── training.py
│   │   └── drift_check.py
│   ├── Dockerfile
│   └── requirements.txt
├── training/                 # Training pipeline
│   ├── train.py             # Main training script
│   ├── model/               # Model implementations
│   ├── Dockerfile
│   └── requirements.txt
├── serving/                  # Model serving
│   ├── app.py               # FastAPI application
│   ├── Dockerfile
│   └── requirements.txt
├── monitoring/               # Observability
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── datasources/
│   └── prometheus/
│       └── prometheus.yml
├── tests/                    # Test suites
├── docs/                     # Documentation
├── docker-compose.yml        # Service definitions
├── Makefile                  # Development commands
└── .env.example             # Configuration template
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

## 📄 License

[Your License Here]

## 🙏 Acknowledgments

- MLflow for experiment tracking
- Prefect for workflow orchestration
- FastAPI for high-performance serving
- Prometheus & Grafana for monitoring
