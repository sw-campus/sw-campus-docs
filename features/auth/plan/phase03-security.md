# Phase 03: Security + JWT

> 예상 시간: 2시간

## 1. 목표

Spring Security 설정과 JWT 토큰 Provider를 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] Security 설정 완료 (Filter Chain)
- [ ] TokenProvider 구현 (Access/Refresh Token 생성/검증)
- [ ] JwtAuthenticationFilter 구현
- [ ] Cookie 유틸리티 구현
- [ ] 단위 테스트 통과
- [ ] 테스트 커버리지 95% 이상

---

## 3. 관련 User Stories

- US-15: Access Token 만료 시 자동 갱신
- US-16: Refresh Token 만료 시 재로그인
- US-17: 동시 로그인 제한

---

## 4. 파일 구조

```
sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── config/
        ├── SecurityConfig.java
        ├── CorsConfig.java
        └── CookieUtil.java
    └── security/
        └── JwtAuthenticationFilter.java

sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── auth/
        ├── TokenProvider.java
        ├── TokenInfo.java
        ├── RefreshToken.java              ✅ Phase 02 완료
        ├── RefreshTokenRepository.java    ✅ Phase 02 완료
        └── exception/
            ├── TokenExpiredException.java
            └── InvalidTokenException.java

sw-campus-infra/db-postgres/
└── src/main/java/com/swcampus/infra/postgres/
    └── auth/
        ├── RefreshTokenEntity.java        ✅ Phase 02 완료
        ├── RefreshTokenJpaRepository.java ✅ Phase 02 완료
        └── RefreshTokenRepositoryImpl.java ✅ Phase 02 완료
```

> ✅ **Phase 02에서 완료된 항목**: RefreshToken 도메인/인프라는 이미 구현됨

---

## 5. TDD Tasks

### 5.1 Red: 테스트 작성

**TokenProviderTest.java**
```java
@DisplayName("TokenProvider 테스트")
class TokenProviderTest {

    private TokenProvider tokenProvider;

    @BeforeEach
    void setUp() {
        String secret = "test-secret-key-for-testing-purpose-only-32bytes";
        long accessTokenValidity = 3600L;  // 1시간
        long refreshTokenValidity = 86400L; // 1일
        tokenProvider = new TokenProvider(secret, accessTokenValidity, refreshTokenValidity);
    }

    @Test
    @DisplayName("Access Token을 생성할 수 있다")
    void createAccessToken() {
        // given
        Long userId = 1L;
        String email = "user@example.com";
        Role role = Role.USER;

        // when
        String token = tokenProvider.createAccessToken(userId, email, role);

        // then
        assertThat(token).isNotBlank();
        assertThat(tokenProvider.validateToken(token)).isTrue();
    }

    @Test
    @DisplayName("Refresh Token을 생성할 수 있다")
    void createRefreshToken() {
        // given
        Long userId = 1L;

        // when
        String token = tokenProvider.createRefreshToken(userId);

        // then
        assertThat(token).isNotBlank();
        assertThat(tokenProvider.validateToken(token)).isTrue();
    }

    @Test
    @DisplayName("토큰에서 사용자 ID를 추출할 수 있다")
    void getUserIdFromToken() {
        // given
        Long userId = 1L;
        String token = tokenProvider.createAccessToken(userId, "user@example.com", Role.USER);

        // when
        Long extractedUserId = tokenProvider.getUserId(token);

        // then
        assertThat(extractedUserId).isEqualTo(userId);
    }

    @Test
    @DisplayName("만료된 토큰은 검증에 실패한다")
    void validateExpiredToken() {
        // given
        TokenProvider shortLivedProvider = new TokenProvider(
            "test-secret-key-for-testing-purpose-only-32bytes", 
            0L,  // 즉시 만료
            0L
        );
        String token = shortLivedProvider.createAccessToken(1L, "user@example.com", Role.USER);

        // when & then
        assertThat(tokenProvider.validateToken(token)).isFalse();
    }

    @Test
    @DisplayName("잘못된 토큰은 검증에 실패한다")
    void validateInvalidToken() {
        // given
        String invalidToken = "invalid.token.here";

        // when & then
        assertThat(tokenProvider.validateToken(invalidToken)).isFalse();
    }
}
```

> ✅ **RefreshTokenRepositoryTest.java** - Phase 02에서 완료됨 (RefreshTokenRepositoryTest 참조)

### 5.2 Green: 구현

**TokenInfo.java**
```java
@Getter
@AllArgsConstructor
public class TokenInfo {
    private final String accessToken;
    private final String refreshToken;
}
```

**TokenProvider.java**
```java
@Component
public class TokenProvider {

    private final SecretKey secretKey;
    private final long accessTokenValidity;
    private final long refreshTokenValidity;

    public TokenProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-token-validity}") long accessTokenValidity,
            @Value("${jwt.refresh-token-validity}") long refreshTokenValidity) {
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenValidity = accessTokenValidity * 1000;
        this.refreshTokenValidity = refreshTokenValidity * 1000;
    }

    public String createAccessToken(Long userId, String email, Role role) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + accessTokenValidity);

        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("email", email)
                .claim("role", role.name())
                .issuedAt(now)
                .expiration(expiry)
                .signWith(secretKey)
                .compact();
    }

    public String createRefreshToken(Long userId) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + refreshTokenValidity);

        return Jwts.builder()
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(expiry)
                .signWith(secretKey)
                .compact();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public Long getUserId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return Long.parseLong(claims.getSubject());
    }

    public String getEmail(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return claims.get("email", String.class);
    }

    public Role getRole(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return Role.valueOf(claims.get("role", String.class));
    }

    public long getAccessTokenValidity() {
        return accessTokenValidity / 1000;
    }

    public long getRefreshTokenValidity() {
        return refreshTokenValidity / 1000;
    }
}
```

