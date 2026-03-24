# Whispree

STT와 LLM 프로바이더를 자유롭게 선택할 수 있는 macOS 메뉴바 음성인식 앱. 빠른 응답속도, 높은 정확도, OpenAI 계정만 있으면 거의 무료.

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

### 프로바이더 선택

[OpenCode](https://github.com/nicepkg/opencode)처럼, STT와 LLM 프로바이더를 직접 골라 쓸 수 있습니다.

| 프로바이더 | STT 옵션 | LLM 옵션 |
|----------|-------------|-------------|
| 클라우드 (권장) | [Groq API](https://groq.com/) — 무료, 빠름, 정확함 | [OpenAI via Codex CLI](https://github.com/openai/codex) — 기존 계정 그대로 사용 |
| 로컬 | [WhisperKit](https://github.com/argmaxinc/WhisperKit) — 온디바이스, CoreML + ANE | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — Qwen3-4B, Apple Silicon |
| 로컬 | [MLX Audio](https://github.com/ml-explore/mlx-audio) — Qwen3-ASR, Python worker | — |

### 영어 섞어 쓰는 한국인 개발자를 위해

Whispree는 **코드스위칭**에 최적화되어 있습니다 — 한국어에 영어 기술 용어를 섞어 쓸 때:

- "밸리데이션" → "validation"
- "리액트 컴포넌트" → "React 컴포넌트"
- 말로 한 프롬프트를 깔끔한 문장으로 재구성

### 스마트 받아쓰기

- **녹음 & 전사** — `Ctrl+Shift+R`로 녹음 시작, 다시 누르면 전사
- **Quick Fix** — 잘못 인식된 단어? `Ctrl+Shift+D`로 교정 사전에 저장
- **다양한 교정 모드** — STT 교정, 코드스위칭 교정, 프롬프트 엔지니어링 모드

## 이름의 유래

> 처음엔 **FreeWhisper**였다. 나만 쓸 도구를 Swift로 대충 만든 거라 이름 따위 신경 쓸 이유가 없었다.
>
> 오픈소스로 공개하려다 보니 이름이 필요했다. "Oh My ..." 시리즈는 좀 유행 지난 느낌이었고, **OpenWhisper**는 이미 있는 이름이었다.
>
> API 키를 빌려다 쓰는 게 마치 남의 양지바른 자리에 슬쩍 눌러앉는 고양이 같아서, **Not My Whisper**라는 이름도 괜찮겠다 싶었다. 근데 매일 쓰다 보니 애착이 생겨버렸다. *"잠깐, 이거 내 위스퍼 아닌가?"*
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

1. **첫 실행** — 마이크 및 접근성 권한을 허용하세요.
2. **모델 다운로드** — 설정 > 모델에서 사용할 STT/LLM 모델을 다운로드하세요.
3. **녹음** — `Ctrl+Shift+R`을 눌러 녹음을 시작합니다. 다시 누르면 전사됩니다.
4. **삽입** — 교정된 텍스트가 커서 위치에 자동 삽입됩니다.
5. **Quick Fix** — 잘못 인식된 단어를 선택하고 `Ctrl+Shift+D`를 눌러 교정 사전에 저장하세요.

### 설정

메뉴바 아이콘에서 설정에 접근할 수 있습니다:

- **일반** — 단축키, 녹음 모드, 로그인 시 시작
- **STT** — STT 프로바이더 선택 (WhisperKit, Groq, MLX Audio)
- **LLM** — LLM 프로바이더 선택 (없음, 로컬, OpenAI via Codex), 교정 모드
- **모델** — 모델 다운로드 및 관리

## 요구 사항

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- 마이크 권한
- 접근성 권한 (텍스트 삽입용)

## 기여하기

[CONTRIBUTING.md](CONTRIBUTING.md)를 참고해주세요.

## 라이선스

[MIT](LICENSE)
