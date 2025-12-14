# 인증 (Auth) - Tech Spec

> Technical Specification

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-05 |
| 상태 | Draft |
| 버전 | 0.1 |
| PRD | [prd.md](./prd.md) |

---

## 1. 개요

### 1.1 목적

PRD에 정의된 인증 기능(회원가입, 로그인, 로그아웃, 토큰 관리, 비밀번호 변경/찾기)의 기술적 구현 명세를 정의합니다.

### 1.2 기술 스택

| 구분 | 기술 |
|------|------|
| Framework | Spring Boot 3.x |
| Security | Spring Security 6.x |
| JWT | jjwt 0.12.x |
| Database | PostgreSQL |
| ORM | Spring Data JPA |
| OAuth | Spring Security OAuth2 Client |

---

## 2. 시스템 아키텍처

### 2.1 모듈 구조

```
sw-campus-server/
├── sw-campus-api/                    # Presentation Layer
│   └── auth/
│       ├── AuthController.java
│       ├── OAuthController.java
│       ├── request/
│       └── response/
│
├── sw-campus-domain/                 # Business Logic Layer
│   ├── auth/
│   │   ├── AuthService.java
│   │   ├── TokenProvider.java
│   │   └── 도메인 객체 & Repository 인터페이스
│   ├── oauth/
│   │   └── OAuthService.java
│   └── member/
│       └── MemberService.java
│
└── sw-campus-infra/db-postgres/      # Infrastructure Layer
    ├── auth/
    │   └── Entity & Repository 구현체
    ├── oauth/
    └── member/
```

### 2.2 컴포넌트 구조

#### sw-campus-api

```
com.swcampus.api/
├── auth/
│   ├── AuthController.java
│   ├── request/
│   │   ├── EmailSendRequest.java
│   │   ├── SignupRequest.java
│   │   ├── OrganizationSignupRequest.java
│   │   ├── LoginRequest.java
│   │   ├── PasswordChangeRequest.java
│   │   ├── PasswordResetRequest.java
│   │   └── PasswordResetConfirmRequest.java
│   └── response/
│       ├── EmailStatusResponse.java
│       └── SignupResponse.java
├── security/
│   ├── JwtAuthenticationFilter.java
│   ├── CurrentMember.java            # 커스텀 어노테이션 (@AuthenticationPrincipal 래퍼)
│   └── SecurityConfig.java
├── oauth/
│   ├── OAuthController.java
│   ├── request/
│   │   └── OAuthCallbackRequest.java
│   └── response/
│       └── OAuthLoginResponse.java
```

#### sw-campus-domain

```
com.swcampus.domain/
├── auth/
│   ├── AuthService.java
│   ├── TokenProvider.java
│   ├── MemberPrincipal.java          # 인증된 사용자 정보 (Principal)
│   ├── EmailVerification.java
│   ├── EmailVerificationRepository.java
│   ├── RefreshToken.java
│   ├── RefreshTokenRepository.java
│   ├── PasswordResetToken.java
│   ├── PasswordResetTokenRepository.java
│   └── exception/
│       ├── InvalidCredentialsException.java
│       ├── EmailNotVerifiedException.java
│       ├── TokenExpiredException.java
│       └── DuplicateEmailException.java
├── oauth/
│   ├── OAuthService.java
│   ├── OAuthClient.java (interface)
│   ├── OAuthClientFactory.java (interface)
│   ├── OAuthUserInfo.java
│   ├── OAuthLoginResult.java
│   ├── SocialAccount.java
│   ├── SocialAccountRepository.java
│   └── OAuthProvider.java (enum: GOOGLE, GITHUB)
├── member/
│   ├── Member.java
│   ├── MemberRepository.java
│   ├── MemberService.java
│   └── Role.java (enum: USER, ORGANIZATION, ADMIN)
```

#### sw-campus-infra/db-postgres

```
com.swcampus.infra.postgres/
├── auth/
│   ├── EmailVerificationEntity.java
│   ├── EmailVerificationJpaRepository.java
│   ├── EmailVerificationEntityRepository.java
│   ├── RefreshTokenEntity.java
│   ├── RefreshTokenJpaRepository.java
│   ├── RefreshTokenEntityRepository.java
│   ├── PasswordResetTokenEntity.java
│   ├── PasswordResetTokenJpaRepository.java
│   └── PasswordResetTokenEntityRepository.java
├── oauth/
│   ├── SocialAccountEntity.java
│   ├── SocialAccountJpaRepository.java
│   └── SocialAccountEntityRepository.java
├── member/
│   ├── MemberEntity.java
│   ├── MemberJpaRepository.java
│   └── MemberEntityRepository.java
```

