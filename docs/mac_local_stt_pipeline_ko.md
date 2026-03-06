# Mac M2 Pro에서 로컬 STT + LLM 받아쓰기 파이프라인 구축

**M2 Pro에서 최적의 완전 로컬 한국어/영어 받아쓰기 파이프라인은 mlx-whisper(`large-v3-turbo` 모델)와 mlx-lm의 Qwen2.5-3B 조합입니다.** 이 조합은 Apple의 MLX 프레임워크 안에서 통합 메모리를 최적으로 활용하며, 엔드투엔드 레이턴시는 약 2~3초입니다. `push-to-talk-dictate`라는 오픈소스 프로젝트가 이 정확한 파이프라인을 이미 구현해 두었습니다. Option 키를 누르고 말한 뒤 손을 떼면 교정된 텍스트가 현재 창에 자동으로 입력됩니다. 더 많은 제어를 원한다면 Hammerspoon + 쉘 스크립트 방식이 최대의 모듈성을 제공합니다.

---

## Apple Silicon용 Whisper 런타임 비교

Mac에서 Whisper를 실행하는 구현체는 네 가지가 있지만, **Python 기반 워크플로우에서는 mlx-whisper가 압도적으로 유리합니다.** whisper.cpp 대비 약 2배 빠르며, M2 Pro 기준 10~30초 클립 처리 성능은 다음과 같습니다:

| 구현체 | 백엔드 | GPU/ANE | 레이턴시 (large-v3-turbo) | 설치 난이도 |
|---|---|---|---|---|
| **mlx-whisper** | Apple MLX GPU | ✅ 완전 지원 | **~1.0~1.5초** (권장) | `pip install mlx-whisper` |
| **WhisperKit** | CoreML + ANE | ✅ 완전 지원 | **~0.5~1.0초** (최고 속도) | Swift/Xcode 필요 |
| **whisper.cpp + CoreML** | C++ + ANE 인코더 | 부분 지원 | ~1.2~2.0초 | 소스 빌드 + CoreML 모델 생성 |
| **whisper.cpp (Metal)** | C++ + Metal | ✅ Metal | ~2~3초 | `cmake && make` |
| **faster-whisper** | CTranslate2 CPU | ❌ CPU 전용 | ~3~5초 | Mac에서 비권장 |

mlx-whisper는 `pip install mlx-whisper` 한 줄과 Python 코드 세 줄로 오디오를 전사할 수 있습니다. HuggingFace에서 모델을 자동으로 다운로드하며, MLX를 통해 Apple Silicon GPU에서 네이티브로 실행됩니다. `lightning-whisper-mlx` 래퍼는 배치 디코딩으로 추가 4배 속도 향상을 주장하지만, 실제 이득은 오디오 길이에 따라 다릅니다.

**WhisperKit**(Argmax, ICML 2025)은 speculative decoding으로 large-v3 대비 2.24배 속도 향상을 달성하고, large-v3-turbo를 1.6GB에서 0.6GB로 압축하면서 정확도 손실은 1% 미만으로 유지합니다. Swift/Xcode로 macOS/iOS 앱을 빌드할 때는 이상적이지만, Python 스크립트 파이프라인에서는 불편합니다.

---

## 모델 선택: distil-whisper를 쓰면 안 되는 이유

**핵심 선택: `large-v3-turbo`가 한국어/영어 이중 언어에서 속도-정확도 균형의 최적점입니다.**

많은 가이드에서 속도를 이유로 추천하는 distil-whisper 시리즈(distil-large-v2, distil-large-v3)는 **영어 전용**입니다. 한국어 오디오를 입력하면 깨진 출력이 나오거나 강제로 영어 번역이 됩니다. 한국어-영어 이중 언어 사용자에게는 치명적인 함정입니다.

`large-v3-turbo`는 디코더 레이어가 32개(full large-v3)가 아닌 4개뿐이라, **추론 속도 4~6배** 향상을 제공합니다. 메모리는 약 1.5GB(full large-v3는 ~3GB)로, 16GB M2 Pro에서 3B LLM과 동시에 올려도 여유가 있습니다. 한국어 CER(문자 오류율)은 KsponSpeech 기준 약 12~14%로, full large-v3의 ~11%와 근소한 차이입니다.

한국어 정확도를 더 높이고 싶다면 HuggingFace의 커뮤니티 파인튜닝 모델을 시도할 수 있습니다. **seastar105/Korean-Whisper** 컬렉션(Google TPU 지원으로 다양한 한국어 데이터셋 학습)과 **o0dimplz0o/Whisper-Large-v3-turbo-STT-Zeroth-KO-v2**가 대표적입니다. ENERZAi 연구에 따르면 한국어 파인튜닝으로 CER을 18%에서 6.4%까지 절감할 수 있으며, large-v3-turbo 기반 파인튜닝이라면 7~8% CER 달성도 가능합니다.

---

