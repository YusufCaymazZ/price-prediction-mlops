from fastapi import FastAPI

app = FastAPI()  # This must exist!

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/model-info")
def model_info():
    return {"model": "price-prediction-v1", "version": "1.0.0", "status": "ready"}