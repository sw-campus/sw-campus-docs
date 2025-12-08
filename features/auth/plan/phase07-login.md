# Phase 07: 로그인/로그아웃

> 예상 시간: 2시간  
> **상태: ✅ 완료 (2025-12-08)**

## 1. 목표

이메일 로그인, 로그아웃 기능을 구현하고 JWT 토큰을 Cookie로 발급합니다.

---

## 2. 완료 조건 (Definition of Done)

- [x] 로그인 API 구현
- [x] 로그아웃 API 구현
- [x] Access Token, Refresh Token 발급 (Cookie)
- [x] Refresh Token DB 저장
- [x] 동시 로그인 제한 (기존 RT 삭제)
- [x] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-11 | 이메일/비밀번호 로그인 |
| US-12 | 로그인 실패 시 에러 메시지 |
| US-13 | 로그인 성공 시 JWT 발급 |
| US-14 | 로그아웃 시 토큰 삭제 |

---

## 4. API 명세

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/v1/auth/login` | 로그인 |
| POST | `/api/v1/auth/logout` | 로그아웃 |

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── auth/
        ├── AuthService.java (추가)
        └── LoginResult.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        ├── AuthController.java (추가)
        ├── request/
        │   └── LoginRequest.java
        └── response/
            └── LoginResponse.java
```

---

## 6. TDD Tasks

### 6.1 Red: 테스트 작성

**AuthServiceLoginTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService - 로그인 테스트")
class AuthServiceLoginTest {

    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private RefreshTokenRepository refreshTokenRepository;
    
    @Mock
    private PasswordEncoder passwordEncoder;
    
    @Mock
    private TokenProvider tokenProvider;

    @InjectMocks
    private AuthService authService;

    @Test
    @DisplayName("로그인에 성공한다")
    void login() {
        // given
        String email = "user@example.com";
        String password = "Password1!";
        
        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn(email);
        when(member.getPassword()).thenReturn("encodedPassword");
        when(member.getRole()).thenReturn(Role.USER);
        
        when(memberRepository.findByEmail(email)).thenReturn(Optional.of(member));
        when(passwordEncoder.matches(password, "encodedPassword")).thenReturn(true);
        when(tokenProvider.createAccessToken(1L, email, Role.USER)).thenReturn("access-token");
        when(tokenProvider.createRefreshToken(1L)).thenReturn("refresh-token");
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);

        // when
        LoginResult result = authService.login(email, password);

        // then
        assertThat(result.getAccessToken()).isEqualTo("access-token");
        assertThat(result.getRefreshToken()).isEqualTo("refresh-token");
        assertThat(result.getMember()).isEqualTo(member);
    }

    @Test
    @DisplayName("존재하지 않는 이메일로 로그인 시 실패한다")
    void login_emailNotFound() {
        // given
        when(memberRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> authService.login("unknown@example.com", "password"))
            .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    @DisplayName("비밀번호 불일치 시 로그인 실패한다")
    void login_wrongPassword() {
        // given
        Member member = mock(Member.class);
        when(member.getPassword()).thenReturn("encodedPassword");
        when(memberRepository.findByEmail("user@example.com")).thenReturn(Optional.of(member));
        when(passwordEncoder.matches("wrongPassword", "encodedPassword")).thenReturn(false);

        // when & then
        assertThatThrownBy(() -> authService.login("user@example.com", "wrongPassword"))
            .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    @DisplayName("로그인 시 기존 Refresh Token이 삭제된다 (동시 로그인 제한)")
    void login_deletesExistingRefreshToken() {
        // given
        String email = "user@example.com";
        String password = "Password1!";
        
        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn(email);
        when(member.getPassword()).thenReturn("encodedPassword");
        when(member.getRole()).thenReturn(Role.USER);
        
        when(memberRepository.findByEmail(email)).thenReturn(Optional.of(member));
        when(passwordEncoder.matches(password, "encodedPassword")).thenReturn(true);
        when(tokenProvider.createAccessToken(any(), any(), any())).thenReturn("access-token");
        when(tokenProvider.createRefreshToken(any())).thenReturn("refresh-token");
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);

        // when
        authService.login(email, password);

        // then
        verify(refreshTokenRepository).deleteByUserId(1L);  // 기존 토큰 삭제
        verify(refreshTokenRepository).save(any(RefreshToken.class));  // 새 토큰 저장
    }
}
```

**AuthServiceLogoutTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService - 로그아웃 테스트")
class AuthServiceLogoutTest {

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @InjectMocks
    private AuthService authService;

    @Test
    @DisplayName("로그아웃 시 Refresh Token이 삭제된다")
    void logout() {
        // given
        Long userId = 1L;

        // when
        authService.logout(userId);

        // then
        verify(refreshTokenRepository).deleteByUserId(userId);
    }
}
```

