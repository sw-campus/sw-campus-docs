# Phase 10: OAuth 소셜 로그인 - 완료 보고서

> 완료일: 2025-12-09

## 1. 개요

Google, GitHub 소셜 로그인 기능을 구현했습니다. 신규 사용자는 랜덤 닉네임이 자동 생성되며, 기존 이메일 계정과의 연동도 지원합니다.

---

## 2. 완료 항목

| 항목 | 상태 | 비고 |
|------|------|------|
| SocialAccount 도메인 구현 | ✅ | 소셜 계정 엔티티 |
| OAuth2 Client 설정 (Google) | ✅ | `GoogleOAuthClient` |
| OAuth2 Client 설정 (GitHub) | ✅ | `GitHubOAuthClient` |
| 소셜 로그인 API 구현 | ✅ | `POST /api/v1/auth/oauth/{provider}` |
| 랜덤 닉네임 자동 생성 | ✅ | "사용자_" + UUID 8자리 |
| 기존 회원 연동 처리 | ✅ | 이메일 기반 자동 연동 |
| URL 인코딩 code 디코딩 처리 | ✅ | `URLDecoder` 적용 |
| 단위 테스트 | ✅ | 5개 테스트 케이스 |
| 통합 테스트 | ✅ | 4개 테스트 케이스 |
| Postman 컬렉션 | ✅ | OAuth 테스트 컬렉션 |

---

## 3. 구현 상세

### 3.1 API 엔드포인트

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/oauth/{provider}` | 소셜 로그인 (Google/GitHub) | 불필요 |

### 3.2 OAuth 로그인 프로세스

```
1. 클라이언트에서 Authorization Code 전송
2. URL 인코딩된 code 디코딩 처리
3. OAuth Provider에 Access Token 요청
4. OAuth Provider에서 사용자 정보 조회
5. 소셜 계정 존재 여부 확인
   - 있으면: 기존 회원으로 로그인
   - 없으면:
     - 이메일로 기존 회원 조회
       - 있으면: 소셜 계정 연동
       - 없으면: 신규 회원 생성 (랜덤 닉네임)
