from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.database import get_db
from app.api import auth, profile, scans, search
import os

app = FastAPI(
    title="SkinMatch API",
    description="Backend API untuk analisis kecocokan kosmetik",
    version="1.0.0"
)

# Create uploads directory if not exists
os.makedirs("uploads/scans", exist_ok=True)
os.makedirs("uploads/profiles", exist_ok=True)

# Mount static files
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(scans.router)
app.include_router(search.router)

@app.get("/")
def root():
    return {"message": "SkinMatch API is running", "version": "1.0.0"}

@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        # Test database connection
        db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": f"error: {str(e)}"}