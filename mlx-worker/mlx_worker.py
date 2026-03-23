"""mlx-audio STT worker — stdin/stdout JSON protocol."""

import json
import os
import sys
import tempfile

import numpy as np
import soundfile as sf


_model = None
_model_id = None


def _respond(data: dict):
    """Write JSON response to stdout."""
    print(json.dumps(data, ensure_ascii=False), flush=True)


def _error(msg: str):
    _respond({"ok": False, "error": msg})


def handle_load(model_id: str):
    """Load an mlx-audio STT model."""
    global _model, _model_id
    try:
        from mlx_audio.stt.utils import load

        _model = load(model_id)
        _model_id = model_id
        _respond({"ok": True, "model": model_id})
    except Exception as e:
        _error(f"Failed to load model: {e}")


def handle_warmup():
    """Run silent audio through model to trigger JIT compilation."""
    if _model is None:
        _error("No model loaded")
        return
    try:
        fd, path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        sf.write(path, np.zeros(8000, dtype=np.float32), 16000)
        _model.generate(path, max_tokens=1)
        os.unlink(path)
        _respond({"ok": True})
    except Exception as e:
        _error(f"Warmup failed: {e}")


def handle_transcribe(audio_path: str, language: str | None = None):
    """Transcribe audio file."""
    if _model is None:
        _error("No model loaded")
        return
    try:
        kwargs = {}
        if language:
            kwargs["language"] = language
        result = _model.generate(audio_path, **kwargs)
        text = result.text.strip() if hasattr(result, "text") else str(result).strip()
        _respond({"ok": True, "text": text})
    except Exception as e:
        _error(f"Transcription failed: {e}")
    finally:
        try:
            os.unlink(audio_path)
        except OSError:
            pass


def main():
    """Main loop: read JSON commands from stdin, write responses to stdout."""
    # Signal ready
    _respond({"ok": True, "status": "ready"})

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            cmd = json.loads(line)
        except json.JSONDecodeError:
            _error("Invalid JSON")
            continue

        action = cmd.get("cmd")

        if action == "load":
            handle_load(cmd.get("model", ""))
        elif action == "warmup":
            handle_warmup()
        elif action == "transcribe":
            handle_transcribe(
                cmd.get("path", ""),
                cmd.get("language"),
            )
        elif action == "status":
            _respond({
                "ok": True,
                "model": _model_id,
                "loaded": _model is not None,
            })
        elif action == "quit":
            _respond({"ok": True, "status": "bye"})
            break
        else:
            _error(f"Unknown command: {action}")


if __name__ == "__main__":
    main()
