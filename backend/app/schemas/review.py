from typing import Literal

from pydantic import BaseModel, Field


class ScanReviewRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    verdict: Literal["Cocok", "Tidak Cocok"]
    comment: str | None = Field(default=None, max_length=500)
