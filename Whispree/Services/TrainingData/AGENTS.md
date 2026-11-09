<!-- Parent: ../AGENTS.md -->

# TrainingData

## Purpose
STT/LLM 파인튜닝용 원시 데이터를 **소유자 Mac에만** 수집. 수집 시점에 정답(GT) 판정은 하지 않는다 — raw로 모으고 나중에 판단. 네트워크/서버 없음.

## Key Files

| File | Description |
|------|-------------|
| `TrainingDataRecorder.swift` | `@MainActor` facade (`TrainingDataRecorder.shared`). `AppSettings.collectTrainingData` OFF면 전부 no-op. `TrainingDataIO`가 전용 serial queue에서 모든 디스크/SQLite I/O 수행 |
| `TrainingDataStore.swift` | system SQLite3 C API 래퍼 (`dataset.sqlite`, WAL) + 오디오(FLAC, 실패 시 16-bit WAV)/스크린샷 파일 쓰기. **I/O queue 전용, thread-safe 아님** |
| `EditObservation.swift` | 붙여넣기 직전/직후 AX 포커스 요소 값 읽기 + 최대 60s 1초 폴링 관찰 (value 변화 기록. 다른 앱/필드로 가면 종료하지 않고 `app_switch`/`focus_change` 이벤트 후 일시정지, 돌아오면 `focus_back` 후 재개. 일시정지 중 제어키 marker 무시. 종료는 60s timeout·필드 비움·다음 delivery) |
| `TrainingDataExporter.swift` | 설정 화면 "데이터 내보내기" — `VACUUM INTO` 임시 복사본 + audio + manifest.json → `ditto` zip. 기본은 스크린샷/입력창 원문 제외(복사본에서만 삭제·NULL) |

## Storage
- 기본 루트 `~/.whispree/dataset/` (`whispree.trainingDataPath`로 변경, 빈 문자열 = 기본). 앱 번들 밖이라 Sparkle 업데이트/재설치에도 유지.
- `dataset.sqlite` + `audio/<sessionID>.flac|wav` + `screenshots/<sessionID>_<n>.jpg`. session id = `DictationJobID`.
- 스키마는 **append-only**: `TrainingDataStore.migrations`에 새 항목만 추가. 기존 항목 수정/테이블 drop 금지.

## For AI Agents
- 실패는 `Logger(subsystem: "com.whispree.app", category: "Dataset")`로 로그 후 삼킨다. 녹음/FIFO delivery를 절대 막지 말 것.
- 큐 retention을 늘리지 말 것 — 오디오는 `stopRecording()` 시점에 `[Float]`를 recorder로 넘겨 바로 파일로 쓴다.
- `settingsSnapshot`에 API key/토큰을 넣지 말 것 (테스트가 검증).
- 편집 마커는 `EventTapHotkeyService.isEditObservationActive`일 때만 Return/Cmd+Return/Esc/Cmd+Z 발생 사실만 보고. 이벤트를 소비/변경하지 않으며 다른 키 입력은 기록 금지.
- AX 한계: Electron/일부 웹뷰는 `AXValue`를 안 주거나 지연 → `unsupported`. 터미널(iTerm2)은 AXValue가 스크롤백 전체라 4000자 창으로 잘라 저장(`value_offset`).
- 보안 입력란(`AXSecureTextField`)은 값 읽지 않고 `secure_field_skipped`.

### RecordingCoordinator 훅
`stopRecording()` enqueue 직후 `beginSession` / `processSTT` 성공·실패 `recordSTT` / `processLLM` 각 fallback·성공 `recordLLM` / `deliver()` paste 전후 `prepareEditObservation`·`pasteDidHappen`·`recordDelivery` / `refreshProjectedState()`에서 `syncTerminalStatuses`. Quick Fix는 `AppDelegate.showQuickFixPanel` 확인 콜백에서 `recordQuickFix`.

### Testing
- `WhispreeTests/Services/TrainingDataTests.swift` — 임시 디렉토리 + 고유 UserDefaults suite.