---

## 3. API 설계

### 3.1 이메일 인증

#### `POST /api/v1/auth/email/send`

이메일 인증 메일 발송

**Request**
```json
{
  "email": "user@example.com"
}
```

**Response** `200 OK`
```json
{
  "message": "인증 메일이 발송되었습니다"
}
```

**Errors**
- `400` AUTH001: 이메일 형식 오류
- `409` AUTH007: 이미 가입된 이메일

---

#### `GET /api/v1/auth/email/verify`

이메일 인증 링크 클릭 시 호출

**Query Parameters**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| token | string | ✅ | 인증 토큰 |

**Response** `302 Found`
- 인증 성공: 프론트엔드 회원가입 페이지로 리다이렉트
- 인증 실패: 에러 페이지로 리다이렉트

---

#### `GET /api/v1/auth/email/status`

이메일 인증 상태 확인

**Query Parameters**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| email | string | ✅ | 이메일 |

**Response** `200 OK`
```json
{
  "email": "user@example.com",
  "verified": true
}
```

---

### 3.2 회원가입

#### `POST /api/v1/auth/signup`

일반 사용자 회원가입

**Request**
```json
{
  "email": "user@example.com",
  "password": "Password1!",
  "name": "홍길동",
  "nickname": "길동이",
  "phone": "010-1234-5678",
  "location": "서울시 강남구"
}
```

**Response** `201 Created`
```json
{
  "userId": 1,
  "email": "user@example.com",
  "name": "홍길동",
  "nickname": "길동이",
  "role": "USER"
}
```

**Errors**
- `400` AUTH001: 이메일 형식 오류
- `400` AUTH002: 비밀번호 형식 오류
- `403` AUTH006: 이메일 인증 미완료
- `409` AUTH007: 이미 가입된 이메일

---

#### `POST /api/v1/auth/signup/organization`

기관 담당자 회원가입

**Request** `multipart/form-data`
| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| email | string | ✅ | 이메일 |
| password | string | ✅ | 비밀번호 |
| name | string | ✅ | 이름 |
| nickname | string | ✅ | 닉네임 |
| phone | string | ✅ | 전화번호 |
| location | string | ✅ | 주소 |
| certificateImage | file | ✅ | 재직증명서 이미지 |

**Response** `201 Created`
```json
{
  "userId": 1,
  "email": "org@example.com",
  "name": "김기관",
  "nickname": "기관담당자",
  "role": "ORGANIZATION",
  "orgAuth": 0
}
```

---

### 3.3 소셜 인증

#### `POST /api/v1/auth/oauth/{provider}`

소셜 로그인/회원가입

**Path Parameters**
| 파라미터 | 설명 |
|---------|------|
| provider | `google` 또는 `github` |

**Request**
```json
{
  "code": "authorization_code_from_oauth_provider"
}
```

**Response** `200 OK`
```
Set-Cookie: accessToken=...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=3600
Set-Cookie: refreshToken=...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=86400
```

```json
{
  "memberId": 1,
  "email": "user@gmail.com",
  "name": "홍길동",
  "nickname": "사용자_a1b2c3d4",
  "role": "USER"
}
```

> 신규 OAuth 사용자는 랜덤 닉네임("사용자_" + UUID 8자리)이 자동 생성됩니다. phone, location은 선택 사항입니다.

---

### 3.4 로그인

#### `POST /api/v1/auth/login`

이메일 로그인

**Request**
```json
{
  "email": "user@example.com",
  "password": "Password1!"
}
```

**Response** `200 OK`
```
Set-Cookie: accessToken=...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=3600
Set-Cookie: refreshToken=...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=86400
```

```json
{
  "userId": 1,
  "email": "user@example.com",
  "name": "홍길동",
  "role": "USER"
}
```

> ORGANIZATION인 경우 `orgAuth` 필드 추가 반환 (0: 미승인, 1: 승인)

**Errors**
- `401` AUTH003: 이메일 또는 비밀번호 불일치

---

### 3.5 로그아웃

#### `POST /api/v1/auth/logout`

로그아웃

**Request**
```
Cookie: accessToken=...; refreshToken=...
```

**Response** `200 OK`
```
Set-Cookie: accessToken=; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=0
Set-Cookie: refreshToken=; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=0
```

---

### 3.6 토큰 갱신

#### `POST /api/v1/auth/refresh`

Access Token 갱신

