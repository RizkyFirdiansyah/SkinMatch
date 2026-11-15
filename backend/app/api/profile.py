from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.api.deps import get_current_user
from app.models.user import User, SkinTypeEnum
from app.schemas.profile import ProfileResponse, UpdateProfileRequest

router = APIRouter(prefix="/api/profile", tags=["Profile"])

@router.get("", response_model=ProfileResponse)
def get_profile(current_user: User = Depends(get_current_user)):
    """
    Get user profile
    - Require authentication (JWT token)
    """
    return {
        "status": "success",
        "data": {
            "user_id": current_user.id,
            "name": current_user.name,
            "email": current_user.email,
            "skin_type": current_user.skin_type.value if current_user.skin_type else None,
            "profile_completed": current_user.profile_completed
        }
    }

@router.put("", response_model=ProfileResponse)
def update_profile(
    request: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update user skin type
    - Mandatory setelah register
    - Bisa diubah kapan saja
    """
    
    # Validate skin type
    valid_types = ["Normal", "Kering", "Berminyak", "Sensitif"]
    if request.skin_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tipe kulit tidak valid",
            headers={"valid_options": ", ".join(valid_types)}
        )
    
    # Update user
    current_user.skin_type = SkinTypeEnum(request.skin_type)
    current_user.profile_completed = True
    
    db.commit()
    db.refresh(current_user)
    
    return {
        "status": "success",
        "message": "Profil berhasil diperbarui",
        "data": {
            "user_id": current_user.id,
            "name": current_user.name,
            "email": current_user.email,
            "skin_type": current_user.skin_type.value,
            "profile_completed": current_user.profile_completed
        }
    }