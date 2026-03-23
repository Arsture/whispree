"""Lightning Whisper MLX engine — 10x faster Whisper on Apple Silicon."""
import asyncio
import tempfile
import wave
import struct
from pathlib import Path

import numpy as np


class WhisperEngine:
    """Wraps lightning-whisper-mlx for use as a local HTTP service."""

    def __init__(self, model: str = "large-v3", batch_size: int = 12, quant: str | None = None):
        self.model_name = model
        self.batch_size = batch_size
        self.quant = quant
        self.is_ready = False
        self._whisper = None

    async def setup(self):
        """Initialize the Lightning Whisper MLX pipeline."""
        from lightning_whisper_mlx import LightningWhisperMLX
        self._whisper = LightningWhisperMLX(
            model=self.model_name,
            batch_size=self.batch_size,
            quant=self.quant,
        )
        self.is_ready = True

    async def teardown(self):
        """Clean up resources."""
        self._whisper = None
        self.is_ready = False

    async def transcribe(self, audio: np.ndarray, language: str | None = None,
                         prompt: str | None = None) -> dict:
        """Transcribe audio buffer (16kHz float32).

        lightning-whisper-mlx takes a file path, so we write a temp WAV file.
        """
        if not self.is_ready or self._whisper is None:
            return {"text": "", "segments": [], "language": None}

        # Write audio buffer to temp WAV file (16kHz, mono, float32→int16)
        tmp_path = await self._write_temp_wav(audio)

        try:
            # Run transcription in thread pool (blocking call)
            result = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: self._whisper.transcribe(audio_path=str(tmp_path), language=language),
            )

            text = result.get("text", "") if isinstance(result, dict) else str(result)
            segments = result.get("segments", []) if isinstance(result, dict) else []

            return {
                "text": text.strip(),
                "segments": segments,
                "language": language,
            }
        finally:
            # Clean up temp file
            try:
                tmp_path.unlink()
            except OSError:
                pass

    async def transcribe_stream(self, audio: np.ndarray, language: str | None = None,
                                prompt: str | None = None):
        """Stream transcription results (single-shot for now)."""
        result = await self.transcribe(audio, language=language, prompt=prompt)
        yield {"text": result["text"], "is_final": True}

    @staticmethod
    async def _write_temp_wav(audio: np.ndarray) -> Path:
        """Write float32 audio buffer to a temporary 16kHz mono WAV file."""
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp_path = Path(tmp.name)
        tmp.close()

        # Convert float32 [-1, 1] to int16
        audio_int16 = np.clip(audio * 32767, -32768, 32767).astype(np.int16)

        def _write():
            with wave.open(str(tmp_path), "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)  # 16-bit
                wf.setframerate(16000)
                wf.writeframes(audio_int16.tobytes())

        await asyncio.get_event_loop().run_in_executor(None, _write)
        return tmp_path
