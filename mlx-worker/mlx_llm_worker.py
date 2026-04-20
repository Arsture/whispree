"""mlx-lm LLM worker — stdin/stdout JSON protocol.

Whispree의 LocalText 교정을 Python mlx-lm으로 우회하는 워커.
mlx-swift-lm에 아직 포팅되지 않은 아키텍처(Gemma4 MoE 등)를 지원하기 위함.
"""

import json
import sys


_model = None
_tokenizer = None
_model_id = None


def _respond(data: dict):
    """Write JSON response to stdout as a single line."""
    print(json.dumps(data, ensure_ascii=False), flush=True)


def _error(msg: str):
    _respond({"ok": False, "error": msg})


def handle_load(model_id: str):
    """Load an mlx-lm model."""
    global _model, _tokenizer, _model_id
    try:
        from mlx_lm import load

        _model, _tokenizer = load(model_id)
        _model_id = model_id
        _respond({"ok": True, "model": model_id})
    except Exception as e:
        _error(f"Failed to load model: {e}")


def handle_warmup():
    """Generate 1 token to trigger JIT compilation."""
    if _model is None or _tokenizer is None:
        _error("No model loaded")
        return
    try:
        from mlx_lm import generate

        generate(_model, _tokenizer, "hi", max_tokens=1, verbose=False)
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


def handle_correct(system_prompt: str, user_text: str, max_tokens: int, temperature: float):
    """Run correction. Returns generated text."""
    if _model is None or _tokenizer is None:
        _error("No model loaded")
        return
    try:
        from mlx_lm import generate
        from mlx_lm.sample_utils import make_sampler

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ]

        # chat template 적용
        if hasattr(_tokenizer, "apply_chat_template"):
            prompt = _tokenizer.apply_chat_template(
                messages, add_generation_prompt=True, tokenize=False
            )
        else:
            prompt = system_prompt + "\n" + user_text

        sampler = make_sampler(temp=temperature, top_p=1.0)
        output = generate(
            _model,
            _tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
            sampler=sampler,
            verbose=False,
        )

        _respond({"ok": True, "text": _strip_think(output)})
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
            handle_load(cmd.get("model", ""))
        elif action == "warmup":
            handle_warmup()
        elif action == "correct":
            handle_correct(
                cmd.get("system_prompt", ""),
                cmd.get("user_text", ""),
                int(cmd.get("max_tokens", 2000)),
                float(cmd.get("temperature", 0.0)),
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
