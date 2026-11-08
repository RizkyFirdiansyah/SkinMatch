from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="SkinMatch API",
    description="Backend API untuk analisis kecocokan kosmetik",
    version="1.0.0"
)

# CORS - allow Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Production: ganti dengan specific domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "SkinMatch API is running", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "database": "not connected yet"}