**Request**
```
Cookie: refreshToken=...
```

**Response** `200 OK`
```
Set-Cookie: accessToken=...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=3600
```

**Errors**
- `401` AUTH004: 토큰 만료
- `401` AUTH005: 유효하지 않은 토큰

---

### 3.7 비밀번호 변경/찾기

#### `PATCH /api/v1/auth/password`

비밀번호 변경 (로그인 상태)

**Request**
```
Cookie: accessToken=...
```

```json
{
  "currentPassword": "OldPassword1!",
  "newPassword": "NewPassword1!"
}
```

**Response** `200 OK`

**Errors**
- `400` AUTH009: 현재 비밀번호 불일치
- `400` AUTH002: 새 비밀번호 형식 오류

---

#### `POST /api/v1/auth/password/reset-request`

비밀번호 재설정 이메일 요청

**Request**
```json
{
  "email": "user@example.com"
}
```

**Response** `200 OK`
```json
{
  "message": "비밀번호 재설정 메일이 발송되었습니다"
}
```

---

#### `POST /api/v1/auth/password/reset`

비밀번호 재설정

**Request**
```json
{
  "token": "reset_token",
  "newPassword": "NewPassword1!"
}
```

**Response** `200 OK`

**Errors**
- `400` AUTH010: 토큰 만료
- `400` AUTH002: 비밀번호 형식 오류

---

## 4. 데이터베이스 스키마

### 4.1 기존 테이블 (MEMBERS)

