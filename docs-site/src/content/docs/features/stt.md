---
title: STT 엔진
description: 받아쓰기 엔진 세 가지 — WhisperKit · Groq · MLX Audio, 언어 선택과 무음 자동 스킵.
---

STT(Speech-to-Text)는 말소리를 글로 바꾸는 엔진입니다. Whispree는 세 가지를 제공하며 설정 → STT 또는 홈 대시보드에서 **언제든 전환**할 수 있습니다.

## 엔진 비교

| 엔진 | 위치 | 모델 | 필요 조건 | 특징 |
| --- | --- | --- | --- | --- |
| **WhisperKit** *(기본)* | 로컬 (CoreML + Neural Engine) | `whisper-large-v3-turbo` (~1.5 GB) | 첫 사용 시 모델 다운로드 | 99개 언어, 도메인 단어를 인식 힌트로 주입. 인터넷 없이 동작. |
| **Groq Cloud** | 클라우드 | `whisper-large-v3-turbo` (서버) | Groq API 키 | 매우 빠름(~200ms). 음성을 WAV로 변환해 업로드. |
| **MLX Audio** | 로컬 (Python 워커) | `Qwen3-ASR-1.7B-8bit` (~1.0 GB) | `uv` 설치 | 한·중·일·영 강점. 첫 로드(콜드스타트) ~1분. mlx-audio 모델이면 교체 가능. |

:::tip
가장 간단하게 시작하려면 **WhisperKit**(로컬, 설정 불필요)으로 두세요. 더 빠른 클라우드를 원하면 [console.groq.com](https://console.groq.com)에서 키를 발급해 **Groq**를 쓰면 됩니다. Groq 키는 STT·교정 양쪽에서 공유됩니다.
:::

## 언어

설정에서 인식 언어를 고릅니다: **자동 감지** 또는 ko · en · ja · zh · es · fr · de · pt.

- **자동 감지**는 편하지만 정확도가 떨어질 수 있어 경고가 표시됩니다. 한 언어로 주로 말한다면 그 언어를 고정하는 편이 정확합니다.
- WhisperKit은 자동 감지에서 한·영·일·중이 아닌 언어로 잘못 잡히면 한국어로 한 번 더 시도하는 보정이 있습니다.

선택한 언어는 AI 교정 프롬프트 선택에도 사용됩니다(한↔영 코드스위칭 등). [AI 교정](/features/correction/) 참고.

## 무음 자동 스킵 (VAD)

설정 → STT의 **무음 자동 스킵** *(기본 켜짐)* 은 음성 활동 감지(VAD)로 말이 없는 구간을 변환 전에 제거합니다. 모든 STT 엔진에 적용되어 변환을 더 빠르고 깔끔하게 만들고, 녹음 중에는 “무음 스킵 중” 표시로 알려줍니다.

## 도메인 단어 인식

WhisperKit과 MLX Audio는 [단어 사전](/features/dictionary/)에 등록한 도메인 단어를 인식 힌트로 받아, 전문 용어·고유명사의 받아쓰기 정확도를 높입니다.
