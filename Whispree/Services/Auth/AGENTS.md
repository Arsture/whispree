<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Auth

## Purpose
외부 인증 토큰 관리. Codex CLI 토큰 재사용 + OAuth PKCE 브라우저 로그인 fallback.

## Key Files

| File | Description |
|------|-------------|
| `CodexAuthService.swift` | `~/.codex/auth.json`에서 OpenAI 토큰 읽기 + 리프레시. OpenAIProvider가 우선 사용 |
| `OAuthService.swift` | OpenAI OAuth PKCE 인증. Codex CLI 없는 유저를 위한 fallback. 브라우저 로그인 → localhost:1455 콜백 → 토큰 교환. `~/.whispree/oauth.json`에 저장 |

## For AI Agents

### Working In This Directory
- `OpenAIProvider` 인증 우선순위: (1) CodexAuthService → (2) OAuthService
- `~/.codex/auth.json` 파일 형식이 변경되면 CodexAuthService 파싱 로직 업데이트 필요
- `OAuthService`는 `NWListener`로 TCP 콜백 서버 실행 (포트 1455). PKCE + state 검증으로 CSRF 방지
- 토큰이 없으면 OpenAIProvider는 `AuthError.notAuthenticated` throw

<!-- MANUAL: -->