## Qwen2.5-3B: 한국어 교정용 최적 LLM

후처리 단계(구두점, 띄어쓰기, 조사, 동음이의어 교정)에는 **Qwen2.5-3B-Instruct 4비트 양자화**를 권장합니다. 한국어를 포함한 29개 이상 언어를 지원하고, KMMLU(한국어 MMLU) 벤치마크로 평가되었으며, 메모리 약 2GB로 Whisper와 동시에 올릴 수 있습니다.

M2 Pro 기준 50~70 tokens/sec 생성 속도로, 일반적인 받아쓰기 교정(50~100 토큰)에 **약 0.7~1.5초**가 소요됩니다. 따라서 전체 파이프라인 레이턴시는 **Whisper ~1초 + LLM 교정 ~1~1.5초 = 2~3초** 수준입니다.

대안 모델과의 비교:

- **EXAONE 3.5 2.4B** (LG AI Research): 한국어-영어 이중 언어 전용으로 2.4B 파라미터 대비 성능이 뛰어나지만, 비상업적 연구 라이센스이고 MLX 포맷 변환이 필요합니다.
- **Qwen3-4B**: 100개 이상 언어 지원의 최신 세대 모델. 비사고(non-thinking) 모드로 사용하면 교정 속도가 빠릅니다. `mlx-community/Qwen3-4B-Instruct-2507-4bit`로 사용 가능합니다.
- **Llama 3.2 3B**: 빠르고 지원이 잘 되어 있지만, 한국어 사전학습 데이터 부족으로 교정 품질이 떨어집니다.
- **레거시 한국어 모델** (KULLM, KoAlpaca, SOLAR): 오래된 아키텍처 기반으로 Qwen2.5 같은 현대 다국어 모델에 이미 추월되었습니다.

EMNLP 2023 KEBAP 벤치마크는 LLM 교정이 타깃해야 할 한국어 ASR 오류 13가지를 분류합니다. 가장 중요한 오류 유형은 **띄어쓰기 오류**(조사가 명사에 붙어야 함), **구두점 누락**, **동음이의어 치환**, **G2P 오류**(표준 맞춤법 대신 발음 표기, 예: '같이' → '가치')입니다. 아래 시스템 프롬프트가 이 모든 유형을 커버합니다:

```
System: 당신은 한국어/영어 이중 언어 텍스트 교정 보조입니다.
다음 STT 오류를 수정하세요: (1) 띄어쓰기, (2) 구두점,
(3) 동음이의어, (4) 조사 (은/는, 이/가, 을/를),
(5) G2P 맞춤법 오류. 의미를 바꾸지 마세요. 원래 언어를 유지하세요.
수정된 텍스트만 출력하세요.
```

---

## 즉시 사용 가능한 오픈소스 프로젝트

처음부터 파이프라인을 직접 만들 필요 없이 아래 프로젝트를 바로 활용할 수 있습니다.

**push-to-talk-dictate** (github.com/Rasala/push-to-talk-dictate)는 Superwhisper와 가장 유사한 동작을 제공합니다. **MLX Whisper large-v3 → Qwen2.5/Phi-3 LLM 교정 → 활성 창에 자동 타이핑**을 완전 로컬로 구현합니다. Option 키를 누르고 말하고, 손을 떼면 교정된 텍스트가 커서 위치에 나타납니다. `.env` 파일에서 LLM 모델, 언어, 출력 방식을 설정합니다.

```bash
git clone https://github.com/Rasala/push-to-talk-dictate
cd push-to-talk-dictate && cp .env.example .env
# .env 수정: LANGUAGE=ko, LLM_MODEL=qwen, OUTPUT_MODE=type
pip install -r requirements.txt
python -m dictate
```

**Spellspoon** (github.com/kevinjalbert/spellspoon)은 Hammerspoon 기반의 모듈형 접근법입니다. 녹음, 전사, LLM 프롬프팅 쉘 스크립트를 직접 커스터마이징할 수 있습니다. 전사 스크립트는 whisper-cli 또는 mlx-whisper를, 프롬프팅 스크립트는 `ollama run qwen2.5:3b` 또는 로컬 mlx-lm 서버를 가리키면 됩니다.

**OpenSuperWhisper** (github.com/Starmel/OpenSuperWhisper)는 `brew install opensuperwhisper`로 설치하는 네이티브 macOS 앱으로, 아시아 언어를 명시적으로 지원하며 전역 단축키 `cmd+\``를 제공합니다. 내장 LLM 후처리는 없지만, 가장 완성도 높은 오픈소스 Superwhisper 클론입니다.

**VoiceInk** (github.com/Beingpax/VoiceInk)는 가장 기능이 풍부한 오픈소스 옵션입니다. 네이티브 Swift 앱으로 시스템 전역 단축키, 앱별 설정이 자동 적용되는 "Power Mode", 화면 컨텍스트 인식 기능을 제공합니다. GPL v3 라이센스로 소스에서 무료 빌드하거나 $39에 구매할 수 있습니다.

