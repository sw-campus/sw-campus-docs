# 인증 (Auth) Spec

## 설계 결정

### 왜 JWT를 HttpOnly Cookie에 저장하는가?

XSS 공격 방지. JavaScript에서 토큰 접근 불가.

| 저장 방식 | XSS 취약 | CSRF 취약 | 선택 |
|-----------|:--------:|:---------:|:----:|
| localStorage | O | X | X |
| HttpOnly Cookie | X | O (SameSite로 방어) | O |

추가 보안 설정:
- `SameSite: Strict` - CSRF 방어
- `Secure: true` - HTTPS 전용 (prod)

### 왜 동시 로그인을 제한하는가?

계정 공유 방지 및 보안 강화.

- `REFRESH_TOKENS.USER_ID`에 UNIQUE 제약
- 새 로그인 시 기존 토큰 자동 삭제
- 사용자당 1개 세션만 유지

### 왜 Access Token 1시간, Refresh Token 1일인가?

보안과 사용성의 균형.

| 토큰 | 만료 | 이유 |
|------|------|------|
| Access | 1시간 | 탈취 시 피해 최소화 |
| Refresh | 1일 | 하루 한 번 재로그인으로 사용성 유지 |

Refresh 시 Access Token만 갱신, Refresh Token은 유지 (Sliding Session 아님).

### 왜 닉네임 중복 검사에 LOWER 인덱스를 사용하는가?

대소문자 혼동 방지. `ABC`와 `abc`를 동일 닉네임으로 취급.

```sql
CREATE UNIQUE INDEX members_nickname_lower_key
ON swcampus.members (LOWER(nickname))
WHERE nickname IS NOT NULL;
```

PostgreSQL 함수 기반 인덱스로 대소문자 무시 검색 성능 보장.

### 왜 이메일 인증을 필수로 하는가?

허위 계정 방지 및 비밀번호 찾기 기능 보장.

- 회원가입 전 이메일 인증 완료 필수
- 인증 완료된 이메일만 가입 가능
- 비밀번호 찾기 시 검증된 이메일로 발송

### 왜 OAuth에서 state 파라미터를 사용하는가?

CSRF 공격 방지.

```
1. 클라이언트: UUID 생성 → sessionStorage 저장 → OAuth URL에 state 포함
2. OAuth Provider: 인증 후 state 그대로 반환
3. 클라이언트: sessionStorage의 state와 비교 → 불일치 시 거부
```

### 왜 기관 담당자는 승인 전에도 로그인 가능한가?

UX 고려. 승인 대기 중에도 서비스 탐색 가능.

| 상태 | 로그인 | 강의 등록 |
|------|:------:|:---------:|
| PENDING | O | X |
| APPROVED | O | O |
| REJECTED | O | X |

승인 상태는 `Organization.approvalStatus`에서 관리.

---

## 구현 노트

### 2025-12-21 - 닉네임 중복 검사 구현 [Server]

- PR: #186
- 배경: 닉네임 중복으로 인한 혼란 방지
- 변경:
  - `GET /api/v1/members/nickname/check` API 추가
  - PostgreSQL `LOWER()` 인덱스로 대소문자 무시
  - 회원가입 시 중복 검사 강제
- 관련: `MemberService.java`, `V19__add_nickname_unique_constraint.sql`

### 2025-12-21 - 닉네임 중복 검사 UI [Client]

- 배경: 회원가입 시 사용 가능한 닉네임 확인 필요
- 변경:
  - `NickNameInput.tsx` 컴포넌트 추가
  - 3가지 상태 UI (available/unavailable/error)
  - 회원가입 전 중복 검사 필수
- 관련: `useSignupForm.ts`, `NickNameInput.tsx`

### 2025-12-14 - MemberPrincipal 도입 [Server]

- 배경: Spring Security 표준 준수
- 변경:
  - `MemberPrincipal` record 도입
  - `@CurrentMember` 커스텀 어노테이션
  - Swagger 문서에서 자동 숨김 처리

### 2025-12-10 - 토큰 자동 갱신 구현 [Client]

- 배경: 토큰 만료 시 사용자 경험 개선
- 변경:
  - Axios 인터셉터로 401 감지
  - 자동 refresh 및 원래 요청 재시도
  - 중복 refresh 방지 (isRefreshing 플래그)
- 관련: `axios.ts`

### 2025-12-05 - 초기 구현 [Server][Client]

**Server:**
- 이메일 인증, 회원가입, 로그인/로그아웃
- JWT 기반 인증 (HttpOnly Cookie)
- OAuth 연동 (Google, GitHub)
- 비밀번호 변경/재설정
- 동시 로그인 제한

**Client:**
- 로그인/로그아웃 UI (Zustand 상태 관리)
- OAuth 플로우 (Google, GitHub)
- 이메일 인증 (폴링 방식)
- 비밀번호 찾기 (`FindPasswordModal` - 임시 비밀번호 발급)
- 비밀번호 변경 (`PasswordChangeModal` - 마이페이지)
- 비밀번호 검증 (`PasswordVerifyModal` - 개인정보 수정 전)
- AdminGuard (관리자 라우트 보호)

**OAuth 사용자 특별 처리:**
- 비밀번호 찾기/변경 불가 (Server 예외 처리)
- 비밀번호 검증 자동 통과 (비밀번호 없음)
- UI에서 비밀번호 변경 버튼 숨김

---

## 미구현 사항

| 기능 | 상태 | 비고 |
|------|:----:|------|
| 마이페이지 라우트 보호 | X | AdminGuard만 존재 |
| 2단계 인증 (2FA) | X | Out of Scope |
| 로그인 실패 횟수 제한 | X | Out of Scope |
