# Whispree

> OpenAI 계정 하나로 쓰는 거의 무료 macOS 음성인식. 빠르고, 정확하고, 메뉴바에서 바로.

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

### 거의 무료

Groq STT는 무료이고, OpenAI LLM 교정은 [Codex CLI](https://github.com/openai/codex) 인증 토큰을 그대로 가져다 씁니다. OpenAI 계정만 있으면 사실상 추가 비용 없이 고품질 STT + LLM 교정을 쓸 수 있습니다.

### 프로바이더 선택

[OpenCode](https://github.com/nicepkg/opencode)처럼 STT와 LLM 프로바이더를 직접 골라 쓸 수 있습니다.

| | STT | LLM |
|---|---|---|
| **클라우드 (권장)** | [Groq](https://groq.com/) — 무료, 빠름 | [OpenAI via Codex CLI](https://github.com/openai/codex) — 기존 계정 그대로 |
| **로컬** | [WhisperKit](https://github.com/argmaxinc/WhisperKit) — CoreML + ANE | [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — Qwen3-4B |
| **로컬** | [MLX Audio](https://github.com/ml-explore/mlx-audio) — Qwen3-ASR, Python worker | — |

### 코드스위칭 최적화

영어 섞어서 말하는 한국인 개발자를 위해 만들었습니다. LLM 교정이 한국어 속 영어 기술 용어를 잡아줍니다.

```
"밸리데이션 해야 되거든"  →  "validation 해야 되거든"
"리엑트 컴포넌트"        →  "React 컴포넌트"
"깃허브에 PR 올려놨어"   →  "GitHub에 PR 올려놨어"
```

### 스마트 받아쓰기

- **녹음** — `Ctrl+Shift+R`. Push to Talk(누르고 있으면 녹음) 또는 Toggle(한 번 누르면 시작, 다시 누르면 중지) 모드 지원
- **Quick Fix** — `Ctrl+Shift+D`. 잘못 인식된 단어를 교정 사전에 바로 등록
- **취소** — `ESC`. 녹음 중 언제든 취소

### 교정 모드

| 모드 | 설명 |
|---|---|
| Standard | STT 오류 교정 — 띄어쓰기, 맞춤법, 잘못 인식된 단어 |
| Filler Removal | STT 교정 + 추임새 제거 (음, 어, 그러니까, 뭐랄까) |
| Structured | STT 교정 + 추임새 제거 + 불릿포인트로 구조화 |
| Custom | 직접 작성한 시스템 프롬프트로 교정 |

## 이름의 유래

> 처음엔 **FreeWhisper**였다. 나만 쓸 도구를 Swift로 대충 만든 거라 이름 따위는 신경도 안 썼다.
>
> 근데 이걸 오픈소스로 공개하려니까 이름이 필요해졌다. "Oh My ..." 시리즈는 솔직히 좀 유행 지난 느낌이었고, **OpenWhisper**는 이미 있는 것 같았다.
>
> API 키를 빌려다 쓰는 게 마치 남의 양지바른 자리에 슬쩍 눌러앉는 고양이 같아서 **Not My Whisper**라는 방향도 생각해봤다. 근데 매일 쓰다 보니 오히려 애착이 생겨버렸다. *"잠깐, 이거 내 Whisper 아닌가?"*
>
> 그래서 **Whispree**가 됐다.

## 꿀팁

> **직장인 팁**: 에어팟 끼고 통화하는 척하면 됩니다. 아무도 당신이 장보기 목록을 받아쓰고 있다는 걸 모릅니다.

> **Zoom 회의**: 음소거 걸고 Whispree에 속삭이세요. 회의록이 실시간으로 완성됩니다. 아무도 모릅니다.

> **대중교통**: "아주 중요한 전화를 받고 있는" 표정이 핵심입니다. 살짝 귀찮은 표정으로 말하면 완벽합니다.

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
# Xcode에서 Cmd+R로 빌드 및 실행
```

SPM 의존성은 첫 빌드 시 자동으로 해결됩니다.

## 사용법

### 기본 흐름

1. **첫 실행** — 마이크 권한과 접근성 권한을 허용합니다.
2. **모델 다운로드** — 설정 > 모델에서 사용할 STT/LLM 모델을 다운로드합니다. (클라우드 프로바이더만 쓸 경우 불필요)
3. **녹음** — `Ctrl+Shift+R`을 눌러 녹음합니다. 끝나면 자동으로 전사 + 교정이 진행됩니다.
4. **삽입** — 교정된 텍스트가 직전에 사용하던 앱의 커서 위치에 자동 붙여넣기됩니다.

### Quick Fix

자주 틀리는 단어가 있다면 `Ctrl+Shift+D`로 교정 사전에 등록하세요. 도메인 단어 세트(프로그래밍, 의료 등)를 만들어두면 해당 분야 용어 인식률이 올라갑니다.

### 설정

메뉴바 아이콘에서 설정에 접근할 수 있습니다.

- **일반** — 단축키 변경, 녹음 모드(Push to Talk / Toggle), 로그인 시 자동 시작
- **STT** — STT 프로바이더 선택 (WhisperKit, Groq, MLX Audio)
- **LLM** — LLM 프로바이더 선택 (없음, 로컬 Qwen3, OpenAI via Codex), 교정 모드 설정
- **모델** — 로컬 모델 다운로드 및 관리

## 요구 사항

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- 마이크 권한
- 접근성 권한 (텍스트 자동 삽입에 필요)

## 기여하기

[CONTRIBUTING.md](CONTRIBUTING.md)를 참고해주세요.

## 라이선스

[MIT](LICENSE)
