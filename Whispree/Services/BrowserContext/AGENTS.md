# BrowserContext

## Purpose
Chrome 전용 탭 + input element 컨텍스트 캡처/복원. 녹음 시작 시점의 Chrome 탭과 포커스된 HTML element를 기억해서 붙여넣기 단계에서 같은 위치로 복원.

## Key Files

| File | Description |
|------|-------------|
| `BrowserContextService.swift` | `@MainActor` — `captureChrome(app:)` / `restoreChrome(_:)`. NSAppleScript는 MainActor에서 직접 실행 (TCC 프롬프트 조건) |
| `ChromeAppleScripts.swift` | AppleScript 템플릿 모음 — `captureActiveTab`, `captureActiveElement`, `restoreTab(tabID:fallbackURL:)`, `focusElement(selector:type:start:end:)`. selector + 커서 위치(selectionStart/End · contenteditable 문자 offset)를 함께 캡처/복원하는 JS minified 형태로 embed |

## For AI Agents

### Working In This Directory

- **Automation 권한 필수** — 첫 호출 시 macOS가 자동 프롬프트 (System Settings → Privacy & Security → Automation → Whispree → Google Chrome)
- **"Apple Events로부터 JavaScript 허용"** (Chrome 메뉴바 → 보기 → 개발자) — element-level 복원에만 필요. 꺼져있어도 탭 복원은 동작 (`ElementInfo = nil` fallback)
- **`com.apple.security.automation.apple-events` entitlement 필수** — Hardened Runtime에서 이게 없으면 TCC 프롬프트가 뜨기 전에 entitlement gate에서 -1743으로 조용히 차단됨. `project.yml`의 `entitlements.properties`에 등록
- `NSAppleScript`는 **반드시 MainActor에서 직접 실행** — `Task.detached`로 호출하면 macOS가 Automation 프롬프트를 띄우지 않고 -1743 반환
- 에러 코드: `-1743` (Automation 권한 거부 또는 entitlement 누락), `-1728`/`-1708` (JS 미허용 또는 실행 실패). OSLog `BrowserContext` 카테고리로 기록 (Console.app에서 확인)
- `captureChrome`은 실패 시 `.app(app)` fallback 반환 — 호출자는 추가 분기 없음
- `restoreChrome`: tabID 우선 검색 → URL 매칭 fallback. 성공 시 탭 활성화 + 윈도우 최전면
- element 복원은 best-effort — 실패해도 탭 복원 상태는 유지

### 커서 위치 복원 전략
- **input/textarea**: `selectionStart`/`selectionEnd`를 숫자 그대로 캡처 → 복원 시 `setSelectionRange(start, end)` (value 길이 초과 시 clamp)
- **contenteditable**: `Selection.getRangeAt(0)` 기준 Range를 만들고, `selectNodeContents(root)` 후 `setEnd(range.startContainer, range.startOffset)` → `toString().length`로 root 기준 **문자 offset**을 계산. 복원 시 TreeWalker로 text node를 순회하면서 누적 길이로 해당 offset의 (node, offset) 쌍을 찾아 `Range.setStart/setEnd` → `Selection.addRange`
- DOM이 캡처 시점과 달라져 offset이 유효하지 않으면 마지막 text node 끝으로 fallback (기존 `collapse(false)` 동작과 동일)

### AppleScript 문자열 escape 규칙
- `escapeForAppleScript`: `\` → `\\`, `"` → `\"` (백슬래시 먼저)
- `escapeForJSSingleQuotedString`: `\` → `\\`, `'` → `\'`
- JS는 반드시 **한 줄**로 minify — AppleScript 문자열 리터럴 제약

### Dependencies
- `ExternalContext` (Models/) — `.chromeTab(...)` case 반환
- `AppSettings.restoreBrowserTab` — 기능 on/off 토글

### RecordingCoordinator 연동
- `startRecording()`: 타겟 앱이 Chrome이고 `restoreBrowserTab` 활성 시 `captureChrome`을 **동기 호출** (MainActor에서 TCC 프롬프트 표시를 위해). 결과는 `capturedContext: ExternalContext?`에 저장
- `processPipeline()` Step 4: `capturedContext`가 `.chromeTab`이면 `restoreChrome` 호출 후 `insertText`
- `cancel()`: `capturedContext = nil` 리셋

## Info.plist
- `NSAppleEventsUsageDescription` — AppleEvents 사용 사유 명시 (macOS 권한 프롬프트에 표시)
