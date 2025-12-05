# Phase 09: 비밀번호 관리

> 예상 시간: 2시간

## 1. 목표

비밀번호 변경 및 비밀번호 재설정(찾기) 기능을 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] 비밀번호 변경 API 구현 (로그인 상태)
- [ ] 비밀번호 재설정 요청 API 구현
- [ ] 비밀번호 재설정 API 구현
- [ ] PasswordResetToken 도메인 구현
- [ ] 비밀번호 재설정 이메일 발송
- [ ] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-18 | 로그인 상태에서 비밀번호 변경 |
| US-19 | 비밀번호 찾기 이메일 발송 |
| US-20 | 이메일 링크로 비밀번호 재설정 |

---

## 4. API 명세

| Method | Endpoint | 설명 |
|--------|----------|------|
| PATCH | `/api/v1/auth/password` | 비밀번호 변경 |
| POST | `/api/v1/auth/password/reset-request` | 비밀번호 재설정 요청 |
| POST | `/api/v1/auth/password/reset` | 비밀번호 재설정 |

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── auth/
        ├── PasswordResetToken.java
        ├── PasswordResetTokenRepository.java
        └── PasswordService.java

sw-campus-infra/db-postgres/
└── src/main/java/com/swcampus/infra/postgres/
    └── auth/
        ├── PasswordResetTokenEntity.java
        ├── PasswordResetTokenJpaRepository.java
        └── PasswordResetTokenRepositoryImpl.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        ├── PasswordController.java
        └── request/
            ├── PasswordChangeRequest.java
            ├── PasswordResetRequest.java
            └── PasswordResetConfirmRequest.java
```

---

## 6. TDD Tasks

### 6.1 Red: 테스트 작성

**PasswordResetTokenTest.java**
```java
@DisplayName("PasswordResetToken 도메인 테스트")
class PasswordResetTokenTest {

    @Test
    @DisplayName("비밀번호 재설정 토큰을 생성할 수 있다")
    void create() {
        // given
        Long userId = 1L;

        // when
        PasswordResetToken token = PasswordResetToken.create(userId);

        // then
        assertThat(token.getUserId()).isEqualTo(userId);
        assertThat(token.getToken()).isNotBlank();
        assertThat(token.isUsed()).isFalse();
        assertThat(token.getExpiresAt()).isAfter(LocalDateTime.now());
    }

    @Test
    @DisplayName("토큰을 사용할 수 있다")
    void use() {
        // given
        PasswordResetToken token = PasswordResetToken.create(1L);

        // when
        token.use();

        // then
        assertThat(token.isUsed()).isTrue();
    }

    @Test
    @DisplayName("만료된 토큰은 사용할 수 없다")
    void useExpiredToken() {
        // given
        PasswordResetToken token = PasswordResetToken.create(1L);
        ReflectionTestUtils.setField(token, "expiresAt", LocalDateTime.now().minusHours(1));

        // when & then
        assertThatThrownBy(token::use)
            .isInstanceOf(TokenExpiredException.class);
    }

