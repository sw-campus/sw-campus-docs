# 인증 (Auth) Spec

## 개요

회원가입, 로그인, 로그아웃, 토큰 관리, 비밀번호 변경/찾기 기능의 기술 명세입니다.

---

## API

### 이메일 인증

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/email/send` | 인증 메일 발송 | X |
| GET | `/api/v1/auth/email/verify?token={token}` | 인증 링크 확인 (302 리다이렉트) | X |
| GET | `/api/v1/auth/email/status?email={email}` | 인증 상태 확인 | X |

### 닉네임 중복 검사

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/members/nickname/check?nickname={nickname}` | 닉네임 사용 가능 여부 확인 | X |

**Response**: `{ "isAvailable": true/false }`

### 회원가입

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/signup` | 일반 사용자 회원가입 | X |
| POST | `/api/v1/auth/signup/organization` | 기관 담당자 회원가입 (multipart) | X |

**닉네임 규칙**:
- 최대 20자
- 허용 문자: `a-z`, `A-Z`, `0-9`, `가-힣`, `-`, `_`
- 대소문자 무시 중복 검사 (ABC = abc)

**기관 회원가입 필드**:
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| email, password, name, nickname, phone, location | string | O | 기본 정보 |
| certificateImage | file | O | 재직증명서 이미지 |
| organizationId | string | X | 기존 기관 선택 시 |

### 소셜 인증

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/oauth/{provider}` | 소셜 로그인/회원가입 | X |

**Provider**: `google`, `github`

### 로그인/로그아웃

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/login` | 이메일 로그인 | X |
| POST | `/api/v1/auth/logout` | 로그아웃 | O |
| POST | `/api/v1/auth/refresh` | Access Token 갱신 | X (Cookie) |

### 비밀번호

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| PATCH | `/api/v1/auth/password` | 비밀번호 변경 | O |
| POST | `/api/v1/auth/password/reset-request` | 재설정 메일 요청 | X |
| POST | `/api/v1/auth/password/reset` | 비밀번호 재설정 | X |

---

## DB 스키마

### MEMBERS (기존)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| USER_ID | BIGSERIAL PK | 사용자 ID |
| EMAIL | VARCHAR(255) UNIQUE | 이메일 |
| PASSWORD | VARCHAR(255) | 비밀번호 (BCrypt) |
| NAME, NICKNAME | VARCHAR(255) | 이름, 닉네임 |
| PHONE, LOCATION | VARCHAR(255) | 연락처, 주소 |
| ROLE | ENUM | USER, ORGANIZATION, ADMIN |
| ORG_ID | INTEGER | 기관 ID (기관 담당자) |

### 추가 테이블

| 테이블 | 주요 컬럼 | 설명 |
|--------|----------|------|
| REFRESH_TOKENS | USER_ID (UNIQUE), TOKEN, EXPIRES_AT | Refresh Token 저장 |
| EMAIL_VERIFICATIONS | EMAIL, TOKEN, VERIFIED, EXPIRES_AT | 이메일 인증 |
| SOCIAL_ACCOUNTS | USER_ID, PROVIDER, PROVIDER_ID | 소셜 계정 연동 |
| PASSWORD_RESET_TOKENS | USER_ID, TOKEN, EXPIRES_AT, USED | 비밀번호 재설정 |

---

## 보안 설계

### JWT 설정

| 항목 | Access Token | Refresh Token |
|------|-------------|---------------|
| 만료 시간 | 1시간 | 1일 |
| 알고리즘 | HS256 | HS256 |
| 저장 위치 | HttpOnly Cookie | HttpOnly Cookie |

### Cookie 설정

```
HttpOnly: true
Secure: true (HTTPS)
SameSite: Strict
Path: /
```

### 비밀번호 정책

- 최소 8자
- 특수문자 1개 이상 필수
- BCrypt (strength: 10)

### 동시 로그인 제한

- `REFRESH_TOKENS.USER_ID` UNIQUE 제약으로 사용자당 1개 토큰만 유지
- 새 로그인 시 기존 토큰 삭제

### MemberPrincipal

```java
public record MemberPrincipal(Long memberId, String email, Role role) {}
```

**@CurrentMember 어노테이션**: `@AuthenticationPrincipal` 래퍼, Swagger 자동 숨김

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| AUTH001 | 400 | 이메일 형식 오류 |
| AUTH002 | 400 | 비밀번호 형식 오류 (8자+, 특수문자 1+) |
| AUTH003 | 401 | 이메일/비밀번호 불일치 |
| AUTH004 | 401 | 토큰 만료 |
| AUTH005 | 401 | 유효하지 않은 토큰 |
| AUTH006 | 403 | 이메일 인증 미완료 |
| AUTH007 | 409 | 이미 가입된 이메일 |
| AUTH008 | 404 | 인증 정보 없음 |
| AUTH009 | 400 | 현재 비밀번호 불일치 |
| AUTH010 | 400 | 재설정 토큰 만료 |
| NICKNAME_ALREADY_EXISTS | 409 | 이미 사용 중인 닉네임 |

---

## 구현 노트

### 2025-12-21 - 닉네임 중복 검사 구현

- PR: #186
- 닉네임 사용 가능 여부 확인 API 추가 (`GET /api/v1/members/nickname/check`)
- 회원가입 시 닉네임 중복 검사 (일반/기관)
- 닉네임 유효성 규칙 추가 (최대 20자, 허용 문자: a-zA-Z0-9가-힣_-)
- 대소문자 무시 중복 검사 (PostgreSQL `LOWER()` 인덱스)
- DB 마이그레이션: V19__add_nickname_unique_constraint.sql
- MemberEntity nickname 필드에 `@Column(unique = true)` 추가

### 2025-12-14 - MemberPrincipal 도입

- Spring Security 표준 준수
- `@CurrentMember` 커스텀 어노테이션 도입
- Swagger 문서에서 자동 숨김 처리

### 2025-12-05 - 초기 구현

- 이메일 인증, 회원가입, 로그인/로그아웃
- JWT 기반 인증 (HttpOnly Cookie)
- OAuth (Google, GitHub) 연동
- 비밀번호 변경/재설정
