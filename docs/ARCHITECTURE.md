# System Architecture

## Overview

Price Prediction Pipeline is a production-ready, end-to-end machine learning system designed for automated training, deployment, and monitoring of regression models.

## Architecture Principles

### 1. Modularity
Each component is containerized and can be scaled independently:
- Training service scales for parallel experiments
- Serving service scales for high throughput
- Monitoring stack runs separately from core services

### 2. Observability
Every layer is instrumented:
- Application metrics (Prometheus)
- Custom ML metrics (MLflow)
- Business metrics (PostgreSQL)
- Visualization (Grafana)

### 3. Reproducibility
All experiments are tracked:
- Code version (Git SHA)
- Data version (DVC or similar)
- Dependencies (requirements.txt)
- Hyperparameters (MLflow)
- Environment (Docker)

## Component Details

### Data Layer

#### PostgreSQL
- **Purpose**: Central data store for all metadata
- **Schemas**:
  - `price_data`: Raw and processed features
  - `model_registry`: Model metadata and deployment history
  - `monitoring`: Predictions, metrics, and drift detection
- **Scaling**: Master-slave replication for read-heavy workloads
- **Backup**: Automated daily backups with point-in-time recovery

#### MinIO (Optional)
- **Purpose**: S3-compatible object storage for large artifacts
- **Use Cases**:
  - Model binaries
  - Large datasets
  - Feature stores
- **Benefits**: Local development with cloud-compatible API

### Orchestration Layer

#### Prefect
- **Purpose**: Workflow orchestration and scheduling
- **Key Flows**:
  1. **ETL Flow**: Data ingestion and preprocessing
  2. **Training Flow**: Model training and evaluation
  3. **Drift Detection Flow**: Monitor feature/target drift
  4. **Deployment Flow**: Model promotion and rollout

**Why Prefect over Airflow?**
- Modern Python-first API
- Dynamic DAGs
- Better error handling
- Native cloud support
- Easier local development

**Flow Example**:
```python
@flow(name="training-pipeline")
def train_model():
    data = extract_data()
    features = transform_data(data)
    model = train_model(features)
    metrics = evaluate_model(model)
    register_model(model, metrics)
```

### Training Layer

#### Training Service
- **Purpose**: Model training and experimentation
- **Features**:
  - Automated hyperparameter tuning (Optuna)
  - Cross-validation
  - Feature engineering pipelines
  - Model interpretability (SHAP, LIME)

**Training Pipeline Stages**:
```
Data Validation → Feature Engineering → Model Training
     ↓                    ↓                   ↓
Great Expectations   Preprocessing      Hyperparameter
                     Pipeline          Optimization
                                            ↓
                                      Model Evaluation
                                            ↓
                                      MLflow Tracking
```

#### MLflow
- **Purpose**: Experiment tracking and model registry
- **Components**:
  - **Tracking Server**: Log experiments, metrics, parameters
  - **Model Registry**: Version control for models
  - **Artifact Store**: Store model binaries and plots

**Model Lifecycle**:
```
None → Staging → Production → Archived
        ↑           ↑
        └───────────┘
     (validation required)
```

### Serving Layer

#### FastAPI Service
- **Purpose**: Real-time model inference
- **Endpoints**:
  - `POST /predict`: Make predictions
  - `GET /health`: Health check
  - `GET /metrics`: Prometheus metrics
  - `GET /model-info`: Current model metadata

**Features**:
- Automatic API documentation (Swagger/OpenAPI)
- Request/response validation (Pydantic)
- Rate limiting
- Caching (Redis)
- Load balancing ready

**Prediction Flow**:
```
Request → Validation → Feature Transform → Model Inference
   ↓           ↓              ↓                  ↓
Logging    Schema Check   Preprocessing    Cached Model
                                                 ↓
                                           Response
                                                 ↓
                                        Monitoring
```

#### Redis
- **Purpose**: Caching and session management
- **Use Cases**:
  - Model cache (avoid reloading)
  - Feature cache (reduce computation)
  - Rate limiting
  - Prediction queue (async processing)

### Monitoring Layer

#### Prometheus
- **Purpose**: Time-series metrics collection
- **Metrics Collected**:
  - System metrics (CPU, memory, disk)
  - Application metrics (request rate, latency)
  - ML metrics (prediction distribution, inference time)
  - Business metrics (prediction accuracy, drift scores)

**Custom Metrics**:
```python
prediction_latency = Histogram('prediction_latency_seconds', 
                               'Time to make prediction')
prediction_count = Counter('predictions_total', 
                          'Total predictions made')
model_accuracy = Gauge('model_accuracy', 
                       'Current model accuracy')
```

