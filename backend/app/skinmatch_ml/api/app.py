"""API minimal SkinMatch - untuk smoke deploy P0b (SPEC-ML §10).

Sengaja kecil: hanya membuktikan bahwa container Linux di Hugging Face Spaces
dapat memuat model dan melakukan inferensi OCR. Pipeline klasifikasi belum
disambungkan di sini.

Endpoint:
    GET  /          penanda hidup (untuk warm-up dari splash screen Flutter)
    GET  /health    status model, versi pustaka, waktu muat, uptime
    POST /v1/scan   unggah gambar -> baris teks + skor keyakinan

Variabel lingkungan:
    OCR_TIER       tiny | small | medium (default: small, SPEC-ML §12.5)
    ENABLE_MKLDNN  1/0 (default: ikut platform; di Linux aktif)
"""

from __future__ import annotations

import os
import threading
import time
from contextlib import asynccontextmanager

import anyio.to_thread
import cv2
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile

from skinmatch_ml.ocr.engine import MODEL_NAMES, create_ocr, extract_lines

MAX_UPLOAD_BYTES = 10 * 1024 * 1024
TIER = os.environ.get("OCR_TIER", "small")


def _mkldnn_flag() -> bool | None:
    raw = os.environ.get("ENABLE_MKLDNN")
    if raw is None or raw.strip() == "":
        return None
    return raw.strip().lower() not in ("0", "false", "no", "off")


_state: dict = {
    "ocr": None,
    "load_s": None,
    "error": None,
    "started_at": time.time(),
}
_lock = threading.Lock()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Muat model sekali saat start; kegagalan dicatat, bukan membuat crash."""
    started = time.perf_counter()
    try:
        _state["ocr"] = create_ocr(TIER, mkldnn=_mkldnn_flag())
        _state["load_s"] = round(time.perf_counter() - started, 2)
    except Exception as exc:  # noqa: BLE001
        _state["error"] = f"{type(exc).__name__}: {exc}"
    yield
    _state["ocr"] = None


app = FastAPI(title="SkinMatch OCR (smoke)", version="0.1.0", lifespan=lifespan)


@app.get("/")
def root() -> dict:
    return {"status": "awake", "service": "skinmatch-ocr", "tier": TIER}


@app.get("/health")
def health() -> dict:
    from importlib.metadata import version

    def ver(name: str) -> str:
        try:
            return version(name)
        except Exception:  # noqa: BLE001
            return "unknown"

    ready = _state["ocr"] is not None
    return {
        "status": "ok" if ready else "degraded",
        "model_ready": ready,
        "tier": TIER,
        "models": list(MODEL_NAMES.get(TIER, ())),
        "load_seconds": _state["load_s"],
        "uptime_seconds": round(time.time() - _state["started_at"], 1),
        "error": _state["error"],
        "versions": {
            "paddlepaddle": ver("paddlepaddle"),
            "paddleocr": ver("paddleocr"),
            "numpy": ver("numpy"),
        },
    }


@app.post("/v1/scan")
async def scan(file: UploadFile = File(...)) -> dict:
    if _state["ocr"] is None:
        raise HTTPException(
            status_code=503,
            detail=f"model belum siap: {_state['error'] or 'masih dimuat'}",
        )

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="file kosong")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="file melebihi 10 MB")

    image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=400, detail="gambar tidak bisa dibaca")

    # Paddle predictor tidak thread-safe: satu inferensi pada satu waktu.
    # Dijalankan di worker thread agar event loop tidak terblokir selama
    # inferensi CPU (bisa detik-an).
    def _infer(payload: np.ndarray) -> tuple[list, float]:
        with _lock:
            started = time.perf_counter()
            output = _state["ocr"].predict(payload)
            return output, round((time.perf_counter() - started) * 1000, 1)

    try:
        result, latency_ms = await anyio.to_thread.run_sync(_infer, image)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=500, detail=f"inferensi gagal: {type(exc).__name__}"
        ) from exc

    lines = extract_lines(result)
    return {
        "filename": file.filename,
        "width": int(image.shape[1]),
        "height": int(image.shape[0]),
        "latency_ms": latency_ms,
        "line_count": len(lines),
        "lines": lines,
        "raw_text": "\n".join(line["text"] for line in lines),
    }
