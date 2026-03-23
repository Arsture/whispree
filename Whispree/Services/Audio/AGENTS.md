<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Audio

## Purpose
마이크 녹음과 오디오 분석. 네이티브 샘플레이트 캡처 → 16kHz 모노 리샘플링 + 64밴드 FFT 시각화.

## Key Files

| File | Description |
|------|-------------|
| `AudioService.swift` | `@MainActor` — AVAudioEngine 기반 녹음, 16kHz 리샘플링, vDSP FFT (80-3500Hz 음성 대역), `frequencyBands` 퍼블리시 |

## For AI Agents

### Working In This Directory
- 오디오 탭 콜백은 **오디오 스레드**에서 실행 → `Task { @MainActor in }` 디스패치 필수
- FFT는 Accelerate vDSP 사용, 64밴드, fast attack / slow decay 스무딩
- 리샘플링은 STT 모델 요구사항 (WhisperKit = 16kHz 모노)
- `currentLevel`과 `frequencyBands`는 `NeonWaveformView`에서 60fps 렌더링에 사용

<!-- MANUAL: -->
