# Phase 06: 회원가입 - 기관

> 예상 시간: 1.5시간

## 1. 목표

기관(ORGANIZATION) 회원가입 기능과 S3 파일 업로드를 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] 기관 회원가입 API 구현 (multipart/form-data)
- [ ] S3 파일 업로드 서비스 구현
- [ ] 재직증명서 이미지 저장
- [ ] ORGANIZATION Role 및 ORG_AUTH=0 설정
- [ ] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-09 | 기관 담당자 재직증명서 업로드 |
| US-10 | 기관 가입 후 승인 대기 안내 |

---

## 4. API 명세

| Method | Endpoint | Content-Type | 설명 |
|--------|----------|--------------|------|
| POST | `/api/v1/auth/signup/organization` | multipart/form-data | 기관 회원가입 |

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── storage/
        └── FileStorageService.java

sw-campus-infra/
└── s3/
    ├── S3Config.java
    └── S3FileStorageService.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        └── request/
            └── OrganizationSignupRequest.java
```

---

## 6. TDD Tasks

### 6.1 Red: 테스트 작성

**S3FileStorageServiceTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("S3FileStorageService 테스트")
class S3FileStorageServiceTest {

    @Mock
    private S3Client s3Client;

    @InjectMocks
    private S3FileStorageService fileStorageService;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(fileStorageService, "bucketName", "test-bucket");
        ReflectionTestUtils.setField(fileStorageService, "region", "ap-northeast-2");
    }

    @Test
    @DisplayName("파일을 S3에 업로드할 수 있다")
    void upload() {
        // given
        byte[] content = "test content".getBytes();
        String fileName = "test.jpg";
        String contentType = "image/jpeg";

        // when
        String url = fileStorageService.upload(content, fileName, contentType);

        // then
        assertThat(url).contains("test-bucket");
        assertThat(url).contains(".jpg");
        verify(s3Client).putObject(any(PutObjectRequest.class), any(RequestBody.class));
    }

    @Test
    @DisplayName("파일 확장자가 유지된다")
    void uploadWithExtension() {
        // given
        byte[] content = "test content".getBytes();
        String fileName = "document.pdf";

        // when
        String url = fileStorageService.upload(content, fileName, "application/pdf");

        // then
        assertThat(url).endsWith(".pdf");
    }
}
```

**AuthServiceOrganizationSignupTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService - 기관 회원가입 테스트")
class AuthServiceOrganizationSignupTest {

    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private EmailVerificationRepository emailVerificationRepository;
    
    @Mock
    private PasswordEncoder passwordEncoder;
    
    @Mock
    private FileStorageService fileStorageService;

    @InjectMocks
    private AuthService authService;

    @Test
    @DisplayName("기관 회원가입에 성공한다")
    void signupOrganization() {
        // given
        byte[] imageContent = "fake image".getBytes();
        OrganizationSignupCommand command = OrganizationSignupCommand.builder()
            .email("org@example.com")
            .password("Password1!")
            .name("김기관")
            .nickname("기관담당자")
            .phone("010-9876-5432")
            .location("서울시 서초구")
            .certificateImage(imageContent)
            .certificateFileName("certificate.jpg")
            .certificateContentType("image/jpeg")
            .build();

        when(memberRepository.existsByEmail(command.getEmail())).thenReturn(false);
        when(emailVerificationRepository.findByEmailAndVerified(command.getEmail(), true))
            .thenReturn(Optional.of(mock(EmailVerification.class)));
        when(passwordEncoder.encode(command.getPassword())).thenReturn("encodedPassword");
        when(fileStorageService.upload(any(), any(), any()))
            .thenReturn("https://s3.../certificate.jpg");
        when(memberRepository.save(any(Member.class))).thenAnswer(i -> {
            Member m = i.getArgument(0);
            ReflectionTestUtils.setField(m, "id", 1L);
            return m;
        });

        // when
        Member member = authService.signupOrganization(command);

        // then
        assertThat(member.getRole()).isEqualTo(Role.ORGANIZATION);
        assertThat(member.getOrgAuth()).isEqualTo(0);  // 미승인
        verify(fileStorageService).upload(imageContent, "certificate.jpg", "image/jpeg");
    }