**AuthControllerLoginTest.java**
```java
@WebMvcTest(AuthController.class)
@DisplayName("AuthController - 로그인/로그아웃 테스트")
class AuthControllerLoginTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;

    @MockBean
    private CookieUtil cookieUtil;

    @MockBean
    private TokenProvider tokenProvider;

    @Test
    @DisplayName("POST /api/v1/auth/login - 로그인 성공")
    void login() throws Exception {
        // given
        LoginRequest request = new LoginRequest("user@example.com", "Password1!");
        
        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn("user@example.com");
        when(member.getName()).thenReturn("홍길동");
        when(member.getRole()).thenReturn(Role.USER);
        when(member.getOrgAuth()).thenReturn(null);

        LoginResult result = new LoginResult("access-token", "refresh-token", member);
        when(authService.login(request.getEmail(), request.getPassword())).thenReturn(result);
        
        when(tokenProvider.getAccessTokenValidity()).thenReturn(3600L);
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);
        
        when(cookieUtil.createAccessTokenCookie("access-token", 3600L))
            .thenReturn(ResponseCookie.from("accessToken", "access-token").build());
        when(cookieUtil.createRefreshTokenCookie("refresh-token", 86400L))
            .thenReturn(ResponseCookie.from("refreshToken", "refresh-token").build());

        // when & then
        mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(header().exists("Set-Cookie"))
            .andExpect(jsonPath("$.userId").value(1))
            .andExpect(jsonPath("$.email").value("user@example.com"))
            .andExpect(jsonPath("$.role").value("USER"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login - 로그인 실패")
    void login_failed() throws Exception {
        // given
        LoginRequest request = new LoginRequest("user@example.com", "wrongPassword");
        when(authService.login(request.getEmail(), request.getPassword()))
            .thenThrow(new InvalidCredentialsException());

        // when & then
        mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout - 로그아웃 성공")
    void logout() throws Exception {
        // given
        when(cookieUtil.deleteAccessTokenCookie())
            .thenReturn(ResponseCookie.from("accessToken", "").maxAge(0).build());
        when(cookieUtil.deleteRefreshTokenCookie())
            .thenReturn(ResponseCookie.from("refreshToken", "").maxAge(0).build());

        // when & then
        mockMvc.perform(post("/api/v1/auth/logout")
                .cookie(new Cookie("accessToken", "valid-token"))
                .cookie(new Cookie("refreshToken", "valid-refresh-token")))
            .andExpect(status().isOk())
            .andExpect(header().exists("Set-Cookie"));
    }
}
```

### 6.2 Green: 구현

**LoginResult.java**
```java
@Getter
@AllArgsConstructor
public class LoginResult {
    private final String accessToken;
    private final String refreshToken;
    private final Member member;
}
```

**InvalidCredentialsException.java**
```java
public class InvalidCredentialsException extends RuntimeException {
    public InvalidCredentialsException() {
        super("이메일 또는 비밀번호가 일치하지 않습니다");
    }
}
```

