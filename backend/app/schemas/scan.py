from pydantic import BaseModel, field_validator
from typing import List

class ScanResponse(BaseModel):
    status: str
    message: str | None = None
    data: dict

class ScanListResponse(BaseModel):
    status: str
    data: dict

class ScanNameUpdate(BaseModel):
    product_name: str

    @field_validator("product_name")
    @classmethod
    def _clean_name(cls, value: str) -> str:
        # Rapikan spasi/newline hasil paste, tolak kosong dan kepanjangan.
        name = " ".join(value.split())
        if not name:
            raise ValueError("Nama produk tidak boleh kosong")
        if len(name) > 150:
            raise ValueError("Nama produk maksimal 150 karakter")
        return name