    @Test
    @DisplayName("재직증명서 없이 기관 가입 시 실패한다")
    void signupOrganization_noCertificate() {
        // given
        OrganizationSignupCommand command = OrganizationSignupCommand.builder()
            .email("org@example.com")
            .password("Password1!")
            .name("김기관")
            .nickname("기관담당자")
            .phone("010-9876-5432")
            .location("서울시 서초구")
            .certificateImage(null)  // 재직증명서 없음
            .build();

        // when & then
        assertThatThrownBy(() -> authService.signupOrganization(command))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("재직증명서");
    }
}
```

**AuthControllerOrganizationSignupTest.java**
```java
@WebMvcTest(AuthController.class)
@DisplayName("AuthController - 기관 회원가입 테스트")
class AuthControllerOrganizationSignupTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AuthService authService;

    @Test
    @DisplayName("POST /api/v1/auth/signup/organization - 기관 회원가입 성공")
    void signupOrganization() throws Exception {
        // given
        MockMultipartFile certificate = new MockMultipartFile(
            "certificateImage",
            "certificate.jpg",
            MediaType.IMAGE_JPEG_VALUE,
            "fake image content".getBytes()
        );

        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn("org@example.com");
        when(member.getName()).thenReturn("김기관");
        when(member.getNickname()).thenReturn("기관담당자");
        when(member.getRole()).thenReturn(Role.ORGANIZATION);
        when(member.getOrgAuth()).thenReturn(0);
        when(authService.signupOrganization(any())).thenReturn(member);

        // when & then
        mockMvc.perform(multipart("/api/v1/auth/signup/organization")
                .file(certificate)
                .param("email", "org@example.com")
                .param("password", "Password1!")
                .param("name", "김기관")
                .param("nickname", "기관담당자")
                .param("phone", "010-9876-5432")
                .param("location", "서울시 서초구"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.userId").value(1))
            .andExpect(jsonPath("$.role").value("ORGANIZATION"))
            .andExpect(jsonPath("$.orgAuth").value(0));
    }

    @Test
    @DisplayName("POST /api/v1/auth/signup/organization - 재직증명서 누락 시 실패")
    void signupOrganization_noCertificate() throws Exception {
        // when & then
        mockMvc.perform(multipart("/api/v1/auth/signup/organization")
                .param("email", "org@example.com")
                .param("password", "Password1!")
                .param("name", "김기관")
                .param("nickname", "기관담당자")
                .param("phone", "010-9876-5432")
                .param("location", "서울시 서초구"))
            .andExpect(status().isBadRequest());
    }
}
```

### 6.2 Green: 구현

**FileStorageService.java (Domain Interface)**
```java
public interface FileStorageService {
    /**
     * 파일을 저장하고 접근 URL을 반환
     */
    String upload(byte[] content, String fileName, String contentType);
    
    /**
     * 파일 삭제
     */
    void delete(String fileUrl);
}
```

**S3Config.java**
```java
@Configuration
public class S3Config {

    @Value("${aws.credentials.access-key}")
    private String accessKey;

    @Value("${aws.credentials.secret-key}")
    private String secretKey;

    @Value("${aws.s3.region}")
    private String region;

    @Bean
    public S3Client s3Client() {
        AwsBasicCredentials credentials = AwsBasicCredentials.create(accessKey, secretKey);
        
        return S3Client.builder()
            .region(Region.of(region))
            .credentialsProvider(StaticCredentialsProvider.create(credentials))
            .build();
    }
}
```

**S3FileStorageService.java**
```java
@Service
@RequiredArgsConstructor
public class S3FileStorageService implements FileStorageService {

    private final S3Client s3Client;

    @Value("${aws.s3.bucket}")
    private String bucketName;

    @Value("${aws.s3.region}")
    private String region;

    @Override
    public String upload(byte[] content, String fileName, String contentType) {
        String key = generateKey(fileName);

        PutObjectRequest request = PutObjectRequest.builder()
            .bucket(bucketName)
            .key(key)
            .contentType(contentType)
            .build();

        s3Client.putObject(request, RequestBody.fromBytes(content));

        return String.format("https://%s.s3.%s.amazonaws.com/%s", bucketName, region, key);
    }

    @Override
    public void delete(String fileUrl) {
        String key = extractKeyFromUrl(fileUrl);
        
        DeleteObjectRequest request = DeleteObjectRequest.builder()
            .bucket(bucketName)
            .key(key)
            .build();

        s3Client.deleteObject(request);
    }

    private String generateKey(String fileName) {
        String extension = getExtension(fileName);
        String uuid = UUID.randomUUID().toString();
        String date = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));
        
        return String.format("certificates/%s/%s%s", date, uuid, extension);
    }

    private String getExtension(String fileName) {
        int dotIndex = fileName.lastIndexOf('.');
        return dotIndex > 0 ? fileName.substring(dotIndex) : "";
    }

    private String extractKeyFromUrl(String url) {
        // https://bucket.s3.region.amazonaws.com/key -> key
        return url.substring(url.indexOf(".com/") + 5);
    }
}
```

**OrganizationSignupCommand.java**
```java
@Getter
@Builder
public class OrganizationSignupCommand {
    private String email;
    private String password;
    private String name;
    private String nickname;
    private String phone;
    private String location;
    private byte[] certificateImage;
    private String certificateFileName;
    private String certificateContentType;
}
```

**AuthService.java (기관 회원가입 추가)**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class AuthService {

    private final MemberRepository memberRepository;
    private final EmailVerificationRepository emailVerificationRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordValidator passwordValidator;
    private final FileStorageService fileStorageService;

    // ... 기존 signup 메서드 ...

    public Member signupOrganization(OrganizationSignupCommand command) {
        // 1. 재직증명서 확인
        if (command.getCertificateImage() == null || command.getCertificateImage().length == 0) {
            throw new IllegalArgumentException("재직증명서는 필수입니다");
        }

        // 2. 중복 이메일 검증
        if (memberRepository.existsByEmail(command.getEmail())) {
            throw new DuplicateEmailException();
        }

        // 3. 이메일 인증 여부 확인
        emailVerificationRepository.findByEmailAndVerified(command.getEmail(), true)
            .orElseThrow(EmailNotVerifiedException::new);

        // 4. 비밀번호 정책 검증
        passwordValidator.validate(command.getPassword());

        // 5. 재직증명서 S3 업로드
        String certificateUrl = fileStorageService.upload(
            command.getCertificateImage(),
            command.getCertificateFileName(),
            command.getCertificateContentType()
        );

        // 6. 비밀번호 암호화
        String encodedPassword = passwordEncoder.encode(command.getPassword());

        // 7. 기관 담당자 생성 (ORG_AUTH = 0: 미승인)
        Member member = Member.createOrganization(
            command.getEmail(),
            encodedPassword,
            command.getName(),
            command.getNickname(),
            command.getPhone(),
            command.getLocation()
        );
        // 재직증명서 URL 저장 (Member에 필드 추가 필요)
        member.setCertificateUrl(certificateUrl);

        return memberRepository.save(member);
    }
}
```