더 간단한 방법으로는 **MacWhisper Pro** (~$60 일회성 구매)가 **Ollama 연동**을 지원합니다. Ollama 설치 후 `qwen2.5:3b`를 풀하고 MacWhisper 설정에서 AI 서비스로 지정하면, 받아쓰기 출력이 로컬 LLM을 거쳐 자동으로 교정됩니다.

---

## 직접 구축: 완전한 설정 가이드

### 1단계: 의존성 설치

```bash
brew install sox ffmpeg
pip install mlx-whisper mlx-lm pyaudio requests
```

LLM 런타임은 두 가지 중 선택합니다:

```bash
# 옵션 A: Ollama (간단한 REST API)
brew install ollama
ollama pull qwen2.5:3b
ollama serve &

# 옵션 B: mlx-lm (Python 네이티브, 더 빠름)
# 별도 설치 불필요 — mlx-lm이 모델을 자동으로 로드
```

### 2단계: 전사 테스트

```bash
# 테스트 클립 녹음 (말한 후 Ctrl+C)
rec -r 16000 -c 1 -b 16 /tmp/test.wav

# mlx-whisper로 전사
python3 -c "
import mlx_whisper
result = mlx_whisper.transcribe('/tmp/test.wav',
    path_or_hf_repo='mlx-community/whisper-large-v3-turbo', language='ko')
print(result['text'])
"
```

### 3단계: Hammerspoon으로 글로벌 단축키 설정

```bash
brew install --cask hammerspoon
```

`~/.hammerspoon/init.lua`에 추가:

```lua
local recording = false
local recTask = nil
local audioFile = "/tmp/hs_dictation.wav"

hs.hotkey.bind({"ctrl", "cmd"}, "d", function()
    if not recording then
        recording = true
        hs.alert.show("🎤 녹음 중...")
        recTask = hs.task.new("/opt/homebrew/bin/rec", nil,
            {"-r", "16000", "-c", "1", "-b", "16", audioFile})
        recTask:start()
    else
        recording = false
        if recTask then recTask:terminate() end
        hs.alert.show("⏳ 처리 중...")
        hs.task.new("/bin/bash", function(_, stdOut)
            if stdOut and #stdOut > 0 then
                hs.pasteboard.setContents(stdOut)
                hs.eventtap.keyStroke({"cmd"}, "v")
                hs.alert.show("✅ 완료")
            end
        end, {"-c", os.getenv("HOME") .. "/dictate_pipeline.sh " .. audioFile}):start()
    end
end)
```

### 4단계: 파이프라인 스크립트 (`~/dictate_pipeline.sh`)

```bash
#!/bin/bash
AUDIO="$1"

# mlx-whisper로 전사
RAW=$(python3 -c "
import mlx_whisper
r = mlx_whisper.transcribe('$AUDIO',
    path_or_hf_repo='mlx-community/whisper-large-v3-turbo', language='ko')
print(r['text'].strip())
")

# Ollama (Qwen2.5-3B)로 교정
CORRECTED=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"qwen2.5:3b\",
  \"prompt\": \"문법, 구두점, 띄어쓰기 오류를 수정하세요. 원래 언어를 유지하세요. 수정된 텍스트만 출력하세요:\n\n$RAW\",
  \"stream\": false
}" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'].strip())")

echo -n "$CORRECTED"
```

---

## 결론

Apple Silicon의 로컬 받아쓰기 환경은 이미 충분히 성숙했습니다. **mlx-whisper + large-v3-turbo**는 한국어에서 최고의 속도-정확도 균형을 제공하며, 일반적인 클립을 약 1초 안에 처리합니다. **Qwen2.5-3B 4비트**를 더하면 약 1초를 추가해 띄어쓰기, 구두점, 동음이의어를 지능적으로 교정합니다. 총 2~3초 파이프라인은 16GB 통합 메모리 안에서 동작합니다(Whisper ~1.5GB + LLM ~2GB).

세 가지 핵심 인사이트를 기억하세요. 첫째, distil-whisper의 영어 전용 한계는 제대로 문서화되어 있지 않아 다국어 사용자에게 큰 함정이 됩니다. 한국어에서 "빠른" 선택은 large-v3-turbo입니다. 둘째, `push-to-talk-dictate` 프로젝트가 이미 최적의 MLX Whisper → Qwen2.5 파이프라인을 최소 설정으로 구현해 두었습니다. 셋째, HuggingFace의 한국어 파인튜닝 Whisper 모델은 기본 large-v3 대비 CER을 절반으로 줄일 수 있으므로, 기본 정확도가 부족할 경우 시도해볼 만합니다. 대부분의 사용자에게는 `push-to-talk-dictate`로 시작해 필요에 따라 커스터마이징하는 것이 Superwhisper를 비용 없이 대체하는 가장 빠른 경로입니다.
