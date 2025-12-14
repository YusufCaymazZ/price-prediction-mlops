FROM python:3.11-slim

WORKDIR /mlflow

# System dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
RUN pip install --no-cache-dir \
    mlflow==2.9.2 \
    psycopg2-binary==2.9.9 \
    boto3==1.34.18 \
    scikit-learn==1.4.0 \
    pandas==2.1.4 \
    numpy==1.26.3 \
    xgboost==2.0.3 \
    lightgbm==4.2.0

# Create artifacts directory
RUN mkdir -p /mlflow/artifacts

EXPOSE 5000

CMD ["sh", "-c", \
     "mlflow server \
     --backend-store-uri ${MLFLOW_BACKEND_STORE_URI} \
     --default-artifact-root ${MLFLOW_ARTIFACT_ROOT} \
     --host 0.0.0.0 \
     --port 5000"]
