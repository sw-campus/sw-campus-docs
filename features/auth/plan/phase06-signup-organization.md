# Phase 06: 회원가입 - 기관

> 예상 시간: 2시간
> **상태: ✅ 완료 (2025-12-08)**

## 1. 목표

기관(ORGANIZATION) 회원가입 기능과 S3 파일 업로드를 구현합니다.

**주요 변경사항:**
- 승인 상태(`approvalStatus`)와 재직증명서 URL(`certificateUrl`)을 **Organization 테이블**에서 관리
- Member는 `ROLE = ORGANIZATION`만 설정, 승인 상태는 Organization에서 관리

---

## 2. 완료 조건 (Definition of Done)

- [x] 기관 회원가입 API 구현 (multipart/form-data)
- [x] S3 파일 업로드 서비스 구현
- [x] 재직증명서 이미지 저장 (Organization.certificateUrl)
- [x] Organization 생성 및 approvalStatus=PENDING 설정
- [x] ApprovalStatus Enum 구현
- [x] Member의 orgId에 Organization FK 연결
- [x] 단위 테스트 및 통합 테스트 통과
- [x] 예외 처리 (CertificateRequiredException, MissingServletRequestPartException)
- [x] BaseEntity createdAt updatable=false 수정

---

## 3. 관련 User Stories

| US | 설명 |
|----|------|
| US-05 | 기관 담당자 재직증명서 업로드 |
| US-06 | 기관 가입 시 Organization 생성 (approvalStatus=PENDING) |
| US-07 | 미승인 상태에서 로그인 가능, 강의 등록 불가 |

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
    ├── storage/
    │   └── FileStorageService.java
    └── organization/
        ├── Organization.java (수정: approvalStatus, certificateUrl 추가)
        ├── OrganizationRepository.java
        └── ApprovalStatus.java (신규: Enum)

sw-campus-infra/
├── s3/
│   ├── build.gradle
│   ├── S3Config.java
│   └── S3FileStorageService.java
└── db-postgres/
    └── organization/
        └── OrganizationEntity.java (수정: approvalStatus, certificateUrl 추가)

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── auth/
        ├── request/
        │   └── OrganizationSignupRequest.java
        └── response/
            └── OrganizationSignupResponse.java
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
    private OrganizationRepository organizationRepository;
    
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
            .organizationName("테스트기관")
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
        when(organizationRepository.save(any(Organization.class))).thenAnswer(i -> {
            Organization org = i.getArgument(0);
            ReflectionTestUtils.setField(org, "id", 1L);
            return org;
        });

        // when
        OrganizationSignupResult result = authService.signupOrganization(command);

        // then
        assertThat(result.getMember().getRole()).isEqualTo(Role.ORGANIZATION);
        assertThat(result.getOrganization().getApprovalStatus()).isEqualTo(ApprovalStatus.PENDING);
        assertThat(result.getOrganization().getCertificateUrl()).isEqualTo("https://s3.../certificate.jpg");
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
            .organizationName("테스트기관")
            .certificateImage(null)  // 재직증명서 없음
            .build();

        // when & then
        assertThatThrownBy(() -> authService.signupOrganization(command))
            .isInstanceOf(CertificateRequiredException.class)
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

    @MockitoBean
    private AuthService authService;

    @MockitoBean
    private EmailService emailService;

    @Test
    @WithMockUser
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

        Organization organization = mock(Organization.class);
        when(organization.getId()).thenReturn(1L);
        when(organization.getName()).thenReturn("테스트기관");
        when(organization.getApprovalStatus()).thenReturn(ApprovalStatus.PENDING);

        OrganizationSignupResult result = new OrganizationSignupResult(member, organization);
        when(authService.signupOrganization(any())).thenReturn(result);

        // when & then
        mockMvc.perform(multipart("/api/v1/auth/signup/organization")
                .file(certificate)
                .param("email", "org@example.com")
                .param("password", "Password1!")
                .param("name", "김기관")
                .param("nickname", "기관담당자")
                .param("phone", "010-9876-5432")
                .param("location", "서울시 서초구")
                .param("organizationName", "테스트기관"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.userId").value(1))
            .andExpect(jsonPath("$.role").value("ORGANIZATION"))
            .andExpect(jsonPath("$.approvalStatus").value("PENDING"))
            .andExpect(jsonPath("$.organizationId").value(1));
    }

    @Test
    @WithMockUser
    @DisplayName("POST /api/v1/auth/signup/organization - 재직증명서 누락 시 실패")
    void signupOrganization_noCertificate() throws Exception {
        // when & then
        mockMvc.perform(multipart("/api/v1/auth/signup/organization")
                .param("email", "org@example.com")
                .param("password", "Password1!")
                .param("name", "김기관")
                .param("nickname", "기관담당자")
                .param("phone", "010-9876-5432")
                .param("location", "서울시 서초구")
                .param("organizationName", "테스트기관"))
            .andExpect(status().isBadRequest());
    }
}
```

### 6.2 Green: 구현

**ApprovalStatus.java (Domain Enum)**
```java
package com.swcampus.domain.organization;