    @Test
    @DisplayName("이미 사용된 토큰은 다시 사용할 수 없다")
    void useAlreadyUsedToken() {
        // given
        PasswordResetToken token = PasswordResetToken.create(1L);
        token.use();

        // when & then
        assertThatThrownBy(token::use)
            .isInstanceOf(IllegalStateException.class);
    }
}
```

**PasswordServiceTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("PasswordService 테스트")
class PasswordServiceTest {

    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private PasswordResetTokenRepository passwordResetTokenRepository;
    
    @Mock
    private PasswordEncoder passwordEncoder;
    
    @Mock
    private PasswordValidator passwordValidator;
    
    @Mock
    private MailSender mailSender;

    @InjectMocks
    private PasswordService passwordService;

    @Test
    @DisplayName("비밀번호를 변경할 수 있다")
    void changePassword() {
        // given
        Long userId = 1L;
        String currentPassword = "OldPassword1!";
        String newPassword = "NewPassword1!";
        
        Member member = mock(Member.class);
        when(member.getPassword()).thenReturn("encodedOldPassword");
        
        when(memberRepository.findById(userId)).thenReturn(Optional.of(member));
        when(passwordEncoder.matches(currentPassword, "encodedOldPassword")).thenReturn(true);
        when(passwordEncoder.encode(newPassword)).thenReturn("encodedNewPassword");

        // when
        passwordService.changePassword(userId, currentPassword, newPassword);

        // then
        verify(passwordValidator).validate(newPassword);
        verify(member).changePassword("encodedNewPassword");
        verify(memberRepository).save(member);
    }

    @Test
    @DisplayName("현재 비밀번호가 틀리면 변경 실패")
    void changePassword_wrongCurrentPassword() {
        // given
        Long userId = 1L;
        
        Member member = mock(Member.class);
        when(member.getPassword()).thenReturn("encodedOldPassword");
        
        when(memberRepository.findById(userId)).thenReturn(Optional.of(member));
        when(passwordEncoder.matches("wrongPassword", "encodedOldPassword")).thenReturn(false);

        // when & then
        assertThatThrownBy(() -> 
            passwordService.changePassword(userId, "wrongPassword", "NewPassword1!"))
            .isInstanceOf(InvalidPasswordException.class)
            .hasMessageContaining("현재 비밀번호");
    }

    @Test
    @DisplayName("비밀번호 재설정 이메일을 발송할 수 있다")
    void sendResetEmail() {
        // given
        String email = "user@example.com";
        
        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(memberRepository.findByEmail(email)).thenReturn(Optional.of(member));

        // when
        passwordService.sendPasswordResetEmail(email);

        // then
        verify(passwordResetTokenRepository).deleteByUserId(1L);
        verify(passwordResetTokenRepository).save(any(PasswordResetToken.class));
        verify(mailSender).send(eq(email), anyString(), anyString());
    }

    @Test
    @DisplayName("비밀번호를 재설정할 수 있다")
    void resetPassword() {
        // given
        String token = "valid-reset-token";
        String newPassword = "NewPassword1!";
        
        PasswordResetToken resetToken = mock(PasswordResetToken.class);
        when(resetToken.getUserId()).thenReturn(1L);
        when(resetToken.isExpired()).thenReturn(false);
        when(resetToken.isUsed()).thenReturn(false);
        
        Member member = mock(Member.class);
        
        when(passwordResetTokenRepository.findByToken(token)).thenReturn(Optional.of(resetToken));
        when(memberRepository.findById(1L)).thenReturn(Optional.of(member));
        when(passwordEncoder.encode(newPassword)).thenReturn("encodedNewPassword");

        // when
        passwordService.resetPassword(token, newPassword);

        // then
        verify(passwordValidator).validate(newPassword);
        verify(resetToken).use();
        verify(member).changePassword("encodedNewPassword");
        verify(memberRepository).save(member);
    }
}
```

**PasswordControllerTest.java**
```java
@WebMvcTest(PasswordController.class)
@DisplayName("PasswordController 테스트")
class PasswordControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private PasswordService passwordService;

    @MockBean
    private TokenProvider tokenProvider;

    @Test
    @DisplayName("PATCH /api/v1/auth/password - 비밀번호 변경 성공")
    void changePassword() throws Exception {
        // given
        PasswordChangeRequest request = new PasswordChangeRequest("OldPassword1!", "NewPassword1!");
        
        when(tokenProvider.validateToken("valid-token")).thenReturn(true);
        when(tokenProvider.getUserId("valid-token")).thenReturn(1L);

        // when & then
        mockMvc.perform(patch("/api/v1/auth/password")
                .cookie(new Cookie("accessToken", "valid-token"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk());

        verify(passwordService).changePassword(1L, "OldPassword1!", "NewPassword1!");
    }

    @Test
    @DisplayName("POST /api/v1/auth/password/reset-request - 재설정 요청")
    void requestPasswordReset() throws Exception {
        // given
        PasswordResetRequest request = new PasswordResetRequest("user@example.com");

        // when & then
        mockMvc.perform(post("/api/v1/auth/password/reset-request")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.message").value("비밀번호 재설정 메일이 발송되었습니다"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/password/reset - 비밀번호 재설정")
    void resetPassword() throws Exception {
        // given
        PasswordResetConfirmRequest request = new PasswordResetConfirmRequest(
            "valid-token", "NewPassword1!");

        // when & then
        mockMvc.perform(post("/api/v1/auth/password/reset")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk());

        verify(passwordService).resetPassword("valid-token", "NewPassword1!");
    }
}
```

