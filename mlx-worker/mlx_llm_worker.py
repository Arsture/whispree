"""MLX LLM/VLM worker — stdin/stdout JSON protocol.

Whispree의 LocalText/LocalVision 교정을 Python MLX 패키지로 우회하는 워커.
mlx-swift-lm에 아직 포팅되지 않은 아키텍처(Gemma4 MoE, DiffusionGemma 등)를
지원하기 위함.
"""

import base64
import json
import os
import sys
import tempfile
from pathlib import Path


_model = None
_processor = None
_config = None
_model_id = None
_backend = None


def _respond(data: dict):
    """Write JSON response to stdout as a single line."""
    print(json.dumps(data, ensure_ascii=False), flush=True)


def _error(msg: str):
    _respond({"ok": False, "error": msg})


def handle_load(model_id: str, capability: str):
    """Load an MLX text or vision model."""
    global _model, _processor, _config, _model_id, _backend
    try:
        if capability == "vision":
            from mlx_vlm import load
            from mlx_vlm.utils import load_config

            _model, _processor = load(model_id)
            _config = load_config(model_id)
            _backend = "mlx-vlm"
        else:
            from mlx_lm import load

            _model, _processor = load(model_id)
            _config = None
            _backend = "mlx-lm"
        _model_id = model_id
        _respond({"ok": True, "model": model_id, "backend": _backend})
    except Exception as e:
        _error(f"Failed to load model: {e}")


def handle_warmup():
    """Generate 1 token to trigger JIT compilation."""
    if _model is None or _processor is None:
        _error("No model loaded")
        return
    try:
        if _backend == "mlx-vlm":
            from mlx_vlm import generate
            from mlx_vlm.prompt_utils import apply_chat_template

            prompt = apply_chat_template(_processor, _config, "hi", num_images=0)
            generate(_model, _processor, prompt, image=None, max_tokens=1, verbose=False)
        else:
            from mlx_lm import generate

            generate(_model, _processor, "hi", max_tokens=1, verbose=False)
        _respond({"ok": True})
    except Exception as e:
        _error(f"Warmup failed: {e}")


def _strip_think(text: str) -> str:
    """Qwen3 스타일 <think>...</think> 블록 제거."""
    if "</think>" in text:
        text = text.split("</think>", 1)[1]
    elif text.lstrip().startswith("<think>"):
        return ""
    return text.strip()


def _write_temp_images(screenshots: list[str]) -> list[str]:
    """Write base64 JPEG payloads to temporary files for mlx-vlm."""
    paths = []
    for index, encoded in enumerate(screenshots[:3]):
        if not encoded:
            continue
        raw = base64.b64decode(encoded)
        path = Path(tempfile.gettempdir()) / f"whispree-vlm-{os.getpid()}-{index}.jpg"
        path.write_bytes(raw)
        paths.append(str(path))
    return paths


def _cleanup_temp_images(paths: list[str]):
    for path in paths:
        try:
            Path(path).unlink(missing_ok=True)
        except Exception:
            pass


def _generation_text(output) -> str:
    """Handle mlx-lm string output and mlx-vlm GenerationResult output."""
    if hasattr(output, "text"):
        return output.text
    return str(output)


def handle_correct(
    system_prompt: str,
    user_text: str,
    screenshots: list[str],
    max_tokens: int,
    temperature: float,
):
    """Run correction. Returns generated text."""
    if _model is None or _processor is None:
        _error("No model loaded")
        return
    try:
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ]

        if _backend == "mlx-vlm":
            from mlx_vlm import generate
            from mlx_vlm.prompt_utils import apply_chat_template

            image_paths = _write_temp_images(screenshots)
            try:
                prompt = apply_chat_template(
                    _processor,
                    _config,
                    messages,
                    num_images=len(image_paths),
                )
                output = generate(
                    _model,
                    _processor,
                    prompt=prompt,
                    image=image_paths or None,
                    max_tokens=max_tokens,
                    temperature=temperature,
                    verbose=False,
                )
            finally:
                _cleanup_temp_images(image_paths)
        else:
            from mlx_lm import generate
            from mlx_lm.sample_utils import make_sampler

            # chat template 적용
            if hasattr(_processor, "apply_chat_template"):
                prompt = _processor.apply_chat_template(
                    messages, add_generation_prompt=True, tokenize=False
                )
            else:
                prompt = system_prompt + "\n" + user_text

            sampler = make_sampler(temp=temperature, top_p=1.0)
            output = generate(
                _model,
                _processor,
                prompt=prompt,
                max_tokens=max_tokens,
                sampler=sampler,
                verbose=False,
            )

        _respond({"ok": True, "text": _strip_think(_generation_text(output))})
    except Exception as e:
        _error(f"Correction failed: {e}")


def main():
    """Main loop: read JSON commands from stdin, write responses to stdout."""
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
            handle_load(cmd.get("model", ""), cmd.get("capability", "text"))
        elif action == "warmup":
            handle_warmup()
        elif action == "correct":
            handle_correct(
                cmd.get("system_prompt", ""),
                cmd.get("user_text", ""),
                cmd.get("screenshots", []),
                int(cmd.get("max_tokens", 2000)),
                float(cmd.get("temperature", 0.0)),
            )
        elif action == "status":
            _respond({
                "ok": True,
                "model": _model_id,
                "loaded": _model is not None,
                "backend": _backend,
            })
        elif action == "quit":
            _respond({"ok": True, "status": "bye"})
            break
        else:
            _error(f"Unknown command: {action}")


if __name__ == "__main__":
    main()
