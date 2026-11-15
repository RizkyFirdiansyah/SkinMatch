from pydantic import BaseModel
from typing import Literal

class ProfileResponse(BaseModel):
    status: str
    message: str | None = None
    data: dict

class UpdateProfileRequest(BaseModel):
    skin_type: str  # "Normal" | "Kering" | "Berminyak" | "Sensitif"
    age_range: Literal["18-24", "25-34", "35-44", "45+"] | None = None
    biological_sex: Literal["FEMALE", "MALE"] | None = None