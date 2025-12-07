# Phase 04: 이메일 인증

> 예상 시간: 2.5시간

## 1. 목표

이메일 인증 발송, 검증, 상태 확인 기능을 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [x] EmailVerification 도메인 구현 ✅ **Phase 02 완료**
- [x] MailService 구현 (SMTP) ✅
- [x] 이메일 인증 발송 API ✅
- [x] 이메일 인증 검증 API ✅
- [x] 이메일 인증 상태 확인 API ✅
- [x] 단위 테스트 및 통합 테스트 통과 ✅
- [x] 테스트 커버리지 90% 이상 ✅

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-01 | 이메일 입력 시 인증 메일 발송 |
| US-02 | 인증 메일 재발송 |
| US-03 | 인증 링크 클릭 시 이메일 인증 처리 |
| US-04 | 인증 토큰 만료 시 에러 표시 |
| US-05 | 인증 완료 후 회원가입 진행 |

---

## 4. API 명세

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/v1/auth/email/send` | 인증 메일 발송 |
| GET | `/api/v1/auth/email/verify` | 인증 처리 |
| GET | `/api/v1/auth/email/status` | 인증 상태 확인 |

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── auth/
        ├── EmailVerification.java           ✅ Phase 02 완료
        ├── EmailVerificationRepository.java ✅ Phase 02 완료
        ├── EmailService.java
        └── MailSender.java

sw-campus-infra/db-postgres/
└── src/main/java/com/swcampus/infra/postgres/
    └── auth/
        ├── EmailVerificationEntity.java        ✅ Phase 02 완료
        ├── EmailVerificationJpaRepository.java ✅ Phase 02 완료
        └── EmailVerificationRepositoryImpl.java ✅ Phase 02 완료

sw-campus-infra/
└── mail/
    └── SmtpMailSender.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        ├── AuthController.java
        ├── request/
        │   └── EmailSendRequest.java
        └── response/
            └── EmailStatusResponse.java
```

> ✅ **Phase 02에서 완료된 항목**: EmailVerification 도메인/인프라는 이미 구현됨

---

## 6. TDD Tasks

### 6.1 Red: 테스트 작성

> ✅ **EmailVerificationTest.java** - Phase 02에서 완료됨 (EmailVerificationTest 참조)

**EmailServiceTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("EmailService 테스트")
class EmailServiceTest {

    @Mock
    private EmailVerificationRepository emailVerificationRepository;
    
    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private MailSender mailSender;

    @InjectMocks
    private EmailService emailService;

    @Test
    @DisplayName("인증 메일을 발송할 수 있다")
    void sendVerificationEmail() {
        // given
        String email = "user@example.com";
        when(memberRepository.existsByEmail(email)).thenReturn(false);
        when(emailVerificationRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        // when
        emailService.sendVerificationEmail(email);

        // then
        verify(emailVerificationRepository).save(any(EmailVerification.class));
        verify(mailSender).send(eq(email), anyString(), anyString());
    }

    @Test
    @DisplayName("이미 가입된 이메일은 인증 발송 실패")
    void sendVerificationEmail_alreadyRegistered() {
        // given
        String email = "user@example.com";
        when(memberRepository.existsByEmail(email)).thenReturn(true);

        // when & then
        assertThatThrownBy(() -> emailService.sendVerificationEmail(email))
            .isInstanceOf(DuplicateEmailException.class);
    }

    @Test
    @DisplayName("이메일 인증을 완료할 수 있다")
    void verifyEmail() {
        // given
        String token = "valid-token";
        EmailVerification verification = EmailVerification.create("user@example.com");
        when(emailVerificationRepository.findByToken(token)).thenReturn(Optional.of(verification));

        // when
        emailService.verifyEmail(token);

        // then
        assertThat(verification.isVerified()).isTrue();
    }

    @Test
    @DisplayName("인증 상태를 확인할 수 있다")
    void checkVerificationStatus() {
        // given
        String email = "user@example.com";
        EmailVerification verification = EmailVerification.create(email);
        verification.verify();
        when(emailVerificationRepository.findByEmailAndVerified(email, true))
            .thenReturn(Optional.of(verification));

        // when
        boolean isVerified = emailService.isEmailVerified(email);

        // then
        assertThat(isVerified).isTrue();
    }
}
```

**AuthControllerTest.java (이메일 인증 부분)**
```java
@WebMvcTest(AuthController.class)
@DisplayName("AuthController - 이메일 인증 테스트")
class AuthControllerEmailTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private EmailService emailService;

