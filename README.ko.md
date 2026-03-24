# Whispree

LLM 후처리가 포함된 완전 로컬 macOS 메뉴바 음성인식 앱. SuperWhisper의 무료 오픈소스 대안으로, Apple Silicon에서 클라우드 없이 모든 처리가 온디바이스로 이루어집니다.

[English](README.md) | 한국어

![License](https://img.shields.io/github/license/Arsture/whispree)
![Version](https://img.shields.io/github/v/release/Arsture/whispree)
![Build](https://img.shields.io/github/actions/workflow/status/Arsture/whispree/release.yml)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)

<!-- 데모 영상 -->
<p align="center">
  <em>데모 영상 준비 중</em>
</p>

## 주요 기능

- **로컬 STT** — WhisperKit (large-v3-turbo)으로 99개 이상 언어의 고정밀 음성인식
- **LLM 교정** — mlx-swift-lm (Qwen3-4B)으로 띄어쓰기, 맞춤법, 동음이의어 자동 교정
- **글로벌 단축키** — Push-to-talk, 토글 모드 지원. 단축키 커스터마이즈 가능
- **텍스트 삽입** — 전사 결과를 커서 위치에 자동 삽입 (Accessibility API + 클립보드 폴백)
- **실시간 스트리밍** — 플로팅 오버레이에서 실시간 부분 전사 결과 표시
- **프라이버시** — 모든 처리가 온디바이스. 모델 다운로드 이후 네트워크 호출 제로.
- **자동 업데이트** — Sparkle을 통한 백그라운드 업데이트 체크. 새 버전이 준비되면 알림.

## 이름의 유래

> 처음엔 **FreeWhisper**였다. 그냥 나만 쓸 도구였으니까.
>
> 오픈소스로 풀려고 하니 **OpenWhisper**가 맞을 것 같았다.
> 근데 이름이 이미 있더라.
>
> 한동안 **not-my-whisper**로 정착했다.
> 근데 너무 길고, 솔직히 — 내 위스퍼에 너무 애착이 가서
> "내 거 아님"이라고 부르기가 좀 그랬다.
>
> 그래서 지금의 **Whispree**. 자유로운 위스퍼. 내 위스퍼. 당신의 위스퍼.

## 꿀팁

> **직장인 팁**: 에어팟 끼고 통화하는 척하면 됩니다. 아무도 당신이 장보기 목록을 받아쓰고 있다는 걸 모릅니다.

> **회의 꿀팁**: Zoom 음소거 걸고, Whispree에 속삭이고, 아무도 눈치 못 채게 완벽한 회의록을 붙여넣으세요.

> **대중교통**: "아주 중요한 전화를 받고 있는" 표정이 핵심입니다. 살짝 귀찮은 표정으로 말하면 완벽.

## 설치

### Homebrew Cask (권장)

```bash
brew install --cask whispree
```

### GitHub Releases

[GitHub Releases](https://github.com/Arsture/whispree/releases)에서 최신 `.dmg` 또는 `.zip`을 다운로드하세요.

### 소스에서 빌드

```bash
git clone https://github.com/Arsture/whispree.git
cd whispree
brew install xcodegen
xcodegen generate
open Whispree.xcodeproj
# 빌드 및 실행 (Cmd+R)
```

SPM 의존성은 첫 빌드 시 자동으로 해결됩니다.

## 사용법

1. **첫 실행** — 마이크 및 접근성 권한을 허용하세요. 모델이 자동 다운로드됩니다 (~3.5GB).
2. **녹음** — 글로벌 단축키 (기본: `Option+Space`)를 눌러 녹음을 시작합니다.
3. **전사** — 키를 떼면 (push-to-talk) 또는 다시 누르면 (토글 모드) 전사가 시작됩니다.
4. **삽입** — 교정된 텍스트가 커서 위치에 자동 삽입됩니다.

### 설정

메뉴바 아이콘에서 설정에 접근할 수 있습니다:

- **일반** — 단축키, 녹음 모드, 로그인 시 시작
- **모델** — 모델 선택, 다운로드 관리, 디스크 사용량
- **LLM** — LLM 교정 활성화/비활성화, 커스텀 프롬프트

## 요구 사항

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- ~4GB 디스크 공간 (WhisperKit ~1.5GB + LLM ~2GB)
- 마이크 권한
- 접근성 권한 (텍스트 삽입용)

## 기여하기

[CONTRIBUTING.md](CONTRIBUTING.md)를 참고해주세요.

## 라이선스

[MIT](LICENSE)
