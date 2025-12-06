# Phase 05: 회원가입 - 일반

> 예상 시간: 1.5시간

## 1. 목표

일반 사용자(USER) 회원가입 기능을 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] 회원가입 API 구현
- [ ] 이메일 인증 여부 검증
- [ ] 비밀번호 암호화 (BCrypt)
- [ ] 중복 이메일 검증
- [ ] 비밀번호 정책 검증 (8자 이상, 특수문자 포함)
- [ ] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-06 | 이메일 인증 후 회원가입 진행 |
| US-07 | 비밀번호 규칙 안내 (8자 이상, 특수문자) |
| US-08 | 회원가입 완료 후 로그인 페이지 이동 |

---

## 4. API 명세

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/v1/auth/signup` | 일반 회원가입 |

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── auth/
        ├── AuthService.java
        └── PasswordValidator.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        ├── AuthController.java (추가)
        ├── request/
        │   └── SignupRequest.java
        └── response/
            └── SignupResponse.java
```

---

## 6. TDD Tasks

### 6.1 Red: 테스트 작성

**PasswordValidatorTest.java**
```java
@DisplayName("PasswordValidator 테스트")
class PasswordValidatorTest {

    private PasswordValidator validator = new PasswordValidator();

    @Test
    @DisplayName("유효한 비밀번호는 검증을 통과한다")
    void validPassword() {
        // given
        String password = "Password1!";

        // when & then
        assertThatNoException().isThrownBy(() -> validator.validate(password));
    }

    @Test
    @DisplayName("8자 미만 비밀번호는 검증에 실패한다")
    void tooShortPassword() {
        // given
        String password = "Pass1!";

        // when & then
        assertThatThrownBy(() -> validator.validate(password))
            .isInstanceOf(InvalidPasswordException.class);
    }

    @Test
    @DisplayName("특수문자가 없는 비밀번호는 검증에 실패한다")
    void noSpecialCharacter() {
        // given
        String password = "Password1";

        // when & then
        assertThatThrownBy(() -> validator.validate(password))
            .isInstanceOf(InvalidPasswordException.class);
    }
}
```

**AuthServiceTest.java (회원가입 부분)**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService - 회원가입 테스트")
class AuthServiceSignupTest {

    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private EmailVerificationRepository emailVerificationRepository;
    
    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private AuthService authService;

    @Test
    @DisplayName("일반 회원가입에 성공한다")
    void signup() {
        // given
        SignupCommand command = SignupCommand.builder()
            .email("user@example.com")
            .password("Password1!")
            .name("홍길동")
            .nickname("길동이")
            .phone("010-1234-5678")
            .location("서울시 강남구")
            .build();

        when(memberRepository.existsByEmail(command.getEmail())).thenReturn(false);
        when(emailVerificationRepository.findByEmailAndVerified(command.getEmail(), true))
            .thenReturn(Optional.of(mock(EmailVerification.class)));
        when(passwordEncoder.encode(command.getPassword())).thenReturn("encodedPassword");
        when(memberRepository.save(any(Member.class))).thenAnswer(i -> {
            Member m = i.getArgument(0);
            ReflectionTestUtils.setField(m, "id", 1L);
            return m;
        });

        // when
        Member member = authService.signup(command);

        // then
        assertThat(member.getId()).isEqualTo(1L);
        assertThat(member.getEmail()).isEqualTo("user@example.com");
        assertThat(member.getRole()).isEqualTo(Role.USER);
    }

