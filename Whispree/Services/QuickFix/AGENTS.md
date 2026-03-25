<!-- Parent: ../AGENTS.md -->

# QuickFix

## Purpose
선택 텍스트 교정 + 도메인 사전 자동 등록. `Ctrl+Shift+D`로 활성화.

## Key Files

| File | Description |
|------|-------------|
| `QuickFixService.swift` | `@MainActor` — 선택 텍스트 캡처(Cmd+C 시뮬레이션), 교정 텍스트 삽입(Cmd+V 시뮬레이션), 도메인 사전 등록 |

## For AI Agents

### Working In This Directory
- **Accessibility 권한 필수** — CGEvent로 Cmd+C/V 시뮬레이션
- 클립보드 원본 내용을 저장/복원하는 패턴 사용 (캡처 전 백업 → 캡처 → 복원)
- 두 가지 모드: 단어 추가 (STT+LLM 사전) / 매핑 추가 (LLM 교정 매핑)
- "Quick Fix" 이름의 `DomainWordSet`에 자동 저장 — `ensureQuickFixSet()`으로 없으면 생성
- UI는 `Views/QuickFix/QuickFixPanelView.swift`에 있음
- `AppDelegate.handleQuickFix()`가 진입점 — frontmost app 캡처 → 텍스트 캡처 → 패널 표시
