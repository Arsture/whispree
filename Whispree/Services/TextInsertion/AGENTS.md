<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# TextInsertion

## Purpose
전사 결과를 이전 앱에 붙여넣기. 클립보드 + CGEvent Cmd+V 시뮬레이션.

## Key Files

| File | Description |
|------|-------------|
| `TextInsertionService.swift` | 비동기 텍스트 삽입 — 이전 앱 활성화 → 클립보드 복사 → CGEvent Cmd+V. 유효한 대상 앱 없으면 클립보드 전용 폴백 |

## For AI Agents

### Working In This Directory
- **Accessibility 권한 필수** (`AXIsProcessTrusted`) — 없으면 CGEvent 전송 실패
- `Task.sleep` 사용 (Thread.sleep 아님) — MainActor yield
- `lastExternalApp`이 nil이면 (예: Settings 창에서 녹음 시) 클립보드 전용 폴백
- CGEvent 시뮬레이션은 일부 앱에서 동작하지 않을 수 있음 (보안 설정)

<!-- MANUAL: -->
