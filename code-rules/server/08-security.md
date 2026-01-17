# 08. 보안 규칙 (Server)

## 1. 인증/인가

### 1.1 API 접근 제어
```java
// ✅ 역할 기반 접근 제어 필수
.requestMatchers("/api/v1/admin/**").hasRole("ADMIN")

// ❌ 관리자 API에 permitAll 금지
.requestMatchers("/api/v1/admin/**").permitAll()
```

### 1.2 JWT 예외 처리
- 토큰 만료(EXPIRED)와 위변조(INVALID)를 구분하여 클라이언트에 전달
- 에러 코드: `A001` (유효하지 않은 토큰), `A002` (토큰 만료)

```java
public TokenValidationResult validateTokenWithResult(String token) {
    try {
        // 토큰 검증 로직
        return TokenValidationResult.VALID;
    } catch (ExpiredJwtException e) {
        return TokenValidationResult.EXPIRED;  // A002
    } catch (JwtException e) {
        return TokenValidationResult.INVALID;  // A001
    }
}
```

---

## 2. 입력값 검증

### 2.1 길이 제한 필수
```java
// ✅ 검색어, 텍스트 입력에 길이 제한
@Size(max = 100, message = "검색어는 100자 이내로 입력해주세요")
String keyword

// ❌ 길이 제한 없는 입력값 (DoS 가능성)
String keyword
```

### 2.2 @Validated 어노테이션
`@RequestParam`에 Bean Validation 적용 시 컨트롤러에 `@Validated` 필수

```java
@RestController
@Validated  // ✅ 필수
public class MyController {

    public ResponseEntity<?> search(
            @Size(max = 100) String keyword) {  // 이제 동작함
```

---

## 3. 에러 처리

### 3.1 에러 메시지에 사용자 입력값 포함 금지
```java
// ❌ 사용자 입력값 노출
throw new IllegalArgumentException("유효하지 않은 ID: " + userInput);

// ✅ 일반적인 메시지만
throw new IllegalArgumentException("유효하지 않은 ID 형식입니다");
```

### 3.2 스택 트레이스 노출 금지
- 프로덕션 환경에서 상세 에러 정보 노출 금지
- `GlobalExceptionHandler`에서 일관된 에러 응답 형식 사용

---

## 4. 비밀번호 정책

### 4.1 필수 조건
| 조건 | 요구사항 |
|------|----------|
| 최소 길이 | 8자 이상 |
| 대문자 | 1개 이상 |
| 소문자 | 1개 이상 |
| 숫자 | 1개 이상 |
| 특수문자 | 1개 이상 (`!@#$%^&*(),.?":{}|<>`) |

### 4.2 구현 패턴
```java
private static final Pattern UPPERCASE_PATTERN = Pattern.compile("[A-Z]");
private static final Pattern LOWERCASE_PATTERN = Pattern.compile("[a-z]");
private static final Pattern DIGIT_PATTERN = Pattern.compile("[0-9]");
private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*(),.?\":{}|<>]");
```

---

## 5. 보안 설정

### 5.1 CSRF
- REST API에서는 `csrf().disable()` 허용
- 단, SameSite 쿠키 + CORS 설정 필수

### 5.2 CORS
```java
configuration.setAllowedOrigins(corsProperties.allowedOrigins());  // 명시적 origin
configuration.setAllowCredentials(true);
```

### 5.3 세션
```java
.sessionManagement(session ->
    session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
```

---

## 6. 민감 정보 관리

### 6.1 설정 파일
- `application.yml` 등 민감 정보 포함 파일은 별도 private 저장소로 관리
- `.gitignore`에 포함 확인

### 6.2 로깅
```java
// ❌ 민감 정보 로깅 금지
log.info("User password: {}", password);
log.info("Token: {}", accessToken);

// ✅ 마스킹 처리
log.info("User email: {}", maskEmail(email));
```

---

## 체크리스트

- [ ] 관리자 API에 `hasRole("ADMIN")` 적용
- [ ] JWT 에러 코드 분기 (A001, A002)
- [ ] 입력값 길이 제한 (`@Size`)
- [ ] 에러 메시지에 사용자 입력값 미포함
- [ ] 비밀번호 정책 준수 (8자, 대/소문자, 숫자, 특수문자)
- [ ] CORS 허용 origin 명시적 설정
