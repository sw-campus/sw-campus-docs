# Phase 09: 비밀번호 관리

> 예상 시간: 1시간

## 1. 목표

비밀번호 변경 및 임시 비밀번호 발급(비밀번호 찾기) 기능을 구현합니다.

> **Note**: 비밀번호 관리 기능은 일반 회원가입(이메일) 사용자만 해당됩니다.
> **Note**: OAuth 사용자는 비밀번호가 없으므로 이 기능을 사용할 수 없습니다.

---

## 2. 완료 조건 (Definition of Done)

- [x] 비밀번호 변경 API 구현 (로그인 상태)
- [x] 임시 비밀번호 발급 API 구현
- [x] 임시 비밀번호 이메일 발송
- [x] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-18 | 로그인 상태에서 비밀번호 변경 |
| US-19 | 임시 비밀번호 이메일 발송 |

---

## 4. API 명세

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| PATCH | `/api/v1/auth/password` | 비밀번호 변경 | 필요 (Cookie) |
| POST | `/api/v1/auth/password/temporary` | 임시 비밀번호 발급 | 불필요 |

### 4.1 비밀번호 변경

```
PATCH /api/v1/auth/password

Request:
- Cookie: accessToken (필수)
- Body:
  {
    "currentPassword": "OldPassword1!",
    "newPassword": "NewPassword1!"
  }

Response:
- 200 OK
- 400 Bad Request (현재 비밀번호 불일치, 정책 위반, OAuth 사용자)
- 401 Unauthorized (미로그인)
```

### 4.2 임시 비밀번호 발급

```
POST /api/v1/auth/password/temporary

Request:
- Body:
  {
    "email": "user@example.com"
  }

Response:
- 200 OK
  {
    "message": "임시 비밀번호가 이메일로 발송되었습니다"
  }

Note: 보안을 위해 이메일 존재 여부와 관계없이 동일 응답 반환
```

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── auth/
        └── PasswordService.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        ├── PasswordController.java
        └── request/
            ├── PasswordChangeRequest.java
            └── TemporaryPasswordRequest.java
```

---

## 6. TDD Tasks

### 6.1 Red: 테스트 작성

**PasswordServiceTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("PasswordService 테스트")
class PasswordServiceTest {

    @Mock
    private MemberRepository memberRepository;
    
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
    @DisplayName("OAuth 사용자는 비밀번호 변경 불가")
    void changePassword_oauthUser() {
        // given
        Long userId = 1L;
        
        Member member = mock(Member.class);
        when(member.getPassword()).thenReturn(null);  // OAuth 사용자
        
        when(memberRepository.findById(userId)).thenReturn(Optional.of(member));

        // when & then
        assertThatThrownBy(() -> 
            passwordService.changePassword(userId, "anyPassword", "NewPassword1!"))
            .isInstanceOf(InvalidPasswordException.class)
            .hasMessageContaining("소셜 로그인");
    }

    @Test
    @DisplayName("임시 비밀번호를 발급할 수 있다")
    void issueTemporaryPassword() {
        // given
        String email = "user@example.com";
        
        Member member = mock(Member.class);
        when(member.getPassword()).thenReturn("existingPassword");  // 일반 가입자
        
        when(memberRepository.findByEmail(email)).thenReturn(Optional.of(member));
        when(passwordEncoder.encode(anyString())).thenReturn("encodedTempPassword");

        // when
        passwordService.issueTemporaryPassword(email);

        // then
        verify(member).changePassword("encodedTempPassword");
        verify(memberRepository).save(member);
        verify(mailSender).send(eq(email), anyString(), anyString());
    }

    @Test
    @DisplayName("존재하지 않는 이메일에도 동일 응답 (보안)")
    void issueTemporaryPassword_notFoundEmail() {
        // given
        String email = "notfound@example.com";
        when(memberRepository.findByEmail(email)).thenReturn(Optional.empty());

        // when & then (예외 없이 정상 종료)
        assertThatCode(() -> passwordService.issueTemporaryPassword(email))
            .doesNotThrowAnyException();
        
        verify(mailSender, never()).send(anyString(), anyString(), anyString());
    }

    @Test
    @DisplayName("OAuth 사용자에게는 임시 비밀번호 미발급 (보안)")
    void issueTemporaryPassword_oauthUser() {
        // given
        String email = "oauth@example.com";
        
        Member member = mock(Member.class);
        when(member.getPassword()).thenReturn(null);  // OAuth 사용자
        
        when(memberRepository.findByEmail(email)).thenReturn(Optional.of(member));

        // when & then (예외 없이 정상 종료, 메일 미발송)
        assertThatCode(() -> passwordService.issueTemporaryPassword(email))
            .doesNotThrowAnyException();
        
        verify(mailSender, never()).send(anyString(), anyString(), anyString());
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
    @DisplayName("POST /api/v1/auth/password/temporary - 임시 비밀번호 발급")
    void issueTemporaryPassword() throws Exception {
        // given
        TemporaryPasswordRequest request = new TemporaryPasswordRequest("user@example.com");

        // when & then
        mockMvc.perform(post("/api/v1/auth/password/temporary")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.message").value("임시 비밀번호가 이메일로 발송되었습니다"));

        verify(passwordService).issueTemporaryPassword("user@example.com");
    }

    @Test
    @DisplayName("비밀번호 변경 - 미로그인 시 401")
    void changePassword_unauthorized() throws Exception {
        // given
        PasswordChangeRequest request = new PasswordChangeRequest("OldPassword1!", "NewPassword1!");

        // when & then
        mockMvc.perform(patch("/api/v1/auth/password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isUnauthorized());
    }
}
```