#### Grafana
- **Purpose**: Metrics visualization
- **Dashboards**:
  1. **System Overview**: Infrastructure health
  2. **Model Performance**: Accuracy, latency, throughput
  3. **Data Quality**: Drift detection, data distribution
  4. **Business Metrics**: ROI, prediction value

**Example Dashboard Panels**:
- Prediction volume over time
- Model accuracy trend
- Feature drift heatmap
- Error rate by endpoint
- P95 latency
- Resource utilization

## Data Flow

### Training Flow
```
1. Raw Data → PostgreSQL (price_data.raw_data)
2. Prefect ETL Flow → Feature Engineering
3. Processed Features → PostgreSQL (price_data.processed_features)
4. Prefect Training Flow → Model Training
5. Trained Model → MLflow (tracking + artifacts)
6. Model Metrics → PostgreSQL (monitoring.model_metrics)
7. Model Registration → MLflow Model Registry
```

### Inference Flow
```
1. API Request → FastAPI
2. Feature Extraction → Preprocessing Pipeline
3. Model Loading → Redis Cache or MLflow
4. Prediction → Model Inference
5. Response → Client
6. Logging → PostgreSQL (monitoring.predictions)
7. Metrics → Prometheus
```

### Continuous Training Flow
```
1. Scheduled Trigger (daily) → Prefect
2. Drift Detection → Compare distributions
3. If Drift Detected → Trigger Training Flow
4. New Model Training → MLflow Tracking
5. Model Validation → Compare with production
6. Auto/Manual Promotion → Model Registry
7. Deployment → Update Serving
8. Monitoring → Track new model performance
```

## Scaling Strategies

### Horizontal Scaling

**Training Service**:
```yaml
# Scale for parallel experiments
docker-compose up -d --scale training=5
```

**Serving Service**:
```yaml
# Scale for high traffic
docker-compose up -d --scale serving=10
```

**Database**:
- Read replicas for analytics queries
- Connection pooling (PgBouncer)
- Partitioning for large tables

### Vertical Scaling

**Resource Limits**:
```yaml
services:
  training:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
```

### Caching Strategy

**Multi-Level Cache**:
1. **L1**: In-memory cache (model in RAM)
2. **L2**: Redis cache (feature cache)
3. **L3**: Database query cache

## High Availability

### Service Redundancy
- Multiple serving instances behind load balancer
- Database replication (master-slave)
- Redis cluster mode for cache

### Failure Handling
- Health checks on all services
- Automatic container restart
- Circuit breakers in API calls
- Graceful degradation (fallback models)

### Backup & Recovery
- Automated database backups (daily)
- Model artifact versioning (immutable)
- Configuration as code (Git)
- Disaster recovery plan

## Security

### Network Security
```
External Network (Internet)
    ↓
Load Balancer (HTTPS)
    ↓
Internal Network (Docker Bridge)
    ↓
Services (No direct external access)
```

### Authentication & Authorization
- API keys for external access
- JWT tokens for user sessions
- Role-based access control (RBAC)
- Secrets management (Docker secrets, Vault)

### Data Security
- Encryption at rest (database)
- Encryption in transit (TLS)
- PII data masking
- Audit logging

## Performance Optimization

### Inference Optimization
- Model quantization (reduce size)
- Batch prediction support
- Async processing for non-real-time
- GPU acceleration (optional)

### Database Optimization
- Indexes on frequently queried columns
- Table partitioning for time-series data
- Materialized views for aggregations
- Connection pooling

### Network Optimization
- Response compression (gzip)
- CDN for static assets
- Edge computing for global deployments

## Monitoring & Alerting

### Key Metrics

**System Health**:
- Service uptime
- Resource utilization (CPU, memory, disk)
- Network latency

**ML Performance**:
- Prediction accuracy
- Inference latency (P50, P95, P99)
- Model drift
- Data quality

**Business Metrics**:
- Prediction volume
- Error rate
- Feature coverage

### Alerting Rules

**Critical Alerts** (PagerDuty):
- Service down > 5 minutes
- Error rate > 5%
- Prediction accuracy drop > 10%

**Warning Alerts** (Slack):
- High latency (P95 > 200ms)
- Resource utilization > 80%
- Data drift detected

## Future Enhancements

### Short Term
- [ ] Add model A/B testing
- [ ] Implement canary deployments
- [ ] Add data versioning (DVC)
- [ ] Create more Grafana dashboards

### Medium Term
- [ ] Kubernetes deployment
- [ ] Multi-region support
- [ ] Feature store (Feast)
- [ ] Online learning pipeline

### Long Term
- [ ] AutoML integration
- [ ] Edge deployment
- [ ] Federated learning
- [ ] Real-time streaming inference