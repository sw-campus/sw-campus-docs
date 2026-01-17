# Security Audit Report - 2026년 1월

## 개요

SW Campus 프로젝트의 보안 점검 및 개선 작업 내역을 정리한 문서입니다.

**작업 기간**: 2026년 1월 17일
**대상**: sw-campus-server, sw-campus-client

---

## 보안 점검 결과 요약

| 우선순위 | 항목 | 상태 |
|----------|------|------|
| 🟡 중간 | 관리자 API 권한 체크 | ✅ 완료 |
| 🟡 중간 | JWT 예외 처리 세분화 | ✅ 완료 |
| 🟡 중간 | 입력값 길이 제한 | ✅ 완료 |
| 🟡 중간 | 에러 메시지 정보 노출 | ✅ 완료 |
| 🟡 중간 | Access Token localStorage 저장 | ✅ 완료 |
| 🟡 중간 | HTTP Security Headers | ✅ 완료 |
| 🟡 중간 | 비밀번호 강도 검증 | ✅ 완료 |
| 🟢 낮음 | OAuth state fallback | ✅ 완료 |
| 🟢 낮음 | 테스트 비밀번호 하드코딩 | ⬜ 해당없음 (기능 삭제 예정) |
| 🟢 낮음 | CSRF 토큰 미구현 | ⬜ 해당없음 (SameSite 쿠키로 방어) |

---

## Server 보안 개선 사항

### 1. 관리자 API 권한 체크

**파일**: `SecurityConfig.java`

**문제점**: 관리자 API(`/api/v1/admin/**`)에 역할 기반 접근 제어 미적용

**해결**:
```java
.requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
```

**커밋**: `61406b8`

---

### 2. JWT 예외 처리 세분화

**파일**: `TokenProvider.java`, `JwtAuthenticationFilter.java`, `SecurityConfig.java`

**문제점**: 토큰 만료 vs 위변조를 구분하지 않고 동일한 에러 반환

**해결**:

1. `TokenValidationResult` enum 추가:
```java
public enum TokenValidationResult {
    VALID,    // 유효한 토큰
    EXPIRED,  // 만료된 토큰 (A002)
    INVALID   // 위변조/잘못된 형식 (A001)
}
```

2. `TokenProvider.validateTokenWithResult()` 메서드 추가:
```java
public TokenValidationResult validateTokenWithResult(String token) {
    try {
        Jwts.parser().verifyWith(secretKey).build().parseSignedClaims(token);
        return TokenValidationResult.VALID;
    } catch (ExpiredJwtException e) {
        return TokenValidationResult.EXPIRED;
    } catch (JwtException | IllegalArgumentException e) {
        return TokenValidationResult.INVALID;
    }
}
```

3. `AuthenticationEntryPoint`에서 에러 코드 분기:
```java
if (validationResult == TokenValidationResult.EXPIRED) {
    responseBody = "{\"code\": \"A002\", \"message\": \"토큰이 만료되었습니다\"}";
} else if (validationResult == TokenValidationResult.INVALID) {
    responseBody = "{\"code\": \"A001\", \"message\": \"유효하지 않은 토큰입니다\"}";
}
```

**커밋**: `7c5fb8d`

---

### 3. 입력값 길이 제한

**파일**: `AuthController.java`

**문제점**: `keyword` 파라미터에 길이 제한 없음 (DoS 가능성)

**해결**:
```java
@Validated  // 클래스 레벨에 추가
public class AuthController {

    public ResponseEntity<List<OrganizationSearchResponse>> searchOrganizations(
            @RequestParam(name = "keyword", required = false, defaultValue = "")
            @Size(max = 100, message = "검색어는 100자 이내로 입력해주세요")
            String keyword) {
```

**주의사항**: `@RequestParam`의 Bean Validation은 `@Validated` 어노테이션이 컨트롤러 클래스에 있어야 동작

**커밋**: `ba01a02`

---

### 4. 에러 메시지 정보 노출 방지

**파일**: `AuthController.java`

**문제점**: 에러 메시지에 사용자 입력값 포함
```java
// Before
throw new IllegalArgumentException("유효하지 않은 기관 ID 형식입니다: " + organizationIdStr);
```

**해결**:
```java
// After
throw new IllegalArgumentException("유효하지 않은 기관 ID 형식입니다");
```

**커밋**: `ba01a02`

---

### 5. 비밀번호 강도 검증 강화

**파일**: `PasswordValidator.java`

**문제점**: 비밀번호 검증 조건 부족 (8자 이상 + 특수문자만)

**해결**:
```java
private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*(),.?\":{}|<>]");

public void validate(String password) {
    if (password == null || password.length() < MIN_LENGTH) {
        throw new InvalidPasswordException("비밀번호는 8자 이상이어야 합니다");
    }
    if (!UPPERCASE_PATTERN.matcher(password).find()) {
        throw new InvalidPasswordException("비밀번호에 대문자가 1개 이상 포함되어야 합니다");
    }
    if (!LOWERCASE_PATTERN.matcher(password).find()) {
        throw new InvalidPasswordException("비밀번호에 소문자가 1개 이상 포함되어야 합니다");
    }
    if (!DIGIT_PATTERN.matcher(password).find()) {
        throw new InvalidPasswordException("비밀번호에 숫자가 1개 이상 포함되어야 합니다");
    }
    if (!SPECIAL_CHAR_PATTERN.matcher(password).find()) {
        throw new InvalidPasswordException("비밀번호에 특수문자가 1개 이상 포함되어야 합니다");
    }
}
```