import java.util.Arrays;

public enum ApprovalStatus {
    PENDING(0),    // 승인 대기
    APPROVED(1),   // 승인됨
    REJECTED(2);   // 반려됨

    private final int value;

    ApprovalStatus(int value) {
        this.value = value;
    }

    public int getValue() {
        return value;
    }

    public static ApprovalStatus fromValue(int value) {
        return Arrays.stream(values())
            .filter(s -> s.value == value)
            .findFirst()
            .orElse(PENDING);
    }
}
```

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
    private String organizationName;  // 기관명 추가
    private byte[] certificateImage;
    private String certificateFileName;
    private String certificateContentType;
}
```

**OrganizationSignupResult.java**
```java
@Getter
@AllArgsConstructor
public class OrganizationSignupResult {
    private final Member member;
    private final Organization organization;
}
```

**CertificateRequiredException.java**
```java
public class CertificateRequiredException extends RuntimeException {
    public CertificateRequiredException() {
        super("재직증명서는 필수입니다");
    }
}
```

**AuthService.java (기관 회원가입 추가)**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class AuthService {

    private final MemberRepository memberRepository;
    private final OrganizationRepository organizationRepository;
    private final EmailVerificationRepository emailVerificationRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordValidator passwordValidator;
    private final FileStorageService fileStorageService;

    // ... 기존 signup 메서드 ...

    public OrganizationSignupResult signupOrganization(OrganizationSignupCommand command) {
        // 1. 재직증명서 확인
        if (command.getCertificateImage() == null || command.getCertificateImage().length == 0) {
            throw new CertificateRequiredException();
        }

        // 2. 중복 이메일 검증
        if (memberRepository.existsByEmail(command.getEmail())) {
            throw new DuplicateEmailException(command.getEmail());
        }

        // 3. 이메일 인증 여부 확인
        emailVerificationRepository.findByEmailAndVerified(command.getEmail(), true)
            .orElseThrow(() -> new EmailNotVerifiedException(command.getEmail()));

        // 4. 비밀번호 정책 검증
        passwordValidator.validate(command.getPassword());

        // 5. 비밀번호 암호화
        String encodedPassword = passwordEncoder.encode(command.getPassword());

        // 6. 기관 담당자 생성 (ROLE = ORGANIZATION)
        Member member = Member.createOrganization(
            command.getEmail(),
            encodedPassword,
            command.getName(),
            command.getNickname(),
            command.getPhone(),
            command.getLocation()
        );
        Member savedMember = memberRepository.save(member);

        // 7. 재직증명서 S3 업로드
        String certificateUrl = fileStorageService.upload(
            command.getCertificateImage(),
            command.getCertificateFileName(),
            command.getCertificateContentType()
        );

        // 8. Organization 생성 (approvalStatus = PENDING)
        Organization organization = Organization.create(
            savedMember.getId(),
            command.getOrganizationName(),
            null,  // description
            certificateUrl
        );
        Organization savedOrganization = organizationRepository.save(organization);

        // 9. Member에 orgId 연결
        savedMember.setOrgId(savedOrganization.getId());
        memberRepository.save(savedMember);

        return new OrganizationSignupResult(savedMember, savedOrganization);
    }
}
```

**OrganizationSignupRequest.java**
```java
@Getter
@Setter
@NoArgsConstructor
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

    @NotBlank(message = "기관명은 필수입니다")
    private String organizationName;

    public OrganizationSignupCommand toCommand(MultipartFile certificateImage) throws IOException {
        return OrganizationSignupCommand.builder()
            .email(email)
            .password(password)
            .name(name)
            .nickname(nickname)
            .phone(phone)
            .location(location)
            .organizationName(organizationName)
            .certificateImage(certificateImage != null ? certificateImage.getBytes() : null)
            .certificateFileName(certificateImage != null ? certificateImage.getOriginalFilename() : null)
            .certificateContentType(certificateImage != null ? certificateImage.getContentType() : null)
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
    private Long organizationId;
    private String organizationName;
    private String approvalStatus;
    private String message;

    public static OrganizationSignupResponse from(OrganizationSignupResult result) {
        Member member = result.getMember();
        Organization organization = result.getOrganization();
        
        return new OrganizationSignupResponse(
            member.getId(),
            member.getEmail(),
            member.getName(),
            member.getNickname(),
            member.getRole().name(),
            organization.getId(),
            organization.getName(),
            organization.getApprovalStatus().name(),
            "기관 회원가입이 완료되었습니다. 관리자 승인 후 서비스 이용이 가능합니다."
        );
    }
}
```

**AuthController.java (기관 회원가입 추가)**
```java
@PostMapping(value = "/signup/organization", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<OrganizationSignupResponse> signupOrganization(
        @Valid @ModelAttribute OrganizationSignupRequest request,
        @RequestParam("certificateImage") MultipartFile certificateImage) throws IOException {
    
    OrganizationSignupResult result = authService.signupOrganization(request.toCommand(certificateImage));
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(OrganizationSignupResponse.from(result));
}
```

---

## 7. Organization 도메인 수정

**Organization.java에 approvalStatus, certificateUrl 필드 추가**
```java
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Organization {
    private Long id;
    private Long userId;
    private String name;
    private String description;
    private ApprovalStatus approvalStatus;  // 승인 상태 추가
    private String certificateUrl;           // 재직증명서 URL 추가
    private String govAuth;
    private String facilityImageUrl;
    private String facilityImageUrl2;
    private String facilityImageUrl3;
    private String facilityImageUrl4;
    private String logoUrl;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static Organization create(Long userId, String name, String description, String certificateUrl) {
        Organization org = new Organization();
        org.userId = userId;
        org.name = name;
        org.description = description;
        org.approvalStatus = ApprovalStatus.PENDING;  // 기본값: 대기
        org.certificateUrl = certificateUrl;
        org.createdAt = LocalDateTime.now();
        org.updatedAt = LocalDateTime.now();
        return org;
    }

    public void approve() {
        this.approvalStatus = ApprovalStatus.APPROVED;
        this.updatedAt = LocalDateTime.now();
    }

    public void reject() {
        this.approvalStatus = ApprovalStatus.REJECTED;
        this.updatedAt = LocalDateTime.now();
    }

    // ... 기존 메서드들 ...
}
```

**Member.java에서 orgAuth 필드 제거, setOrgId 메서드 추가**
```java
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member {
    private Long id;
    private String email;
    private String password;
    private String name;
    private String nickname;
    private String phone;
    private Role role;
    // private Integer orgAuth;  // 제거됨 -> Organization.approvalStatus로 이동
    private Long orgId;
    private String location;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static Member createOrganization(String email, String password,
                                            String name, String nickname,
                                            String phone, String location) {
        Member member = createUser(email, password, name, nickname, phone, location);
        member.role = Role.ORGANIZATION;
        // member.orgAuth = 0;  // 제거됨
        return member;
    }

    public void setOrgId(Long orgId) {
        this.orgId = orgId;
        this.updatedAt = LocalDateTime.now();
    }

    // ... 기존 메서드들 ...
}
```

---

## 8. Entity 수정

**OrganizationEntity.java에 approvalStatus, certificateUrl 필드 추가**
```java
@Entity
@Table(name = "organizations")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrganizationEntity extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "org_id")
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "org_name")
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "approval_status")
    private Integer approvalStatus;  // TINYINT

    @Column(name = "certificate_url", columnDefinition = "TEXT")
    private String certificateUrl;

    @Column(name = "gov_auth", length = 100)
    private String govAuth;

    // ... 기존 필드들 ...

    public static OrganizationEntity from(Organization organization) {
        OrganizationEntity entity = new OrganizationEntity();
        entity.id = organization.getId();
        entity.userId = organization.getUserId();
        entity.name = organization.getName();
        entity.description = organization.getDescription();
        entity.approvalStatus = organization.getApprovalStatus().getValue();
        entity.certificateUrl = organization.getCertificateUrl();
        entity.govAuth = organization.getGovAuth();
        // ... 기타 필드 ...
        return entity;
    }

    public Organization toDomain() {
        return Organization.of(
            id,
            userId,
            name,
            description,
            ApprovalStatus.fromValue(approvalStatus != null ? approvalStatus : 0),
            certificateUrl,
            govAuth,
            // ... 기타 필드 ...
            getCreatedAt(),
            getUpdatedAt()
        );
    }
}
```

**MemberEntity.java에서 orgAuth 컬럼 제거**
```java
@Entity
@Table(name = "members")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MemberEntity extends BaseEntity {

    // ... 기존 필드들 ...

    // @Column(name = "org_auth")
    // private Integer orgAuth;  // 제거됨

    @Column(name = "org_id")
    private Long orgId;

    // ... 기존 메서드들에서 orgAuth 관련 코드 제거 ...
}
```

---

## 9. 검증

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
  -F "organizationName=테스트기관" \
  -F "certificateImage=@/path/to/certificate.jpg"
```

