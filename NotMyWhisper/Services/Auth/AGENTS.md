<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Auth

## Purpose
외부 인증 토큰 재사용. Codex CLI의 인증 정보를 읽어 OpenAI API 호출에 활용.

## Key Files

| File | Description |
|------|-------------|
| `CodexAuthService.swift` | `~/.codex/auth.json`에서 OpenAI 토큰 읽기. OpenAIProvider가 사용 |

## For AI Agents

### Working In This Directory
- `~/.codex/auth.json` 파일 형식이 변경되면 파싱 로직 업데이트 필요
- 토큰이 없으면 OpenAIProvider는 수동 API 키로 폴백

<!-- MANUAL: -->
