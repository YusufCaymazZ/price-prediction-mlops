import logging
from prefect import flow, task
import pandas as pd
from sqlalchemy import create_engine, text
import os
import requests
from datetime import datetime, timedelta

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@task(name="get_last_timestamp")
def get_last_timestamp(table_name: str = "bitcoin_prices", symbol: str = "BTC-USD") -> str:
    """Get the last timestamp from database for incremental updates."""
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise ValueError("DATABASE_URL environment variable not set")
    
    engine = create_engine(db_url)
    
    try:
        with engine.connect() as conn:
            result = conn.execute(text(f"""
                SELECT MAX(timestamp) 
                FROM price_data.{table_name}
                WHERE symbol = :symbol
            """), {"symbol": symbol})
            last_ts = result.scalar()
            
            if last_ts:
                logger.info(f"✓ Last timestamp for {symbol}: {last_ts}")
                # Return next day to avoid duplicates
                next_date = (pd.Timestamp(last_ts) + timedelta(hours=1)).strftime("%Y-%m-%d")
                return next_date
            else:
                logger.info(f"✓ No data found for {symbol}, fetching last 30 days")
                start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
                return start_date
                
    except Exception as e:
        logger.warning(f"⚠ Could not get last timestamp (table might not exist): {e}")
        # Return 30 days back as default
        start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
        return start_date
    finally:
        engine.dispose()

@task(name="fetch_from_binance")
def fetch_from_binance(symbol: str, start_date: str, end_date: str) -> pd.DataFrame:
    """Fetch OHLCV data from Binance API."""
    logger.info(f"Fetching {symbol} from Binance ({start_date} to {end_date})...")
    
    # Convert symbol format: BTC-USD -> BTCUSDT
    binance_symbol = symbol.replace("-", "").replace("USD", "USDT")
    
    try:
        # Binance API endpoint
        url = "https://api.binance.com/api/v3/klines"
        
        start_ts = int(pd.Timestamp(start_date).timestamp() * 1000)
        end_ts = int(pd.Timestamp(end_date).timestamp() * 1000)
        
        all_data = []
        current_ts = start_ts
        
        while current_ts < end_ts:
            params = {
                'symbol': binance_symbol,
                'interval': '1h',
                'startTime': current_ts,
                'endTime': end_ts,
                'limit': 1000
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if not data:
                break
            
            all_data.extend(data)
            # Move to next batch (1 hour interval)
            current_ts = data[-1][0] + 1000 * 3600
        
        # Convert to DataFrame
        df = pd.DataFrame(all_data, columns=[
            'timestamp', 'open', 'high', 'low', 'close', 'volume',
            'close_time', 'quote_volume', 'trades', 'buy_base', 'buy_quote', 'ignore'
        ])
        
        df['timestamp'] = pd.to_datetime(df['timestamp'].astype(int), unit='ms')
        df['open'] = df['open'].astype(float)
        df['high'] = df['high'].astype(float)
        df['low'] = df['low'].astype(float)
        df['close'] = df['close'].astype(float)
        df['volume'] = df['volume'].astype(float)
        df['adj_close'] = df['close']
        df['symbol'] = symbol
        df['source'] = 'binance'
        
        # Keep only necessary columns
        df = df[['timestamp', 'open', 'high', 'low', 'close', 'adj_close', 'volume', 'symbol', 'source']]
        
        logger.info(f"✓ Fetched {len(df)} rows from Binance")
        return df
        
    except Exception as e:
        logger.error(f"✗ Binance fetch failed: {e}")
        raise

@task(name="save_to_postgres")
def save_to_postgres(df: pd.DataFrame, table_name: str = "bitcoin_prices") -> dict:
    """Save DataFrame to PostgreSQL."""
    if df.empty:
        logger.warning("No data to save")
        return {"rows_saved": 0, "status": "empty"}
    
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise ValueError("DATABASE_URL environment variable not set")
    
    engine = create_engine(db_url)
    
    try:
        with engine.begin() as conn:
            # Create schema
            conn.execute(text("CREATE SCHEMA IF NOT EXISTS price_data"))
            
            # Create table if not exists
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS price_data.bitcoin_prices (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP NOT NULL,
                    open DECIMAL(18,8),
                    high DECIMAL(18,8),
                    low DECIMAL(18,8),
                    close DECIMAL(18,8),
                    adj_close DECIMAL(18,8),
                    volume DECIMAL(18,8),
                    symbol VARCHAR(20),
                    source VARCHAR(50),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(timestamp, symbol)
                )
            """))
            
            # Delete overlapping data to avoid duplicates
            min_date = df['timestamp'].min()
            max_date = df['timestamp'].max()
            conn.execute(text(f"""
                DELETE FROM price_data.{table_name}
                WHERE timestamp BETWEEN :min_date AND :max_date
                  AND symbol = :symbol
            """), {"min_date": min_date, "max_date": max_date, "symbol": df['symbol'].iloc[0]})
        
        # Insert new data
        df.to_sql(table_name, engine, schema="price_data", if_exists="append", index=False)
        
        logger.info(f"✓ Saved {len(df)} rows to price_data.{table_name}")
        return {"rows_saved": len(df), "status": "success"}
        
    except Exception as e:
        logger.error(f"✗ Save to Postgres failed: {e}")
        raise
    finally:
        engine.dispose()

@task(name="load_from_postgres")
def load_from_postgres(table_name: str = "bitcoin_prices") -> pd.DataFrame:
    """Load data from PostgreSQL."""
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise ValueError("DATABASE_URL environment variable not set")
    
    engine = create_engine(db_url)
    
    try:
        query = f"SELECT * FROM price_data.{table_name} ORDER BY timestamp"
        df = pd.read_sql(query, engine)
        logger.info(f"✓ Loaded {len(df)} rows from price_data.{table_name}")
        return df
        
    except Exception as e:
        logger.error(f"✗ Load from Postgres failed: {e}")
        raise
    finally:
        engine.dispose()

@flow(name="binance-ingestion-flow", description="Ingest cryptocurrency data from Binance")
def binance_ingestion_flow(symbol: str = "BTC-USD", incremental: bool = True):
    """
    Main ETL flow: Fetch from Binance and ingest to Postgres.
    
    Args:
        symbol: Crypto symbol (e.g., 'BTC-USD')
        incremental: If True, fetch only new data since last timestamp
    """
    logger.info("=" * 60)
    logger.info(f"Starting Binance Ingestion Flow: {symbol}")
    logger.info(f"Mode: {'Incremental' if incremental else 'Full (30 days)'}")
    logger.info("=" * 60)
    
    # Get date range
    end_date = datetime.now().strftime("%Y-%m-%d")
    
    if incremental:
        # Get last timestamp from database
        start_date = get_last_timestamp(symbol=symbol)
        logger.info(f"Incremental update from {start_date} to {end_date}")
    else:
        # Full load - last 30 days
        start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
        logger.info(f"Full load from {start_date} to {end_date}")
    
    # Fetch from Binance
    data = fetch_from_binance(symbol, start_date, end_date)
    
    # Save to Postgres
    result = save_to_postgres(data)
    
    logger.info("=" * 60)
    logger.info(f"Flow completed: {result}")
    logger.info("=" * 60)
    
    return result

if __name__ == "__main__":
    # Test run
    result = binance_ingestion_flow(symbol="BTC-USD", incremental=True)
    print(result)