### 6.2 Green: 구현

**PasswordResetToken.java**
```java
@Getter
public class PasswordResetToken {
    private Long id;
    private Long userId;
    private String token;
    private LocalDateTime expiresAt;
    private boolean used;
    private LocalDateTime createdAt;

    private static final long EXPIRY_HOURS = 1;  // 1시간

    public static PasswordResetToken create(Long userId) {
        PasswordResetToken resetToken = new PasswordResetToken();
        resetToken.userId = userId;
        resetToken.token = UUID.randomUUID().toString();
        resetToken.expiresAt = LocalDateTime.now().plusHours(EXPIRY_HOURS);
        resetToken.used = false;
        resetToken.createdAt = LocalDateTime.now();
        return resetToken;
    }

    public void use() {
        if (isExpired()) {
            throw new TokenExpiredException();
        }
        if (this.used) {
            throw new IllegalStateException("이미 사용된 토큰입니다");
        }
        this.used = true;
    }

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }
}
```

**PasswordResetTokenRepository.java**
```java
public interface PasswordResetTokenRepository {
    PasswordResetToken save(PasswordResetToken token);
    Optional<PasswordResetToken> findByToken(String token);
    void deleteByUserId(Long userId);
}
```

**PasswordService.java**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class PasswordService {

    private final MemberRepository memberRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordValidator passwordValidator;
    private final MailSender mailSender;

    @Value("${app.frontend-url}")
    private String frontendUrl;

    public void changePassword(Long userId, String currentPassword, String newPassword) {
        Member member = memberRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다"));

        // 현재 비밀번호 확인
        if (!passwordEncoder.matches(currentPassword, member.getPassword())) {
            throw new InvalidPasswordException("현재 비밀번호가 일치하지 않습니다");
        }

        // 새 비밀번호 정책 검증
        passwordValidator.validate(newPassword);

        // 비밀번호 변경
        String encodedPassword = passwordEncoder.encode(newPassword);
        member.changePassword(encodedPassword);
        memberRepository.save(member);
    }

    public void sendPasswordResetEmail(String email) {
        Member member = memberRepository.findByEmail(email)
            .orElse(null);

        // 가입되지 않은 이메일이어도 성공 응답 (보안)
        if (member == null) {
            return;
        }

        // 기존 토큰 삭제
        passwordResetTokenRepository.deleteByUserId(member.getId());

        // 새 토큰 생성
        PasswordResetToken resetToken = PasswordResetToken.create(member.getId());
        passwordResetTokenRepository.save(resetToken);

        // 이메일 발송
        String resetUrl = frontendUrl + "/password/reset?token=" + resetToken.getToken();
        String subject = "[SW Campus] 비밀번호 재설정";
        String content = buildResetEmailContent(resetUrl);
        
        mailSender.send(email, subject, content);
    }

    public void resetPassword(String token, String newPassword) {
        PasswordResetToken resetToken = passwordResetTokenRepository.findByToken(token)
            .orElseThrow(() -> new InvalidTokenException());

        // 토큰 유효성 검사 및 사용 처리
        resetToken.use();

        // 비밀번호 정책 검증
        passwordValidator.validate(newPassword);

        // 비밀번호 변경
        Member member = memberRepository.findById(resetToken.getUserId())
            .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다"));

        String encodedPassword = passwordEncoder.encode(newPassword);
        member.changePassword(encodedPassword);
        
        memberRepository.save(member);
        passwordResetTokenRepository.save(resetToken);
    }

    private String buildResetEmailContent(String resetUrl) {
        return """
            <html>
            <body>
                <h2>SW Campus 비밀번호 재설정</h2>
                <p>아래 버튼을 클릭하여 비밀번호를 재설정해주세요.</p>
                <a href="%s" style="display:inline-block;padding:10px 20px;background:#dc3545;color:#fff;text-decoration:none;border-radius:5px;">
                    비밀번호 재설정
                </a>
                <p>이 링크는 1시간 동안 유효합니다.</p>
                <p>본인이 요청하지 않은 경우 이 메일을 무시해주세요.</p>
            </body>
            </html>
            """.formatted(resetUrl);
    }
}
```

**Request DTOs**
```java
// PasswordChangeRequest.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class PasswordChangeRequest {
    @NotBlank(message = "현재 비밀번호는 필수입니다")
    private String currentPassword;

    @NotBlank(message = "새 비밀번호는 필수입니다")
    private String newPassword;
}

