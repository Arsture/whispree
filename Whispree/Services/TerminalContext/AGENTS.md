# TerminalContext

## Purpose
iTerm2 session(pane) + (선택적) tmux window/pane 컨텍스트 캡처/복원. 녹음 시작 시점의 iTerm2 pane UUID와 그 안에서 attached 상태인 tmux의 `session:window.pane`을 기억해서 붙여넣기 단계에서 동일 위치로 복원.

## Key Files

| File | Description |
|------|-------------|
| `TerminalContextService.swift` | `@MainActor` — `captureITerm2(app:)` / `restoreITerm2(_:)`. AppleScript로 iTerm2 session UUID/tty 캡처 → `Process`로 `tmux list-clients`/`display-message` 실행해서 tmux attached 상태 감지 |
| `ITerm2AppleScripts.swift` | AppleScript 템플릿 — `captureActiveSession`, `restoreSession(sessionID:)`. iTerm2는 각 pane(split)이 `session` 단위로 모델링되며 `unique id`(UUID)로 식별 |

## For AI Agents

### Working In This Directory

- **Automation 권한 필수** — 첫 호출 시 macOS가 "Whispree가 iTerm을 제어" 프롬프트. `com.apple.security.automation.apple-events` entitlement 필수 (Hardened Runtime 에서 이게 없으면 -1743으로 조용히 차단)
- **`NSAppleScript`는 MainActor에서 직접 실행** — background thread에서 호출하면 TCC 프롬프트 안 뜨고 silent fail
- `captureITerm2`는 실패 시 `.app(app)` fallback — 호출자는 추가 분기 없음
- iTerm2의 pane = AppleScript의 `session`. `unique id`는 프로세스 생존 동안 안정 (재시작하면 갱신)
- `restoreSession` AppleScript는 전체 windows × tabs × sessions 순회하며 UUID 매칭 → 찾으면 각 계층에서 `select` 호출

### tmux 감지 전략

1. iTerm2 session의 tty (`/dev/ttys001`) AppleScript로 획득
2. `tmux list-clients -F '#{client_tty} #{session_name}'` 실행 (기본 소켓만 지원)
3. tty 매칭 (완전 일치 / hasSuffix 양방향 — tmux/iTerm이 full path vs short name 내보내는 변종 대비)
4. 매칭 성공 → `tmux display-message -p -F '#I #P' -t <session>` 로 active window/pane 획득
5. 복원 시 `tmux select-window -t <sess>:<win>` + `select-pane -t <sess>:<win>.<pane>`

**한계**:
- 커스텀 `-L` / `-S` 소켓은 미지원. `tmux -L name list-clients`까지 probing하면 비용만 크고 가치 낮음
- tmux 바이너리 탐색은 `/opt/homebrew/bin/tmux` → `/usr/local/bin/tmux` → `/usr/bin/tmux` 순. 여기 없으면 tmux 기능만 skip (탭/pane UUID 복원은 동작)

### Dependencies

- `ExternalContext` (Models/) — `.iTerm2Session(app:, sessionID:, tty:, tmux: TmuxSnapshot?)` case 반환
- `AppSettings.restoreTerminalContext` — 기능 on/off 토글
- `Process` (Foundation) — tmux CLI shell-out

### RecordingCoordinator 연동

- `startRecording()`: 타겟이 iTerm2 + `restoreTerminalContext` 활성 시 `captureITerm2` **동기 호출** (MainActor TCC 프롬프트 조건)
- `processPipeline()` Step 4: `capturedContext`가 `.iTerm2Session`이면 `restoreITerm2` 호출 후 `insertText`
- `cancel()`: `capturedContext = nil` 리셋

### 미지원 / 향후 확장 후보

- **Terminal.app**: AppleScript 가능하나 split 개념 없음. 탭 단위 복원만 가능 — 가치 낮음
- **Alacritty / Kitty / Ghostty / Warp**: AppleScript 지원 안 함 → Accessibility API 기반 추론 필요 (신뢰도 낮아 제외)
- **커스텀 tmux 소켓**: 필요하면 `tmux -L <name>` 여러 번 probe (성능 trade-off)