    @Test
    @DisplayName("POST /api/v1/auth/email/send - 인증 메일 발송")
    void sendVerificationEmail() throws Exception {
        // given
        EmailSendRequest request = new EmailSendRequest("user@example.com");

        // when & then
        mockMvc.perform(post("/api/v1/auth/email/send")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.message").value("인증 메일이 발송되었습니다"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/email/verify - 이메일 인증")
    void verifyEmail() throws Exception {
        // given
        String token = "valid-token";

        // when & then
        mockMvc.perform(get("/api/v1/auth/email/verify")
                .param("token", token))
            .andExpect(status().isFound())  // 302 Redirect
            .andExpect(header().exists("Location"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/email/status - 인증 상태 확인")
    void checkEmailStatus() throws Exception {
        // given
        String email = "user@example.com";
        when(emailService.isEmailVerified(email)).thenReturn(true);

        // when & then
        mockMvc.perform(get("/api/v1/auth/email/status")
                .param("email", email))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value(email))
            .andExpect(jsonPath("$.verified").value(true));
    }
}
```

### 6.2 Green: 구현

> ✅ **EmailVerification.java, EmailVerificationRepository.java** - Phase 02에서 완료됨
> - `sw-campus-domain/src/main/java/com/swcampus/domain/auth/EmailVerification.java`
> - `sw-campus-domain/src/main/java/com/swcampus/domain/auth/EmailVerificationRepository.java`

**EmailService.java**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class EmailService {

    private final EmailVerificationRepository emailVerificationRepository;
    private final MemberRepository memberRepository;
    private final MailSender mailSender;

    @Value("${app.frontend-url}")
    private String frontendUrl;

    public void sendVerificationEmail(String email) {
        // 이미 가입된 이메일 확인
        if (memberRepository.existsByEmail(email)) {
            throw new DuplicateEmailException();
        }

        // 기존 인증 정보 삭제 (재발송 대응)
        emailVerificationRepository.deleteByEmail(email);

        // 새 인증 생성
        EmailVerification verification = EmailVerification.create(email);
        emailVerificationRepository.save(verification);

        // 이메일 발송
        String verifyUrl = frontendUrl + "/auth/verify?token=" + verification.getToken();
        String subject = "[SW Campus] 이메일 인증";
        String content = buildEmailContent(verifyUrl);
        
        mailSender.send(email, subject, content);
    }

    public void verifyEmail(String token) {
        EmailVerification verification = emailVerificationRepository.findByToken(token)
            .orElseThrow(() -> new InvalidTokenException());
        
        verification.verify();
        emailVerificationRepository.save(verification);
    }

    @Transactional(readOnly = true)
    public boolean isEmailVerified(String email) {
        return emailVerificationRepository.findByEmailAndVerified(email, true).isPresent();
    }

    private String buildEmailContent(String verifyUrl) {
        return """
            <html>
            <body>
                <h2>SW Campus 이메일 인증</h2>
                <p>아래 버튼을 클릭하여 이메일 인증을 완료해주세요.</p>
                <a href="%s" style="display:inline-block;padding:10px 20px;background:#007bff;color:#fff;text-decoration:none;border-radius:5px;">
                    이메일 인증하기
                </a>
                <p>이 링크는 24시간 동안 유효합니다.</p>
            </body>
            </html>
            """.formatted(verifyUrl);
    }
}
```

**MailSender.java (Interface)**
```java
public interface MailSender {
    void send(String to, String subject, String content);
}
```

**SmtpMailSender.java**
```java
@Component
@RequiredArgsConstructor
public class SmtpMailSender implements MailSender {

    private final JavaMailSender javaMailSender;

    @Value("${spring.mail.username}")
    private String from;

    @Override
    public void send(String to, String subject, String content) {
        try {
            MimeMessage message = javaMailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            
            helper.setFrom(from);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(content, true);  // HTML

            javaMailSender.send(message);
        } catch (MessagingException e) {
            throw new MailSendException("이메일 발송에 실패했습니다", e);
        }
    }
}
```

**AuthController.java (이메일 인증 부분)**
```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final EmailService emailService;

    @PostMapping("/email/send")
    public ResponseEntity<Map<String, String>> sendVerificationEmail(
            @Valid @RequestBody EmailSendRequest request) {
        emailService.sendVerificationEmail(request.getEmail());
        return ResponseEntity.ok(Map.of("message", "인증 메일이 발송되었습니다"));
    }

    @GetMapping("/email/verify")
    public ResponseEntity<Void> verifyEmail(
            @RequestParam String token,
            @Value("${app.frontend-url}") String frontendUrl) {
        try {
            emailService.verifyEmail(token);
            return ResponseEntity.status(HttpStatus.FOUND)
                .header("Location", frontendUrl + "/signup?verified=true")
                .build();
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.FOUND)
                .header("Location", frontendUrl + "/signup?error=invalid_token")
                .build();
        }
    }

    @GetMapping("/email/status")
    public ResponseEntity<EmailStatusResponse> checkEmailStatus(
            @RequestParam String email) {
        boolean verified = emailService.isEmailVerified(email);
        return ResponseEntity.ok(new EmailStatusResponse(email, verified));
    }
}
```

**Request/Response DTOs**
```java
// EmailSendRequest.java
@Getter
@NoArgsConstructor
public class EmailSendRequest {
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    private String email;
}

// EmailStatusResponse.java
@Getter
@AllArgsConstructor
public class EmailStatusResponse {
    private String email;
    private boolean verified;
}
```

---

## 7. 검증

```bash
# 테스트 실행
./gradlew test --tests "*EmailVerification*"
./gradlew test --tests "*EmailService*"
./gradlew test --tests "*AuthController*Email*"

# API 수동 테스트
curl -X POST http://localhost:8080/api/v1/auth/email/send \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

curl -X GET "http://localhost:8080/api/v1/auth/email/status?email=test@example.com"
```

---

## 8. 산출물

| 파일 | 위치 | 설명 | 상태 |
|------|------|------|------|
| `EmailVerification.java` | domain | 이메일 인증 도메인 | ✅ Phase 02 완료 |
| `EmailVerificationRepository.java` | domain | Repository 인터페이스 | ✅ Phase 02 완료 |
| `EmailService.java` | domain | 이메일 인증 서비스 | 구현 예정 |
| `MailSender.java` | domain | 메일 발송 인터페이스 | 구현 예정 |
| `SmtpMailSender.java` | infra | SMTP 메일 발송 구현 | 구현 예정 |
| `EmailVerificationEntity.java` | infra | JPA Entity | ✅ Phase 02 완료 |
| `EmailVerificationJpaRepository.java` | infra | JPA Repository | ✅ Phase 02 완료 |
| `EmailVerificationRepositoryImpl.java` | infra | Repository 구현체 | ✅ Phase 02 완료 |
| `AuthController.java` | api | 인증 컨트롤러 | 구현 예정 |
| `EmailSendRequest.java` | api | 요청 DTO | 구현 예정 |
| `EmailStatusResponse.java` | api | 응답 DTO | 구현 예정 |

---

## 9. 다음 Phase

→ [Phase 05: 회원가입 - 일반](./phase05-signup.md)
