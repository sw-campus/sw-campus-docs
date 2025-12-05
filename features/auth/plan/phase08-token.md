# Phase 08: 토큰 갱신

> 예상 시간: 1시간

## 1. 목표

Refresh Token을 사용한 Access Token 갱신 기능을 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] 토큰 갱신 API 구현
- [ ] Refresh Token 유효성 검증
- [ ] 새 Access Token 발급
- [ ] 만료된 Refresh Token 처리
- [ ] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-15 | Access Token 만료 시 자동 갱신 |
| US-16 | Refresh Token 만료 시 재로그인 |
| US-17 | 동시 로그인 제한 |

---

## 4. API 명세

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/v1/auth/refresh` | Access Token 갱신 |

---

## 5. TDD Tasks

### 5.1 Red: 테스트 작성

**AuthServiceRefreshTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService - 토큰 갱신 테스트")
class AuthServiceRefreshTest {

    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private RefreshTokenRepository refreshTokenRepository;
    
    @Mock
    private TokenProvider tokenProvider;

    @InjectMocks
    private AuthService authService;

    @Test
    @DisplayName("토큰 갱신에 성공한다")
    void refresh() {
        // given
        String refreshToken = "valid-refresh-token";
        Long userId = 1L;
        
        RefreshToken storedToken = mock(RefreshToken.class);
        when(storedToken.getUserId()).thenReturn(userId);
        when(storedToken.getToken()).thenReturn(refreshToken);
        when(storedToken.isExpired()).thenReturn(false);

        Member member = mock(Member.class);
        when(member.getId()).thenReturn(userId);
        when(member.getEmail()).thenReturn("user@example.com");
        when(member.getRole()).thenReturn(Role.USER);

        when(tokenProvider.validateToken(refreshToken)).thenReturn(true);
        when(tokenProvider.getUserId(refreshToken)).thenReturn(userId);
        when(refreshTokenRepository.findByUserId(userId)).thenReturn(Optional.of(storedToken));
        when(memberRepository.findById(userId)).thenReturn(Optional.of(member));
        when(tokenProvider.createAccessToken(userId, "user@example.com", Role.USER))
            .thenReturn("new-access-token");

        // when
        String newAccessToken = authService.refresh(refreshToken);

        // then
        assertThat(newAccessToken).isEqualTo("new-access-token");
    }

    @Test
    @DisplayName("유효하지 않은 Refresh Token으로 갱신 시 실패한다")
    void refresh_invalidToken() {
        // given
        String refreshToken = "invalid-token";
        when(tokenProvider.validateToken(refreshToken)).thenReturn(false);

        // when & then
        assertThatThrownBy(() -> authService.refresh(refreshToken))
            .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    @DisplayName("DB에 없는 Refresh Token으로 갱신 시 실패한다")
    void refresh_tokenNotInDb() {
        // given
        String refreshToken = "valid-but-not-in-db";
        Long userId = 1L;
        
        when(tokenProvider.validateToken(refreshToken)).thenReturn(true);
        when(tokenProvider.getUserId(refreshToken)).thenReturn(userId);
        when(refreshTokenRepository.findByUserId(userId)).thenReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> authService.refresh(refreshToken))
            .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    @DisplayName("토큰 값이 일치하지 않으면 갱신 실패 (다른 기기에서 로그인)")
    void refresh_tokenMismatch() {
        // given
        String refreshToken = "old-refresh-token";
        Long userId = 1L;
        
        RefreshToken storedToken = mock(RefreshToken.class);
        when(storedToken.getToken()).thenReturn("new-refresh-token");  // 다른 토큰

        when(tokenProvider.validateToken(refreshToken)).thenReturn(true);
        when(tokenProvider.getUserId(refreshToken)).thenReturn(userId);
        when(refreshTokenRepository.findByUserId(userId)).thenReturn(Optional.of(storedToken));

        // when & then
        assertThatThrownBy(() -> authService.refresh(refreshToken))
            .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    @DisplayName("만료된 Refresh Token으로 갱신 시 실패한다")
    void refresh_expiredToken() {
        // given
        String refreshToken = "expired-refresh-token";
        Long userId = 1L;
        
        RefreshToken storedToken = mock(RefreshToken.class);
        when(storedToken.getToken()).thenReturn(refreshToken);
        when(storedToken.isExpired()).thenReturn(true);

        when(tokenProvider.validateToken(refreshToken)).thenReturn(true);
        when(tokenProvider.getUserId(refreshToken)).thenReturn(userId);
        when(refreshTokenRepository.findByUserId(userId)).thenReturn(Optional.of(storedToken));

        // when & then
        assertThatThrownBy(() -> authService.refresh(refreshToken))
            .isInstanceOf(TokenExpiredException.class);
    }
}
```

