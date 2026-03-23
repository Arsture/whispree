"""NotMyWhisper STT Engine — Lightning-SimulWhisper HTTP server."""
import argparse
import asyncio
import base64
import struct
import sys
from contextlib import asynccontextmanager

import numpy as np
import uvicorn
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel


class TranscribeRequest(BaseModel):
    audio_base64: str
    language: str | None = None
    prompt: str | None = None


class TranscribeResponse(BaseModel):
    text: str
    segments: list[dict] = []
    language: str | None = None


class HealthResponse(BaseModel):
    status: str
    model: str | None = None
    backend: str = "coreml+mlx"


# Global engine reference
engine = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup."""
    global engine
    try:
        from src.whisper_engine import WhisperEngine
        engine = WhisperEngine()
        await engine.setup()
    except ImportError:
        print("Warning: Lightning-SimulWhisper not installed. Running in stub mode.", file=sys.stderr)
        engine = None
    yield
    if engine:
        await engine.teardown()


app = FastAPI(title="NotMyWhisper STT Engine", lifespan=lifespan)


@app.get("/health")
async def health() -> HealthResponse:
    if engine and engine.is_ready:
        return HealthResponse(status="ready", model=engine.model_name)
    return HealthResponse(status="not_ready")


@app.post("/transcribe")
async def transcribe(req: TranscribeRequest) -> TranscribeResponse:
    if not engine or not engine.is_ready:
        return TranscribeResponse(text="[Engine not ready]")

    audio = _decode_audio(req.audio_base64)
    result = await engine.transcribe(audio, language=req.language, prompt=req.prompt)
    return TranscribeResponse(
        text=result["text"],
        segments=result.get("segments", []),
        language=result.get("language"),
    )


@app.post("/transcribe/stream")
async def transcribe_stream(req: TranscribeRequest):
    if not engine or not engine.is_ready:
        return TranscribeResponse(text="[Engine not ready]")

    audio = _decode_audio(req.audio_base64)

    async def event_generator():
        async for partial in engine.transcribe_stream(audio, language=req.language, prompt=req.prompt):
            import json
            yield f"event: partial\ndata: {json.dumps(partial)}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@app.post("/shutdown")
async def shutdown():
    """Graceful shutdown."""
    asyncio.get_event_loop().call_later(0.5, sys.exit, 0)
    return {"status": "shutting_down"}


def _decode_audio(audio_base64: str) -> np.ndarray:
    """Decode base64 float32 audio buffer to numpy array."""
    raw = base64.b64decode(audio_base64)
    return np.array(struct.unpack(f"{len(raw) // 4}f", raw), dtype=np.float32)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--host", type=str, default="127.0.0.1")
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")