    @Test
    @DisplayName("이메일 인증 없이 회원가입 시 실패한다")
    void signup_emailNotVerified() {
        // given
        SignupCommand command = SignupCommand.builder()
            .email("user@example.com")
            .password("Password1!")
            .name("홍길동")
            .nickname("길동이")
            .phone("010-1234-5678")
            .location("서울시 강남구")
            .build();

        when(memberRepository.existsByEmail(command.getEmail())).thenReturn(false);
        when(emailVerificationRepository.findByEmailAndVerified(command.getEmail(), true))
            .thenReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> authService.signup(command))
            .isInstanceOf(EmailNotVerifiedException.class);
    }

    @Test
    @DisplayName("이미 가입된 이메일로 회원가입 시 실패한다")
    void signup_duplicateEmail() {
        // given
        SignupCommand command = SignupCommand.builder()
            .email("user@example.com")
            .password("Password1!")
            .name("홍길동")
            .nickname("길동이")
            .phone("010-1234-5678")
            .location("서울시 강남구")
            .build();

        when(memberRepository.existsByEmail(command.getEmail())).thenReturn(true);

        // when & then
        assertThatThrownBy(() -> authService.signup(command))
            .isInstanceOf(DuplicateEmailException.class);
    }
}
```

**AuthControllerSignupTest.java**
```java
@WebMvcTest(AuthController.class)
@DisplayName("AuthController - 회원가입 테스트")
class AuthControllerSignupTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;

    @Test
    @DisplayName("POST /api/v1/auth/signup - 회원가입 성공")
    void signup() throws Exception {
        // given
        SignupRequest request = SignupRequest.builder()
            .email("user@example.com")
            .password("Password1!")
            .name("홍길동")
            .nickname("길동이")
            .phone("010-1234-5678")
            .location("서울시 강남구")
            .build();

        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn("user@example.com");
        when(member.getName()).thenReturn("홍길동");
        when(member.getNickname()).thenReturn("길동이");
        when(member.getRole()).thenReturn(Role.USER);
        when(authService.signup(any())).thenReturn(member);

        // when & then
        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.userId").value(1))
            .andExpect(jsonPath("$.email").value("user@example.com"))
            .andExpect(jsonPath("$.role").value("USER"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/signup - 유효성 검증 실패")
    void signup_validationFailed() throws Exception {
        // given
        SignupRequest request = SignupRequest.builder()
            .email("invalid-email")  // 잘못된 이메일
            .password("short")       // 짧은 비밀번호
            .name("")                // 빈 이름
            .build();

        // when & then
        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest());
    }
}
```

### 6.2 Green: 구현

**PasswordValidator.java**
```java
@Component
public class PasswordValidator {

    private static final int MIN_LENGTH = 8;
    private static final Pattern SPECIAL_CHAR_PATTERN = Pattern.compile("[!@#$%^&*(),.?\":{}|<>]");

    public void validate(String password) {
        if (password == null || password.length() < MIN_LENGTH) {
            throw new InvalidPasswordException("비밀번호는 " + MIN_LENGTH + "자 이상이어야 합니다");
        }

        if (!SPECIAL_CHAR_PATTERN.matcher(password).find()) {
            throw new InvalidPasswordException("비밀번호에 특수문자가 1개 이상 포함되어야 합니다");
        }
    }
}
```

**SignupCommand.java**
```java
@Getter
@Builder
public class SignupCommand {
    private String email;
    private String password;
    private String name;
    private String nickname;
    private String phone;
    private String location;
}
```

**AuthService.java (회원가입 부분)**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class AuthService {

    private final MemberRepository memberRepository;
    private final EmailVerificationRepository emailVerificationRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordValidator passwordValidator;

    public Member signup(SignupCommand command) {
        // 1. 중복 이메일 검증
        if (memberRepository.existsByEmail(command.getEmail())) {
            throw new DuplicateEmailException();
        }

        // 2. 이메일 인증 여부 확인
        emailVerificationRepository.findByEmailAndVerified(command.getEmail(), true)
            .orElseThrow(EmailNotVerifiedException::new);

        // 3. 비밀번호 정책 검증
        passwordValidator.validate(command.getPassword());

        // 4. 비밀번호 암호화
        String encodedPassword = passwordEncoder.encode(command.getPassword());

        // 5. 회원 생성
        Member member = Member.createUser(
            command.getEmail(),
            encodedPassword,
            command.getName(),
            command.getNickname(),
            command.getPhone(),
            command.getLocation()
        );

        return memberRepository.save(member);
    }
}
```

**SignupRequest.java**
```java
@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SignupRequest {
    
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    private String email;

    @NotBlank(message = "비밀번호는 필수입니다")
    private String password;

    @NotBlank(message = "이름은 필수입니다")
    private String name;

    @NotBlank(message = "닉네임은 필수입니다")
    private String nickname;

    @NotBlank(message = "전화번호는 필수입니다")
    private String phone;

    @NotBlank(message = "주소는 필수입니다")
    private String location;

    public SignupCommand toCommand() {
        return SignupCommand.builder()
            .email(email)
            .password(password)
            .name(name)
            .nickname(nickname)
            .phone(phone)
            .location(location)
            .build();
    }
}
```

**SignupResponse.java**
```java
@Getter
@AllArgsConstructor
public class SignupResponse {
    private Long userId;
    private String email;
    private String name;
    private String nickname;
    private String role;

    public static SignupResponse from(Member member) {
        return new SignupResponse(
            member.getId(),
            member.getEmail(),
            member.getName(),
            member.getNickname(),
            member.getRole().name()
        );
    }
}
```

**AuthController.java (회원가입 추가)**
```java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final EmailService emailService;

    // ... 이메일 인증 API ...

    @PostMapping("/signup")
    public ResponseEntity<SignupResponse> signup(
            @Valid @RequestBody SignupRequest request) {
        Member member = authService.signup(request.toCommand());
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(SignupResponse.from(member));
    }
}
```

---

## 7. 예외 클래스

**InvalidPasswordException.java**
```java
public class InvalidPasswordException extends RuntimeException {
    public InvalidPasswordException(String message) {
        super(message);
    }
}
```

**EmailNotVerifiedException.java**
```java
public class EmailNotVerifiedException extends RuntimeException {
    public EmailNotVerifiedException() {
        super("이메일 인증이 완료되지 않았습니다");
    }
}
```

**DuplicateEmailException.java**
```java
public class DuplicateEmailException extends RuntimeException {
    public DuplicateEmailException() {
        super("이미 가입된 이메일입니다");
    }
}
```

---

## 8. 검증

```bash
# 테스트 실행
./gradlew test --tests "*PasswordValidator*"
./gradlew test --tests "*AuthService*Signup*"
./gradlew test --tests "*AuthController*Signup*"

# API 수동 테스트
curl -X POST http://localhost:8080/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "Password1!",
    "name": "홍길동",
    "nickname": "길동이",
    "phone": "010-1234-5678",
    "location": "서울시 강남구"
  }'
```

---

## 9. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `PasswordValidator.java` | domain | 비밀번호 검증기 |
| `SignupCommand.java` | domain | 회원가입 명령 객체 |
| `AuthService.java` | domain | 인증 서비스 (회원가입 추가) |
| `SignupRequest.java` | api | 회원가입 요청 DTO |
| `SignupResponse.java` | api | 회원가입 응답 DTO |
| `AuthController.java` | api | 컨트롤러 (회원가입 추가) |
| `InvalidPasswordException.java` | domain | 예외 클래스 |
| `EmailNotVerifiedException.java` | domain | 예외 클래스 |
| `DuplicateEmailException.java` | domain | 예외 클래스 |

---

## 10. 다음 Phase

→ [Phase 06: 회원가입 - 기관](./phase06-signup-organization.md)