// PasswordResetRequest.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class PasswordResetRequest {
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    private String email;
}

// PasswordResetConfirmRequest.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class PasswordResetConfirmRequest {
    @NotBlank(message = "토큰은 필수입니다")
    private String token;

    @NotBlank(message = "새 비밀번호는 필수입니다")
    private String newPassword;
}
```

**PasswordController.java**
```java
@RestController
@RequestMapping("/api/v1/auth/password")
@RequiredArgsConstructor
public class PasswordController {

    private final PasswordService passwordService;
    private final TokenProvider tokenProvider;

    @PatchMapping
    public ResponseEntity<Void> changePassword(
            @CookieValue(name = "accessToken") String accessToken,
            @Valid @RequestBody PasswordChangeRequest request) {
        
        Long userId = tokenProvider.getUserId(accessToken);
        passwordService.changePassword(userId, request.getCurrentPassword(), request.getNewPassword());
        
        return ResponseEntity.ok().build();
    }

    @PostMapping("/reset-request")
    public ResponseEntity<Map<String, String>> requestPasswordReset(
            @Valid @RequestBody PasswordResetRequest request) {
        
        passwordService.sendPasswordResetEmail(request.getEmail());
        return ResponseEntity.ok(Map.of("message", "비밀번호 재설정 메일이 발송되었습니다"));
    }

    @PostMapping("/reset")
    public ResponseEntity<Void> resetPassword(
            @Valid @RequestBody PasswordResetConfirmRequest request) {
        
        passwordService.resetPassword(request.getToken(), request.getNewPassword());
        return ResponseEntity.ok().build();
    }
}
```

---

## 7. 검증

```bash
# 테스트 실행
./gradlew test --tests "*PasswordResetToken*"
./gradlew test --tests "*PasswordService*"
./gradlew test --tests "*PasswordController*"

# API 수동 테스트
# 비밀번호 변경 (로그인 상태)
curl -X PATCH http://localhost:8080/api/v1/auth/password \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"currentPassword": "OldPassword1!", "newPassword": "NewPassword1!"}'

# 비밀번호 재설정 요청
curl -X POST http://localhost:8080/api/v1/auth/password/reset-request \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'

# 비밀번호 재설정
curl -X POST http://localhost:8080/api/v1/auth/password/reset \
  -H "Content-Type: application/json" \
  -d '{"token": "reset-token", "newPassword": "NewPassword1!"}'
```

---

## 8. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `PasswordResetToken.java` | domain | 비밀번호 재설정 토큰 도메인 |
| `PasswordResetTokenRepository.java` | domain | Repository 인터페이스 |
| `PasswordService.java` | domain | 비밀번호 서비스 |
| `PasswordResetTokenEntity.java` | infra | JPA Entity |
| `PasswordResetTokenRepositoryImpl.java` | infra | Repository 구현체 |
| `PasswordController.java` | api | 비밀번호 컨트롤러 |
| `PasswordChangeRequest.java` | api | 변경 요청 DTO |
| `PasswordResetRequest.java` | api | 재설정 요청 DTO |
| `PasswordResetConfirmRequest.java` | api | 재설정 확인 DTO |

---

## 9. 다음 Phase

→ [Phase 10: OAuth](./phase10-oauth.md)
