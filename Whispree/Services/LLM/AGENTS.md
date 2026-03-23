<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# LLM

## Purpose
LLM 기반 텍스트 교정. 프로토콜 추상화로 None/Local(Qwen3)/OpenAI(GPT) 간 런타임 전환.

## Key Files

| File | Description |
|------|-------------|
| `LLMProvider.swift` | `@MainActor protocol LLMProvider` — `correct(text:systemPrompt:glossary:)` |
| `LLMService.swift` | 교정 오케스트레이션 + **word-edit-distance 안전장치** (Levenshtein, threshold 0.5) — LLM 환각 방지 |
| `CorrectionPrompts.swift` | 한국어 few-shot 교정 프롬프트. `codeSwitchPrompt` (한영 코드스위칭), `promptEngineeringPrompt` (STT 교정 + 구조화) |
| `LocalLLMProvider.swift` | Qwen3-4B via mlx-swift-lm, 5초 타임아웃 |
| `NoneProvider.swift` | 패스스루 (교정 없음) |
| `OpenAIProvider.swift` | ChatGPT Responses API + SSE 스트리밍, `CodexAuthService` 토큰 재사용 |

## For AI Agents

### Working In This Directory
- `LLMProvider`는 `@MainActor` — STTProvider와 다름 (LLM은 가벼운 API 호출 + AppState 접근 필요)
- `LLMService`의 word-edit-distance가 0.5를 초과하면 교정 결과를 버리고 원본 반환 → 환각 방지 핵심 로직
- `CorrectionPrompts`는 **한국어** few-shot 예시 포함 — 프롬프트 수정 시 한국어/영어 코드스위칭 케이스 테스트
- `OpenAIProvider`는 SSE 스트리밍 파싱 → `OpenAIModels.swift`의 응답 모델 참조

### Testing
- `WhispreeTests/Services/LLMServiceTests.swift`

<!-- MANUAL: -->
