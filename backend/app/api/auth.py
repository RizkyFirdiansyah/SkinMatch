from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, AuthResponse
from app.utils.security import hash_password, verify_password
from app.services.auth_service import create_access_token

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post("/register", response_model=AuthResponse, status_code=201)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    """
    Register user baru
    - Auto-login setelah register (return token)
    - Profile setup mandatory setelah ini
    """
    
    # 1. Check if email already exists
    existing_user = db.query(User).filter(User.email == request.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email sudah terdaftar"
        )
    
    # 2. Validate password
    if len(request.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password minimal 8 karakter"
        )
    
    if request.password != request.confirm_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password dan konfirmasi password tidak sama"
        )
    
    # 3. Create new user
    new_user = User(
        name=request.name,
        email=request.email,
        hashed_password=hash_password(request.password),
        profile_completed=False
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # 4. Auto-login: generate JWT token
    token = create_access_token(data={"sub": str(new_user.id)})
    
    # 5. Return response
    return {
        "status": "success",
        "message": "Registrasi berhasil. Silakan setup profil kulit Anda.",
        "data": {
            "user_id": new_user.id,
            "name": new_user.name,
            "email": new_user.email,
            "token": token,
            "profile_completed": new_user.profile_completed
        }
    }

@router.post("/login", response_model=AuthResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """
    Login user
    - Return JWT token untuk authentication
    - Token valid 30 hari
    """
    
    # 1. Find user by email
    user = db.query(User).filter(User.email == request.email).first()
    
    # 2. Verify password
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email atau password salah"
        )
    
    # 3. Generate token
    token = create_access_token(data={"sub": str(user.id)})
    
    # 4. Return response
    return {
        "status": "success",
        "data": {
            "user_id": user.id,
            "name": user.name,
            "email": user.email,
            "skin_type": user.skin_type.value if user.skin_type else None,
            "token": token,
            "profile_completed": user.profile_completed
        }
    }