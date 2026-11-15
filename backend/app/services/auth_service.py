from datetime import datetime, timedelta
from jose import jwt, JWTError
from app.config import settings

def create_access_token(data: dict) -> str:
    """
    Generate JWT token
    data: {"sub": user_id}
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.ACCESS_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    return encoded_jwt

def decode_access_token(token: str) -> dict | None:
    """
    Decode JWT token
    Returns payload atau None jika invalid/expired
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError:
        return None