**AuthService.java (로그인/로그아웃 추가)**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class AuthService {

    private final MemberRepository memberRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenProvider tokenProvider;
    // ... 기존 필드들 ...

    // ... 기존 signup 메서드들 ...

    public LoginResult login(String email, String password) {
        // 1. 회원 조회
        Member member = memberRepository.findByEmail(email)
            .orElseThrow(InvalidCredentialsException::new);

        // 2. 비밀번호 검증
        if (!passwordEncoder.matches(password, member.getPassword())) {
            throw new InvalidCredentialsException();
        }

        // 3. 기존 Refresh Token 삭제 (동시 로그인 제한)
        refreshTokenRepository.deleteByUserId(member.getId());

        // 4. 토큰 생성
        String accessToken = tokenProvider.createAccessToken(
            member.getId(), member.getEmail(), member.getRole());
        String refreshToken = tokenProvider.createRefreshToken(member.getId());

        // 5. Refresh Token 저장
        RefreshToken refreshTokenEntity = RefreshToken.create(
            member.getId(), 
            refreshToken, 
            tokenProvider.getRefreshTokenValidity()
        );
        refreshTokenRepository.save(refreshTokenEntity);

        return new LoginResult(accessToken, refreshToken, member);
    }

    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }
}
```

**LoginRequest.java**
```java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class LoginRequest {
    
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    private String email;

    @NotBlank(message = "비밀번호는 필수입니다")
    private String password;
}
```

**LoginResponse.java**
```java
@Getter
@AllArgsConstructor
public class LoginResponse {
    private Long userId;
    private String email;
    private String name;
    private String role;
    private Integer orgAuth;  // PROVIDER인 경우만

    public static LoginResponse from(Member member) {
        return new LoginResponse(
            member.getId(),
            member.getEmail(),
            member.getName(),
            member.getRole().name(),
            member.getOrgAuth()
        );
    }
}
```

**AuthController.java (로그인/로그아웃 추가)**
```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final EmailService emailService;
    private final TokenProvider tokenProvider;
    private final CookieUtil cookieUtil;

    // ... 기존 이메일 인증, 회원가입 API ...

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(
            @Valid @RequestBody LoginRequest request) {
        
        LoginResult result = authService.login(request.getEmail(), request.getPassword());

        ResponseCookie accessTokenCookie = cookieUtil.createAccessTokenCookie(
            result.getAccessToken(), tokenProvider.getAccessTokenValidity());
        ResponseCookie refreshTokenCookie = cookieUtil.createRefreshTokenCookie(
            result.getRefreshToken(), tokenProvider.getRefreshTokenValidity());

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, accessTokenCookie.toString())
            .header(HttpHeaders.SET_COOKIE, refreshTokenCookie.toString())
            .body(LoginResponse.from(result.getMember()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            @CookieValue(name = "accessToken", required = false) String accessToken) {
        
        if (accessToken != null && tokenProvider.validateToken(accessToken)) {
            Long userId = tokenProvider.getUserId(accessToken);
            authService.logout(userId);
        }

        ResponseCookie deleteAccessCookie = cookieUtil.deleteAccessTokenCookie();
        ResponseCookie deleteRefreshCookie = cookieUtil.deleteRefreshTokenCookie();

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, deleteAccessCookie.toString())
            .header(HttpHeaders.SET_COOKIE, deleteRefreshCookie.toString())
            .build();
    }
}
```

---

## 7. 검증

```bash
# 테스트 실행
./gradlew test --tests "*AuthService*Login*"
./gradlew test --tests "*AuthService*Logout*"
./gradlew test --tests "*AuthController*Login*"

# API 수동 테스트
# 로그인
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "Password1!"}' \
  -c cookies.txt \
  -v

# 로그아웃
curl -X POST http://localhost:8080/api/v1/auth/logout \
  -b cookies.txt \
  -v
```

---

## 8. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `LoginResult.java` | domain | 로그인 결과 객체 |
| `InvalidCredentialsException.java` | domain | 인증 실패 예외 |
| `AuthService.java` | domain | 서비스 (로그인/로그아웃 추가) |
| `LoginRequest.java` | api | 로그인 요청 DTO |
| `LoginResponse.java` | api | 로그인 응답 DTO |
| `AuthController.java` | api | 컨트롤러 (로그인/로그아웃 추가) |

---

## 9. 다음 Phase

→ [Phase 08: 토큰 갱신](./phase08-token.md)