---

## 10. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `ApprovalStatus.java` | domain/organization | 승인 상태 Enum |
| `FileStorageService.java` | domain/storage | 파일 저장 인터페이스 |
| `CertificateRequiredException.java` | domain/auth/exception | 재직증명서 필수 예외 |
| `S3Config.java` | infra/s3 | S3 설정 |
| `S3FileStorageService.java` | infra/s3 | S3 구현체 |
| `OrganizationSignupCommand.java` | domain/auth | 명령 객체 |
| `OrganizationSignupResult.java` | domain/auth | 결과 객체 |
| `OrganizationSignupRequest.java` | api/auth/request | 요청 DTO |
| `OrganizationSignupResponse.java` | api/auth/response | 응답 DTO |
| `Organization.java` | domain/organization | 도메인 (수정) |
| `OrganizationEntity.java` | infra/postgres | 엔티티 (수정) |
| `Member.java` | domain/member | 도메인 (수정: orgAuth 제거) |
| `MemberEntity.java` | infra/postgres | 엔티티 (수정: orgAuth 제거) |
| `BaseEntity.java` | infra/postgres | 엔티티 (수정: createdAt updatable=false) |
| `AuthController.java` | api/auth | 컨트롤러 (기관 추가) |
| `AuthService.java` | domain/auth | 서비스 (기관 추가) |
| `GlobalExceptionHandler.java` | api/exception | 예외 핸들러 (MissingServletRequestPartException 추가) |

---

## 11. DB 마이그레이션

```sql
-- organizations 테이블에 컬럼 추가
ALTER TABLE organizations ADD COLUMN approval_status TINYINT DEFAULT 0;
ALTER TABLE organizations ADD COLUMN certificate_url TEXT;

-- members 테이블에서 org_auth 컬럼 제거 (선택적 - 데이터 마이그레이션 후)
-- ALTER TABLE members DROP COLUMN org_auth;
```

---

## 12. 구현 보고서

→ [Phase 06 구현 보고서](../report/phase06-signup-organization.md)

---

## 13. 다음 Phase

→ [Phase 07: 로그인/로그아웃](./phase07-login.md)