**OrganizationSignupRequest.java**
```java
@Getter
@Setter
public class OrganizationSignupRequest {
    
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

    public OrganizationSignupCommand toCommand(MultipartFile certificateImage) throws IOException {
        return OrganizationSignupCommand.builder()
            .email(email)
            .password(password)
            .name(name)
            .nickname(nickname)
            .phone(phone)
            .location(location)
            .certificateImage(certificateImage.getBytes())
            .certificateFileName(certificateImage.getOriginalFilename())
            .certificateContentType(certificateImage.getContentType())
            .build();
    }
}
```

**OrganizationSignupResponse.java**
```java
@Getter
@AllArgsConstructor
public class OrganizationSignupResponse {
    private Long userId;
    private String email;
    private String name;
    private String nickname;
    private String role;
    private Integer orgAuth;

    public static OrganizationSignupResponse from(Member member) {
        return new OrganizationSignupResponse(
            member.getId(),
            member.getEmail(),
            member.getName(),
            member.getNickname(),
            member.getRole().name(),
            member.getOrgAuth()
        );
    }
}
```

**AuthController.java (기관 회원가입 추가)**
```java
@PostMapping("/signup/organization")
public ResponseEntity<OrganizationSignupResponse> signupOrganization(
        @Valid @ModelAttribute OrganizationSignupRequest request,
        @RequestParam("certificateImage") MultipartFile certificateImage) throws IOException {
    
    if (certificateImage.isEmpty()) {
        throw new IllegalArgumentException("재직증명서는 필수입니다");
    }

    Member member = authService.signupOrganization(request.toCommand(certificateImage));
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(OrganizationSignupResponse.from(member));
}
```

---

## 7. Member 도메인 수정

**Member.java에 certificateUrl 필드 추가**
```java
@Getter
public class Member {
    // ... 기존 필드 ...
    private String certificateUrl;  // 재직증명서 URL 추가

    public void setCertificateUrl(String certificateUrl) {
        this.certificateUrl = certificateUrl;
    }
}
```

---

## 8. 검증

```bash
# 테스트 실행
./gradlew test --tests "*S3FileStorageService*"
./gradlew test --tests "*AuthService*Organization*"
./gradlew test --tests "*AuthController*Organization*"

# API 수동 테스트
curl -X POST http://localhost:8080/api/v1/auth/signup/organization \
  -F "email=org@example.com" \
  -F "password=Password1!" \
  -F "name=김기관" \
  -F "nickname=기관담당자" \
  -F "phone=010-9876-5432" \
  -F "location=서울시 서초구" \
  -F "certificateImage=@/path/to/certificate.jpg"
```

---

## 9. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `FileStorageService.java` | domain | 파일 저장 인터페이스 |
| `S3Config.java` | infra | S3 설정 |
| `S3FileStorageService.java` | infra | S3 구현체 |
| `OrganizationSignupCommand.java` | domain | 명령 객체 |
| `OrganizationSignupRequest.java` | api | 요청 DTO |
| `OrganizationSignupResponse.java` | api | 응답 DTO |
| `AuthController.java` | api | 컨트롤러 (기관 추가) |
| `AuthService.java` | domain | 서비스 (기관 추가) |

---

## 10. 다음 Phase

→ [Phase 07: 로그인/로그아웃](./phase07-login.md)