> ✅ **RefreshToken.java, RefreshTokenRepository.java** - Phase 02에서 완료됨
> - `sw-campus-domain/src/main/java/com/swcampus/domain/auth/RefreshToken.java`
> - `sw-campus-domain/src/main/java/com/swcampus/domain/auth/RefreshTokenRepository.java`

**SecurityConfig.java**
```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final TokenProvider tokenProvider;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> 
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // 인증 없이 접근 가능
                .requestMatchers(
                    "/api/v1/auth/**",
                    "/api/v1/health"
                ).permitAll()
                // 나머지는 인증 필요
                .anyRequest().authenticated()
            )
            .addFilterBefore(
                new JwtAuthenticationFilter(tokenProvider),
                UsernamePasswordAuthenticationFilter.class
            );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(10);
    }
}
```

**JwtAuthenticationFilter.java**
```java
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final TokenProvider tokenProvider;

    @Override
    protected void doFilterInternal(HttpServletRequest request, 
            HttpServletResponse response, FilterChain filterChain) 
            throws ServletException, IOException {
        
        String token = resolveToken(request);

        if (token != null && tokenProvider.validateToken(token)) {
            Long userId = tokenProvider.getUserId(token);
            String email = tokenProvider.getEmail(token);
            Role role = tokenProvider.getRole(token);

            UserDetails userDetails = User.builder()
                    .username(email)
                    .password("")
                    .roles(role.name())
                    .build();

            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities());
            
            authentication.setDetails(userId);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }

        filterChain.doFilter(request, response);
    }

    private String resolveToken(HttpServletRequest request) {
        // Cookie에서 토큰 추출
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("accessToken".equals(cookie.getName())) {
                    return cookie.getValue();
                }
            }
        }
        return null;
    }
}
```

**CookieUtil.java**
```java
@Component
public class CookieUtil {

    public ResponseCookie createAccessTokenCookie(String token, long maxAge) {
        return ResponseCookie.from("accessToken", token)
                .httpOnly(true)
                .secure(true)
                .sameSite("Strict")
                .path("/")
                .maxAge(maxAge)
                .build();
    }

    public ResponseCookie createRefreshTokenCookie(String token, long maxAge) {
        return ResponseCookie.from("refreshToken", token)
                .httpOnly(true)
                .secure(true)
                .sameSite("Strict")
                .path("/")
                .maxAge(maxAge)
                .build();
    }

    public ResponseCookie deleteAccessTokenCookie() {
        return ResponseCookie.from("accessToken", "")
                .httpOnly(true)
                .secure(true)
                .sameSite("Strict")
                .path("/")
                .maxAge(0)
                .build();
    }

    public ResponseCookie deleteRefreshTokenCookie() {
        return ResponseCookie.from("refreshToken", "")
                .httpOnly(true)
                .secure(true)
                .sameSite("Strict")
                .path("/")
                .maxAge(0)
                .build();
    }
}
```

---

## 6. 예외 클래스

**TokenExpiredException.java**
```java
public class TokenExpiredException extends RuntimeException {
    public TokenExpiredException() {
        super("토큰이 만료되었습니다");
    }
}
```

**InvalidTokenException.java**
```java
public class InvalidTokenException extends RuntimeException {
    public InvalidTokenException() {
        super("유효하지 않은 토큰입니다");
    }
}
```

---

## 7. 검증

```bash
# 테스트 실행
./gradlew test --tests "*TokenProviderTest*"
./gradlew test --tests "*RefreshTokenRepositoryTest*"

# 애플리케이션 실행 후 Security 동작 확인
curl -X GET http://localhost:8080/api/v1/health  # 200 OK
curl -X GET http://localhost:8080/api/v1/members # 401 Unauthorized
```

---

## 8. 산출물

| 파일 | 위치 | 설명 | 상태 |
|------|------|------|------|
| `TokenProvider.java` | domain | JWT 토큰 생성/검증 | 구현 예정 |
| `TokenInfo.java` | domain | 토큰 정보 DTO | 구현 예정 |
| `RefreshToken.java` | domain | Refresh Token 도메인 | ✅ Phase 02 완료 |
| `RefreshTokenRepository.java` | domain | Repository 인터페이스 | ✅ Phase 02 완료 |
| `RefreshTokenEntity.java` | infra | JPA Entity | ✅ Phase 02 완료 |
| `RefreshTokenJpaRepository.java` | infra | JPA Repository | ✅ Phase 02 완료 |
| `RefreshTokenRepositoryImpl.java` | infra | Repository 구현체 | ✅ Phase 02 완료 |
| `SecurityConfig.java` | api | Security 설정 | 구현 예정 |
| `JwtAuthenticationFilter.java` | api | JWT 인증 필터 | 구현 예정 |
| `CookieUtil.java` | api | Cookie 유틸리티 | 구현 예정 |

---

## 9. 다음 Phase

→ [Phase 04: 이메일 인증](./phase04-email.md)