**커밋**: `7de2393`

---

## Client 보안 개선 사항

### 1. Access Token localStorage 저장 제거

**파일**: `authStore.ts`

**문제점**: accessToken이 localStorage에 저장되어 XSS 공격 시 탈취 가능

**해결**: Zustand persist의 `partialize` 옵션으로 accessToken 제외
```typescript
{
  name: 'auth-storage',
  partialize: state => ({
    isLoggedIn: state.isLoggedIn,
    userName: state.userName,
    nickname: state.nickname,
    userType: state.userType,
    // accessToken은 메모리에만 유지, localStorage에 저장 안 함
  }),
}
```

**동작 방식**: 페이지 새로고침 시 httpOnly refresh cookie로 자동 갱신

**커밋**: `55193aa`

---

### 2. HTTP Security Headers 추가

**파일**: `next.config.ts`

**문제점**: 보안 헤더 미설정

**해결**:
```typescript
async headers() {
  return [
    {
      source: '/(.*)',
      headers: [
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        { key: 'X-DNS-Prefetch-Control', value: 'on' },
      ],
    },
  ]
}
```

| 헤더 | 효과 |
|------|------|
| X-Frame-Options: DENY | 클릭재킹 방지 |
| X-Content-Type-Options: nosniff | MIME 스니핑 방지 |
| Referrer-Policy | 리퍼러 정보 제한 |
| Permissions-Policy | 불필요한 브라우저 API 차단 |

**커밋**: `55193aa`

---

### 3. 비밀번호 강도 검증 (클라이언트)

**파일**: `authApi.ts`

**해결**: 서버와 동일한 검증 규칙 적용
```typescript
password: z
  .string()
  .min(8, '비밀번호는 8자 이상이어야 합니다.')
  .regex(/[A-Z]/, '비밀번호에 대문자가 1개 이상 포함되어야 합니다.')
  .regex(/[a-z]/, '비밀번호에 소문자가 1개 이상 포함되어야 합니다.')
  .regex(/[0-9]/, '비밀번호에 숫자가 1개 이상 포함되어야 합니다.')
  .regex(/[!@#$%^&*(),.?":{}|<>]/, '비밀번호에 특수문자가 1개 이상 포함되어야 합니다.')
```

**중요**: 클라이언트-서버 간 검증 규칙 일관성 유지 필수

**커밋**: `55193aa`

---

### 4. OAuth State 암호학적 난수 생성

**파일**: `useOAuthUrls.ts`

**문제점**: `Math.random()` 사용 (암호학적으로 안전하지 않음)

**해결**:
```typescript
const cryptoObj = globalThis.crypto
if (cryptoObj?.randomUUID) {
  // 최신 브라우저: crypto.randomUUID() 사용
  state = cryptoObj.randomUUID().replace(/-/g, '')
} else if (cryptoObj?.getRandomValues) {
  // 구형 브라우저 fallback: crypto.getRandomValues() 사용
  const array = new Uint8Array(16)
  cryptoObj.getRandomValues(array)
  state = Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('')
} else {
  console.warn('crypto API not available')
  return null
}
```

**커밋**: `ba3a56b`, `b9aead2`

---

## 해당 없음 처리 항목

### CSRF 토큰

**사유**: 다음 메커니즘으로 충분히 방어됨
- SameSite 쿠키 사용
- CORS 설정으로 허용된 origin만 API 호출 가능
- JWT httpOnly 쿠키 사용
- REST API (application/json)

### 테스트 비밀번호 하드코딩

**사유**: test-data 기능 deprecated/삭제 예정

---

## 커밋 히스토리

### Server (sw-campus-server/develop)
```
7de2393 fix(security): 비밀번호 검증 강화 - 대문자/소문자/숫자 필수 조건 추가
ba01a02 fix(security): 입력값 길이 제한 및 에러 메시지 정보 노출 수정
7c5fb8d fix(security): JWT 예외 처리 세분화 및 공개 API 인증 정보 유지 (#428)
61406b8 fix(security): 관리자 API에 ADMIN 역할 기반 접근 제어 추가
```

### Client (sw-campus-client/develop)
```
b9aead2 fix(security): OAuth state TypeScript 타입 오류 수정
ba3a56b fix(security): OAuth state 생성 시 Math.random() 제거
55193aa fix(security): 클라이언트 보안 강화
```

---

## 향후 고려사항

1. **CSP (Content-Security-Policy)**: 현재 미적용. 적용 시 inline script/style 수정 필요
2. **Rate Limiting**: API 호출 빈도 제한 고려
3. **보안 헤더 모니터링**: securityheaders.com 등으로 정기 점검
4. **의존성 취약점 스캔**: npm audit, OWASP Dependency-Check 정기 실행
