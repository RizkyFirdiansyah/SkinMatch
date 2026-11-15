from pydantic import BaseModel

class ProfileResponse(BaseModel):
    status: str
    message: str | None = None
    data: dict

class UpdateProfileRequest(BaseModel):
    skin_type: str  # "Normal" | "Kering" | "Berminyak" | "Sensitif"