from pydantic import BaseModel
from typing import List

class ScanResponse(BaseModel):
    status: str
    message: str | None = None
    data: dict

class ScanListResponse(BaseModel):
    status: str
    data: dict