# Phase 07: 로그인/로그아웃 - 완료 보고서

> **완료일**: 2025-12-08  
> **소요 시간**: 약 1.5시간  
> **브랜치**: `28-sign-up-for-organization` (Phase 06과 함께 작업)

---

## 1. 구현 요약

### 1.1 완료된 기능
- ✅ 이메일/비밀번호 로그인 API
- ✅ 로그아웃 API
- ✅ JWT Access Token, Refresh Token 발급 (HttpOnly Cookie)
- ✅ Refresh Token DB 저장
- ✅ 동시 로그인 제한 (기존 Refresh Token 삭제)
- ✅ 기관 회원 로그인 시 Organization 정보 (approvalStatus) 포함

### 1.2 API 엔드포인트

| Method | Endpoint | 설명 | 응답 |
|--------|----------|------|------|
| POST | `/api/v1/auth/login` | 로그인 | 200 OK + Set-Cookie |
| POST | `/api/v1/auth/logout` | 로그아웃 | 200 OK + Cookie 삭제 |

---

## 2. 파일 변경 내역

### 2.1 신규 생성 파일

| 파일 | 위치 | 설명 |
|------|------|------|
| `InvalidCredentialsException.java` | domain/auth/exception | 인증 실패 예외 |
| `LoginResult.java` | domain/auth | 로그인 결과 객체 |
| `LoginRequest.java` | api/auth/request | 로그인 요청 DTO |
| `LoginResponse.java` | api/auth/response | 로그인 응답 DTO |
| `AuthServiceLoginTest.java` | domain/test | 로그인/로그아웃 단위 테스트 |
| `AuthControllerLoginTest.java` | api/test | 컨트롤러 통합 테스트 |

### 2.2 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `AuthService.java` | `login()`, `logout()` 메서드 추가 |
| `AuthController.java` | `/login`, `/logout` 엔드포인트 추가, `TokenProvider`, `CookieUtil` 의존성 추가 |
| `GlobalExceptionHandler.java` | `InvalidCredentialsException` 핸들러 추가 |
| `AuthControllerEmailTest.java` | Mock 의존성 추가 (`TokenProvider`, `CookieUtil`) |
| `AuthControllerSignupTest.java` | Mock 의존성 추가 (`TokenProvider`, `CookieUtil`) |

---

## 3. 주요 구현 내용

### 3.1 로그인 플로우

```
1. 이메일로 회원 조회
2. 비밀번호 검증 (BCrypt)
3. 기존 Refresh Token 삭제 (동시 로그인 제한)
4. Access Token, Refresh Token 생성
5. Refresh Token DB 저장
6. ORGANIZATION 역할인 경우 Organization 정보 조회
7. Cookie로 토큰 반환 + JSON 응답
```

### 3.2 로그아웃 플로우

```
1. Cookie에서 Access Token 추출
2. 토큰 유효성 검증
3. 유효한 경우 Refresh Token DB에서 삭제
4. Cookie 삭제 (maxAge=0)
```

### 3.3 LoginResponse 구조

```json
// 일반 회원
{
  "userId": 1,
  "email": "user@example.com",
  "name": "홍길동",
  "nickname": "길동이",
  "role": "USER"
}

// 기관 회원
{
  "userId": 1,
  "email": "org@example.com",
  "name": "김기관",
  "nickname": "기관담당자",
  "role": "ORGANIZATION",
  "organizationId": 10,
  "organizationName": "테스트교육기관",
  "approvalStatus": "PENDING"
}
```

---

## 4. 설계 결정 사항

### 4.1 Organization 정보 포함
- **이유**: Phase 06에서 `orgAuth` 필드가 `Organization.approvalStatus`로 이동됨
- **해결**: `LoginResult`에 `Organization` 객체를 optional로 포함
- **효과**: 프론트엔드에서 기관 승인 상태 확인 가능

### 4.2 동시 로그인 제한
- **방식**: 로그인 시 기존 Refresh Token 삭제
- **효과**: 하나의 계정에 하나의 활성 세션만 유지

### 4.3 로그아웃 안전성
- **정책**: 토큰이 없거나 유효하지 않아도 200 OK 반환
- **이유**: 클라이언트 상태와 관계없이 Cookie 삭제 보장

### 4.4 네이밍 일관성
- Plan 문서의 `deleteByUserId` → `deleteByMemberId`로 변경
- 기존 코드베이스와 일관성 유지

---

## 5. 테스트 결과

### 5.1 단위 테스트 (AuthServiceLoginTest)
- `loginUser()` - 일반 회원 로그인 성공 ✅
- `loginOrganization()` - 기관 회원 로그인 성공 (Organization 정보 포함) ✅
- `loginEmailNotFound()` - 존재하지 않는 이메일 ✅
- `loginWrongPassword()` - 비밀번호 불일치 ✅
- `loginDeletesExistingRefreshToken()` - 동시 로그인 제한 ✅
- `logout()` - 로그아웃 ✅

### 5.2 통합 테스트 (AuthControllerLoginTest)
- 일반 회원 로그인 성공 ✅
- 기관 회원 로그인 성공 - Organization 정보 포함 ✅
- 로그인 실패 - 잘못된 자격 증명 ✅
- 로그인 실패 - 이메일 형식 오류 ✅
- 로그인 실패 - 비밀번호 누락 ✅
- 로그아웃 성공 ✅
- 로그아웃 성공 - 토큰 없이도 성공 ✅

### 5.3 전체 테스트
```bash
./gradlew test
BUILD SUCCESSFUL - 31 tests passed
```

---

## 6. API 테스트 예시

### 6.1 로그인
```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "Password1!"
  }' \
  -c cookies.txt \
  -v
```

**응답 헤더:**
```
Set-Cookie: accessToken=eyJ...; Path=/; HttpOnly; Secure; SameSite=Strict
Set-Cookie: refreshToken=eyJ...; Path=/; HttpOnly; Secure; SameSite=Strict
```

### 6.2 로그아웃
```bash
curl -X POST http://localhost:8080/api/v1/auth/logout \
  -b cookies.txt \
  -v
```

---

## 7. 다음 단계

### Phase 08: 토큰 갱신
- `POST /api/v1/auth/refresh` - Refresh Token으로 Access Token 갱신
- Refresh Token Rotation 적용 검토

---

## 8. 참고 사항

### 8.1 테스트 환경 설정
- `@AutoConfigureMockMvc(addFilters = false)` - Security 필터 비활성화
- `@ActiveProfiles("test")` - 테스트 프로파일 사용
- CSRF 비활성화 - SPA 프론트엔드와 분리된 구조

### 8.2 관련 문서
- Plan: `/sw-campus-docs/features/auth/plan/phase07-login.md`
- CONTEXT: `/sw-campus-docs/features/auth/CONTEXT.md` (업데이트 필요)
