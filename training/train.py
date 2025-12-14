"""
Model training script for price prediction pipeline.
This script will be executed by Prefect flows or can be run standalone.
"""

import os
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main training function."""
    logger.info("Training service started")
    logger.info(f"MLflow Tracking URI: {os.getenv('MLFLOW_TRACKING_URI', 'not set')}")
    logger.info(f"Database URL: {os.getenv('DATABASE_URL', 'not set')}")

    # Keep the container running (training will be triggered by Prefect flows)
    logger.info("Waiting for training jobs from Prefect...")

    # This will be replaced with actual training logic
    import time
    while True:
        time.sleep(60)
        logger.info(f"Training service is alive - {datetime.now()}")


if __name__ == "__main__":
    main()
