FROM python:3.11-slim AS prefect-worker

WORKDIR /opt/prefect

# Install system dependencies required for ML libraries
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file from airflow-or-prefect directory
COPY airflow-or-prefect/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set Python path and environment variables
ENV PYTHONPATH=/opt/prefect:/opt/prefect/flows:/opt/prefect/training
ENV PYTHONUNBUFFERED=1

# Default command to start Prefect worker (will be overridden by docker-compose)
CMD ["prefect", "worker", "start", "--pool", "default-pool", "--type", "process"]