### 6.2 Green: 구현

**PasswordService.java**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class PasswordService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordValidator passwordValidator;
    private final MailSender mailSender;

    private static final String TEMP_PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%";
    private static final int TEMP_PASSWORD_LENGTH = 12;

    public void changePassword(Long userId, String currentPassword, String newPassword) {
        Member member = memberRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다"));

        // OAuth 사용자 체크
        if (member.getPassword() == null) {
            throw new InvalidPasswordException("소셜 로그인 사용자는 비밀번호를 변경할 수 없습니다");
        }

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

    public void issueTemporaryPassword(String email) {
        Member member = memberRepository.findByEmail(email).orElse(null);

        // 사용자 없음 또는 OAuth 사용자 → 조용히 종료 (보안)
        if (member == null || member.getPassword() == null) {
            return;
        }

        // 임시 비밀번호 생성
        String temporaryPassword = generateTemporaryPassword();
        
        // 비밀번호 변경
        String encodedPassword = passwordEncoder.encode(temporaryPassword);
        member.changePassword(encodedPassword);
        memberRepository.save(member);

        // 이메일 발송
        String subject = "[SW Campus] 임시 비밀번호 안내";
        String content = buildTemporaryPasswordEmailContent(temporaryPassword);
        mailSender.send(email, subject, content);
    }

    private String generateTemporaryPassword() {
        SecureRandom random = new SecureRandom();
        StringBuilder sb = new StringBuilder(TEMP_PASSWORD_LENGTH);
        for (int i = 0; i < TEMP_PASSWORD_LENGTH; i++) {
            int index = random.nextInt(TEMP_PASSWORD_CHARS.length());
            sb.append(TEMP_PASSWORD_CHARS.charAt(index));
        }
        return sb.toString();
    }

    private String buildTemporaryPasswordEmailContent(String temporaryPassword) {
        return """
            <html>
            <body>
                <h2>SW Campus 임시 비밀번호 안내</h2>
                <p>안녕하세요, SW Campus입니다.</p>
                <p>요청하신 임시 비밀번호를 안내해드립니다.</p>
                <div style="background:#f5f5f5;padding:20px;margin:20px 0;font-size:18px;font-weight:bold;">
                    임시 비밀번호: %s
                </div>
                <p style="color:#dc3545;">보안을 위해 로그인 후 반드시 비밀번호를 변경해주세요.</p>
                <p>본인이 요청하지 않은 경우 이 메일을 무시해주세요.</p>
                <br/>
                <p>감사합니다.</p>
                <p>SW Campus 팀</p>
            </body>
            </html>
            """.formatted(temporaryPassword);
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

// TemporaryPasswordRequest.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class TemporaryPasswordRequest {
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    private String email;
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

    @PostMapping("/temporary")
    public ResponseEntity<Map<String, String>> issueTemporaryPassword(
            @Valid @RequestBody TemporaryPasswordRequest request) {
        
        passwordService.issueTemporaryPassword(request.getEmail());
        return ResponseEntity.ok(Map.of("message", "임시 비밀번호가 이메일로 발송되었습니다"));
    }
}
```

---

## 7. 비밀번호 정책

| 규칙 | 설명 |
|------|------|
| 최소 길이 | 8자 이상 |
| 특수문자 | 1개 이상 포함 (`!@#$%^&*(),.?":{}|<>`) |

---

## 8. 임시 비밀번호 생성 규칙

| 항목 | 값 |
|------|-----|
| 길이 | 12자 |
| 구성 | 영문 대소문자 + 숫자 + 특수문자 |
| 예시 | `Temp1234!@ab` |

---

## 9. 검증

```bash
# 테스트 실행
./gradlew test --tests "*PasswordService*"
./gradlew test --tests "*PasswordController*"

# API 수동 테스트
# 비밀번호 변경 (로그인 상태)
curl -X PATCH http://localhost:8080/api/v1/auth/password \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"currentPassword": "OldPassword1!", "newPassword": "NewPassword1!"}'

# 임시 비밀번호 발급
curl -X POST http://localhost:8080/api/v1/auth/password/temporary \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

---

## 10. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `PasswordService.java` | domain | 비밀번호 서비스 |
| `PasswordController.java` | api | 비밀번호 컨트롤러 |
| `PasswordChangeRequest.java` | api | 변경 요청 DTO |
| `TemporaryPasswordRequest.java` | api | 임시 비밀번호 요청 DTO |

---

## 11. 다음 Phase

→ [Phase 10: OAuth](./phase10-oauth.md)