```sql
-- 기존 ERD 기반, 컨럼명 확인 필요
CREATE TYPE member_role AS ENUM ('USER', 'ORGANIZATION', 'ADMIN');

CREATE TABLE MEMBERS (
    USER_ID BIGSERIAL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL UNIQUE,
    PASSWORD VARCHAR(255),
    NAME VARCHAR(255) NOT NULL,
    NICKNAME VARCHAR(255) NOT NULL,
    PHONE VARCHAR(255) NOT NULL,
    ROLE member_role NOT NULL DEFAULT 'USER',
    ORG_AUTH SMALLINT DEFAULT NULL,
    ORG_ID INTEGER,
    LOCATION VARCHAR(255),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 4.2 추가 테이블

#### REFRESH_TOKENS

```sql
CREATE TABLE REFRESH_TOKENS (
    ID BIGSERIAL PRIMARY KEY,
    USER_ID BIGINT NOT NULL UNIQUE REFERENCES MEMBERS(USER_ID) ON DELETE CASCADE,
    TOKEN VARCHAR(500) NOT NULL UNIQUE,
    EXPIRES_AT TIMESTAMP NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_refresh_tokens_token ON REFRESH_TOKENS(TOKEN);
```

> `USER_ID UNIQUE`: 동시 로그인 제한을 위해 사용자당 1개의 Refresh Token만 저장

#### EMAIL_VERIFICATIONS

```sql
CREATE TABLE EMAIL_VERIFICATIONS (
    ID BIGSERIAL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL,
    TOKEN VARCHAR(255) NOT NULL UNIQUE,
    VERIFIED BOOLEAN DEFAULT FALSE,
    EXPIRES_AT TIMESTAMP NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_email_verifications_email ON EMAIL_VERIFICATIONS(EMAIL);
CREATE INDEX idx_email_verifications_token ON EMAIL_VERIFICATIONS(TOKEN);
```

#### SOCIAL_ACCOUNTS

```sql
CREATE TABLE SOCIAL_ACCOUNTS (
    ID BIGSERIAL PRIMARY KEY,
    USER_ID BIGINT NOT NULL REFERENCES MEMBERS(USER_ID) ON DELETE CASCADE,
    PROVIDER VARCHAR(50) NOT NULL,
    PROVIDER_ID VARCHAR(255) NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (PROVIDER, PROVIDER_ID)
);

CREATE INDEX idx_social_accounts_user_id ON SOCIAL_ACCOUNTS(USER_ID);
```

#### PASSWORD_RESET_TOKENS

```sql
CREATE TABLE PASSWORD_RESET_TOKENS (
    ID BIGSERIAL PRIMARY KEY,
    USER_ID BIGINT NOT NULL REFERENCES MEMBERS(USER_ID) ON DELETE CASCADE,
    TOKEN VARCHAR(255) NOT NULL UNIQUE,
    EXPIRES_AT TIMESTAMP NOT NULL,
    USED BOOLEAN DEFAULT FALSE,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_password_reset_tokens_token ON PASSWORD_RESET_TOKENS(TOKEN);
```

---

## 5. 보안 설계

### 5.1 비밀번호 정책

| 항목 | 설정 |
|------|------|
| 최소 길이 | 8자 |
| 특수문자 | 1개 이상 필수 |
| 암호화 | BCrypt (strength: 10) |

### 5.2 JWT 설정

| 항목 | Access Token | Refresh Token |
|------|-------------|---------------|
| 만료 시간 | 1시간 | 1일 |
| 알고리즘 | HS256 | HS256 |
| 저장 위치 | Cookie | Cookie |

### 5.3 Cookie 설정

```
HttpOnly: true
Secure: true (HTTPS 환경)
SameSite: Strict
Path: /
```

### 5.4 동시 로그인 제한

- 새로운 기기에서 로그인 시 기존 Refresh Token 삭제
- `REFRESH_TOKENS` 테이블에 `USER_ID` UNIQUE 제약으로 구현

### 5.5 MemberPrincipal (인증 사용자 정보)

인증된 사용자 정보는 Spring Security 표준에 따라 `Principal`을 통해 접근합니다.

**MemberPrincipal 클래스**
```java
public record MemberPrincipal(
    Long memberId,
    String email,
    Role role
) {}
```

**JwtAuthenticationFilter에서 설정**
```java
MemberPrincipal principal = new MemberPrincipal(memberId, email, role);
UsernamePasswordAuthenticationToken authentication =
    new UsernamePasswordAuthenticationToken(principal, null, authorities);
SecurityContextHolder.getContext().setAuthentication(authentication);
```

**@CurrentMember 커스텀 어노테이션**

`@AuthenticationPrincipal`을 직접 사용하는 대신, 커스텀 어노테이션 `@CurrentMember`를 사용합니다.

```java
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
@AuthenticationPrincipal(errorOnInvalidType = true)
@Parameter(hidden = true)  // Swagger 문서에서 숨김
public @interface CurrentMember {
}
```

**이점**
- Swagger(OpenAPI) 문서에서 자동 숨김 처리
- 타입 안전성 보장 (`errorOnInvalidType = true`)
- 도메인 친화적인 어노테이션 네이밍
- DRY 원칙 준수 (반복 어노테이션 제거)

**Controller에서 사용**
```java
@GetMapping("/me")
public ResponseEntity<?> getMyInfo(@CurrentMember MemberPrincipal member) {
    Long memberId = member.memberId();
    String email = member.email();
    Role role = member.role();
    // ...
}
```

### 5.6 JWT Payload

**Access Token**
```json
{
  "sub": "1",
  "email": "user@example.com",
  "role": "USER",
  "hasNickname": true,
  "iat": 1701763200,
  "exp": 1701766800
}
```

**Refresh Token**
```json
{
  "sub": "1",
  "iat": 1701763200,
  "exp": 1701849600
}
```

---

## 6. 에러 코드

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| AUTH001 | 400 | 이메일 형식이 올바르지 않습니다 |
| AUTH002 | 400 | 비밀번호는 8자 이상, 특수문자 1개 이상 포함해야 합니다 |
| AUTH003 | 401 | 이메일 또는 비밀번호가 일치하지 않습니다 |
| AUTH004 | 401 | 토큰이 만료되었습니다 |
| AUTH005 | 401 | 유효하지 않은 토큰입니다 |
| AUTH006 | 403 | 이메일 인증이 완료되지 않았습니다 |
| AUTH007 | 409 | 이미 가입된 이메일입니다 |
| AUTH008 | 404 | 인증 정보를 찾을 수 없습니다 |
| AUTH009 | 400 | 현재 비밀번호가 일치하지 않습니다 |
| AUTH010 | 400 | 비밀번호 재설정 토큰이 만료되었습니다 |

---

## 7. 시퀀스 다이어그램

- [회원가입/로그인 시퀀스](../../sequence/auth/signup_login_diagram.md)
- [관리자 로그인 시퀀스](../../sequence/auth/admin_login_diagram.md)
- [기관 담당자 승인 시퀀스](../../sequence/auth/admin_provider_approval_diagram.md)

---

## 8. 관련 문서

- [PRD](./prd.md)
- [Development Plan](./plan.md)
- [Implementation Report](./report.md)

---

## 9. 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 0.3 | 2025-12-14 | @CurrentMember 커스텀 어노테이션 도입 (Swagger 숨김, 타입 안전성) |
| 0.2 | 2025-12-14 | MemberPrincipal 도입 (Spring Security 표준 준수) |
| 0.1 | 2025-12-05 | 초안 작성 |