**AuthControllerRefreshTest.java**
```java
@WebMvcTest(AuthController.class)
@DisplayName("AuthController - 토큰 갱신 테스트")
class AuthControllerRefreshTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AuthService authService;

    @MockBean
    private TokenProvider tokenProvider;

    @MockBean
    private CookieUtil cookieUtil;

    @Test
    @DisplayName("POST /api/v1/auth/refresh - 토큰 갱신 성공")
    void refresh() throws Exception {
        // given
        String refreshToken = "valid-refresh-token";
        String newAccessToken = "new-access-token";

        when(authService.refresh(refreshToken)).thenReturn(newAccessToken);
        when(tokenProvider.getAccessTokenValidity()).thenReturn(3600L);
        when(cookieUtil.createAccessTokenCookie(newAccessToken, 3600L))
            .thenReturn(ResponseCookie.from("accessToken", newAccessToken).build());

        // when & then
        mockMvc.perform(post("/api/v1/auth/refresh")
                .cookie(new Cookie("refreshToken", refreshToken)))
            .andExpect(status().isOk())
            .andExpect(header().exists("Set-Cookie"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh - Refresh Token 없으면 실패")
    void refresh_noToken() throws Exception {
        // when & then
        mockMvc.perform(post("/api/v1/auth/refresh"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh - 유효하지 않은 토큰")
    void refresh_invalidToken() throws Exception {
        // given
        String refreshToken = "invalid-token";
        when(authService.refresh(refreshToken)).thenThrow(new InvalidTokenException());

        // when & then
        mockMvc.perform(post("/api/v1/auth/refresh")
                .cookie(new Cookie("refreshToken", refreshToken)))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh - 만료된 토큰")
    void refresh_expiredToken() throws Exception {
        // given
        String refreshToken = "expired-token";
        when(authService.refresh(refreshToken)).thenThrow(new TokenExpiredException());

        // when & then
        mockMvc.perform(post("/api/v1/auth/refresh")
                .cookie(new Cookie("refreshToken", refreshToken)))
            .andExpect(status().isUnauthorized());
    }
}
```

### 5.2 Green: 구현

**AuthService.java (토큰 갱신 추가)**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class AuthService {

    private final MemberRepository memberRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenProvider tokenProvider;
    // ... 기존 필드들 ...

    // ... 기존 메서드들 ...

    public String refresh(String refreshToken) {
        // 1. Refresh Token 유효성 검증
        if (!tokenProvider.validateToken(refreshToken)) {
            throw new InvalidTokenException();
        }

        // 2. 토큰에서 사용자 ID 추출
        Long userId = tokenProvider.getUserId(refreshToken);

        // 3. DB에서 저장된 Refresh Token 조회
        RefreshToken storedToken = refreshTokenRepository.findByUserId(userId)
            .orElseThrow(InvalidTokenException::new);

        // 4. 토큰 값 일치 확인 (동시 로그인 제한)
        if (!storedToken.getToken().equals(refreshToken)) {
            throw new InvalidTokenException();
        }

        // 5. 만료 확인
        if (storedToken.isExpired()) {
            refreshTokenRepository.deleteByUserId(userId);
            throw new TokenExpiredException();
        }

        // 6. 사용자 정보 조회
        Member member = memberRepository.findById(userId)
            .orElseThrow(InvalidTokenException::new);

        // 7. 새 Access Token 발급
        return tokenProvider.createAccessToken(
            member.getId(), 
            member.getEmail(), 
            member.getRole()
        );
    }
}
```

**AuthController.java (토큰 갱신 추가)**
```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final TokenProvider tokenProvider;
    private final CookieUtil cookieUtil;
    // ... 기존 필드들 ...

    // ... 기존 메서드들 ...

    @PostMapping("/refresh")
    public ResponseEntity<Void> refresh(
            @CookieValue(name = "refreshToken", required = false) String refreshToken) {
        
        if (refreshToken == null) {
            throw new InvalidTokenException();
        }

        String newAccessToken = authService.refresh(refreshToken);

        ResponseCookie accessTokenCookie = cookieUtil.createAccessTokenCookie(
            newAccessToken, tokenProvider.getAccessTokenValidity());

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, accessTokenCookie.toString())
            .build();
    }
}
```

---

## 6. 예외 처리 추가

**GlobalExceptionHandler.java (인증 관련 예외 추가)**
```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(InvalidTokenException.class)
    public ResponseEntity<ErrorResponse> handleInvalidToken(InvalidTokenException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(new ErrorResponse("AUTH005", e.getMessage()));
    }

    @ExceptionHandler(TokenExpiredException.class)
    public ResponseEntity<ErrorResponse> handleTokenExpired(TokenExpiredException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(new ErrorResponse("AUTH004", e.getMessage()));
    }

    @ExceptionHandler(InvalidCredentialsException.class)
    public ResponseEntity<ErrorResponse> handleInvalidCredentials(InvalidCredentialsException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(new ErrorResponse("AUTH003", e.getMessage()));
    }
}

@Getter
@AllArgsConstructor
class ErrorResponse {
    private String code;
    private String message;
}
```

---

## 7. 검증

```bash
# 테스트 실행
./gradlew test --tests "*AuthService*Refresh*"
./gradlew test --tests "*AuthController*Refresh*"

# API 수동 테스트 (로그인 후)
# 1. 먼저 로그인하여 쿠키 획득
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "Password1!"}' \
  -c cookies.txt

# 2. 토큰 갱신
curl -X POST http://localhost:8080/api/v1/auth/refresh \
  -b cookies.txt \
  -v
```

---

## 8. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `AuthService.java` | domain | 서비스 (토큰 갱신 추가) |
| `AuthController.java` | api | 컨트롤러 (토큰 갱신 추가) |
| `GlobalExceptionHandler.java` | api | 전역 예외 처리 |
| `ErrorResponse.java` | api | 에러 응답 DTO |

---

## 9. 다음 Phase

→ [Phase 09: 비밀번호 관리](./phase09-password.md)