6. JWT 토큰 발급 (Access + Refresh)
7. 쿠키로 토큰 반환
```

### 3.3 지원 OAuth Provider

| Provider | Client ID 설정 | 사용자 정보 |
|----------|---------------|------------|
| Google | `oauth.google.client-id` | email, name, id |
| GitHub | `oauth.github.client-id` | email (별도 API), name, id |

### 3.4 랜덤 닉네임 생성

```java
// Member.createOAuthUser() 내부
String randomSuffix = UUID.randomUUID().toString().substring(0, 8);
this.nickname = "사용자_" + randomSuffix;
// 예: "사용자_a1b2c3d4"
```

---

## 4. 생성/수정 파일

### 4.1 Domain 모듈 (`sw-campus-domain`)

| 파일 | 변경 | 설명 |
|------|------|------|
| `OAuthProvider.java` | 생성 | OAuth 제공자 enum (GOOGLE, GITHUB) |
| `OAuthUserInfo.java` | 생성 | OAuth 사용자 정보 DTO |
| `OAuthClient.java` | 생성 | OAuth 클라이언트 인터페이스 |
| `OAuthClientFactory.java` | 생성 | OAuth 클라이언트 팩토리 인터페이스 |
| `OAuthLoginResult.java` | 생성 | 로그인 결과 DTO |
| `SocialAccount.java` | 생성 | 소셜 계정 도메인 |
| `SocialAccountRepository.java` | 생성 | Repository 인터페이스 |
| `OAuthService.java` | 생성 | OAuth 비즈니스 로직 |
| `Member.java` | 수정 | `createOAuthUser()` 메서드 추가 |

### 4.2 Infra - DB 모듈 (`sw-campus-infra/db-postgres`)

| 파일 | 변경 | 설명 |
|------|------|------|
| `SocialAccountEntity.java` | 생성 | JPA Entity |
| `SocialAccountJpaRepository.java` | 생성 | JPA Repository |
| `SocialAccountEntityRepository.java` | 생성 | Repository 구현체 |

### 4.3 Infra - OAuth 모듈 (`sw-campus-infra/oauth`)

| 파일 | 변경 | 설명 |
|------|------|------|
| `GoogleOAuthClient.java` | 생성 | Google OAuth 클라이언트 |
| `GitHubOAuthClient.java` | 생성 | GitHub OAuth 클라이언트 |
| `OAuthClientFactoryImpl.java` | 생성 | 팩토리 구현체 |
| `OAuthConfig.java` | 생성 | RestTemplate Bean 설정 |

### 4.4 API 모듈 (`sw-campus-api`)

| 파일 | 변경 | 설명 |
|------|------|------|
| `OAuthController.java` | 생성 | OAuth API 컨트롤러 |
| `OAuthCallbackRequest.java` | 생성 | 요청 DTO |
| `OAuthLoginResponse.java` | 생성 | 응답 DTO |

### 4.5 테스트

| 파일 | 변경 | 설명 |
|------|------|------|
| `SocialAccountTest.java` | 생성 | 도메인 단위 테스트 (2개) |
| `OAuthServiceTest.java` | 생성 | 서비스 단위 테스트 (3개) |
| `OAuthControllerTest.java` | 생성 | 컨트롤러 통합 테스트 (4개) |

### 4.6 Postman

| 파일 | 변경 | 설명 |
|------|------|------|
| `SW_Campus_OAuth.postman_collection.json` | 생성 | OAuth 테스트 컬렉션 |

---

## 5. 테스트 결과

### 5.1 단위 테스트 (SocialAccountTest)

| 테스트 | 결과 |
|--------|------|
| 소셜 계정을 생성할 수 있다 | ✅ |
| of 메서드로 소셜 계정을 복원할 수 있다 | ✅ |

### 5.2 단위 테스트 (OAuthServiceTest)

| 테스트 | 결과 |
|--------|------|
| 기존 소셜 계정으로 로그인한다 | ✅ |
| 신규 소셜 사용자를 등록한다 - 랜덤 닉네임 자동 생성 | ✅ |
| 이미 가입된 이메일에 소셜 계정을 연동한다 | ✅ |

### 5.3 통합 테스트 (OAuthControllerTest)

| 테스트 | 결과 |
|--------|------|
| Google 로그인 성공 | ✅ |
| GitHub 로그인 성공 | ✅ |
| 인증 코드가 비어있으면 400 에러 | ✅ |
| 지원하지 않는 provider면 500 에러 | ✅ |

### 5.4 수동 테스트 (Postman)

| 테스트 | 결과 |
|--------|------|
| Google OAuth 로그인 - 신규 사용자 | ✅ |
| Google OAuth 로그인 - 기존 사용자 | ✅ |
| DB에 Member, SocialAccount 저장 확인 | ✅ |
| JWT 토큰 쿠키 반환 확인 | ✅ |

---

## 6. 코드 품질

### 6.1 네이밍 컨벤션 준수

- ✅ `OAuthController` - Controller 네이밍
- ✅ `OAuthService.loginOrRegister()` - Service 메서드명
- ✅ `SocialAccountRepository` - Repository 인터페이스 (domain)
- ✅ `SocialAccountEntityRepository` - Repository 구현체 (infra)
- ✅ `OAuthCallbackRequest`, `OAuthLoginResponse` - DTO 네이밍

### 6.2 레이어 분리

- ✅ Controller: HTTP 요청/응답, 쿠키 처리
- ✅ Service: 비즈니스 로직 (로그인/회원가입 분기)
- ✅ Repository: 인터페이스(domain) + 구현체(infra) 분리
- ✅ OAuthClient: 인터페이스(domain) + 구현체(infra/oauth) 분리

### 6.3 의존성 방향

```
api → domain ← infra/db-postgres
         ↑
    infra/oauth
```

- ✅ domain 모듈에 인터페이스 정의
- ✅ infra 모듈에서 구현체 제공
- ✅ api에서 infra 직접 import 없음

---

## 7. 응답 예시

### 7.1 성공 응답

```json
{
  "memberId": 1,
  "email": "user@gmail.com",
  "name": "홍길동",
  "nickname": "사용자_a1b2c3d4",
  "role": "USER"
}
```

### 7.2 응답 헤더 (쿠키)

```
Set-Cookie: accessToken=eyJ...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=3600
Set-Cookie: refreshToken=eyJ...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=86400
```

---

## 8. 구현 시 발생한 이슈 및 해결

### 8.1 `-parameters` 컴파일러 플래그 누락

**문제**: `@PathVariable String provider`에서 파라미터 이름을 인식하지 못함

**해결**:
1. `@PathVariable("provider")` 명시적 이름 지정
2. `build.gradle`에 `-parameters` 플래그 추가

```gradle
tasks.withType(JavaCompile).configureEach {
    options.compilerArgs.add('-parameters')
}
```

### 8.2 URL 인코딩된 Authorization Code

**문제**: 브라우저에서 복사한 code에 `%2F` 등 URL 인코딩 문자 포함

**해결**: OAuth Client에서 `URLDecoder.decode()` 처리 추가

```java
String decodedCode = URLDecoder.decode(code, StandardCharsets.UTF_8);
```

---

## 9. 관련 User Stories 완료

| US | 설명 | 상태 |
|----|------|------|
| US-20 | Google 계정으로 로그인/회원가입 | ✅ |
| US-21 | GitHub 계정으로 로그인/회원가입 | ✅ |
| US-22 | 소셜 로그인 시 랜덤 닉네임 자동 생성 | ✅ |
| US-23 | 기존 이메일 계정과 소셜 계정 연동 | ✅ |

---

## 10. 다음 단계

→ [Phase 11: 통합 테스트](../plan/phase11-integration.md)
