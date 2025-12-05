# Phase 10: OAuth

> 예상 시간: 4시간

## 1. 목표

Google, GitHub 소셜 로그인 기능을 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] SocialAccount 도메인 구현
- [ ] OAuth2 Client 설정 (Google, GitHub)
- [ ] 소셜 로그인 API 구현
- [ ] 신규 사용자 추가 정보 입력 API 구현
- [ ] 기존 회원 연동 처리
- [ ] 단위 테스트 및 통합 테스트 통과

---

## 3. 관련 기능

- 소셜 계정으로 로그인/회원가입
- 신규 사용자 추가 정보 입력
- 기존 이메일 계정과 소셜 계정 연동

---

## 4. API 명세

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/v1/auth/oauth/{provider}` | 소셜 로그인 (Google/GitHub) |
| PATCH | `/api/v1/auth/oauth/profile` | 추가 정보 입력 |

---

## 5. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── oauth/
        ├── OAuthService.java
        ├── OAuthProvider.java (enum)
        ├── OAuthUserInfo.java
        ├── SocialAccount.java
        └── SocialAccountRepository.java

sw-campus-infra/db-postgres/
└── src/main/java/com/swcampus/infra/postgres/
    └── oauth/
        ├── SocialAccountEntity.java
        ├── SocialAccountJpaRepository.java
        └── SocialAccountRepositoryImpl.java

sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── oauth/
        ├── OAuthController.java
        ├── OAuthClient.java
        ├── GoogleOAuthClient.java
        ├── GitHubOAuthClient.java
        ├── request/
        │   ├── OAuthCallbackRequest.java
        │   └── OAuthProfileRequest.java
        └── response/
            └── OAuthLoginResponse.java
```

---

## 6. 사전 준비

### 6.1 Google OAuth 설정

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. API 및 서비스 > OAuth 동의 화면 설정
4. 사용자 인증 정보 > OAuth 2.0 클라이언트 ID 생성
5. 승인된 리디렉션 URI: `http://localhost:3000/oauth/callback/google`

### 6.2 GitHub OAuth 설정

1. [GitHub Developer Settings](https://github.com/settings/developers) 접속
2. New OAuth App 클릭
3. Authorization callback URL: `http://localhost:3000/oauth/callback/github`

---

## 7. TDD Tasks

### 7.1 Red: 테스트 작성

**SocialAccountTest.java**
```java
@DisplayName("SocialAccount 도메인 테스트")
class SocialAccountTest {

    @Test
    @DisplayName("소셜 계정을 생성할 수 있다")
    void create() {
        // given
        Long userId = 1L;
        OAuthProvider provider = OAuthProvider.GOOGLE;
        String providerId = "google-user-id-123";

        // when
        SocialAccount account = SocialAccount.create(userId, provider, providerId);

        // then
        assertThat(account.getUserId()).isEqualTo(userId);
        assertThat(account.getProvider()).isEqualTo(OAuthProvider.GOOGLE);
        assertThat(account.getProviderId()).isEqualTo(providerId);
    }
}
```

**OAuthServiceTest.java**
```java
@ExtendWith(MockitoExtension.class)
@DisplayName("OAuthService 테스트")
class OAuthServiceTest {

    @Mock
    private MemberRepository memberRepository;
    
    @Mock
    private SocialAccountRepository socialAccountRepository;
    
    @Mock
    private RefreshTokenRepository refreshTokenRepository;
    
    @Mock
    private TokenProvider tokenProvider;

    @InjectMocks
    private OAuthService oAuthService;

    @Test
    @DisplayName("기존 소셜 계정으로 로그인한다")
    void loginWithExistingSocialAccount() {
        // given
        OAuthUserInfo userInfo = OAuthUserInfo.builder()
            .provider(OAuthProvider.GOOGLE)
            .providerId("google-123")
            .email("user@gmail.com")
            .name("홍길동")
            .build();

        SocialAccount socialAccount = mock(SocialAccount.class);
        when(socialAccount.getUserId()).thenReturn(1L);

        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn("user@gmail.com");
        when(member.getRole()).thenReturn(Role.USER);
        when(member.getNickname()).thenReturn("길동이");  // 프로필 완성됨

        when(socialAccountRepository.findByProviderAndProviderId(OAuthProvider.GOOGLE, "google-123"))
            .thenReturn(Optional.of(socialAccount));
        when(memberRepository.findById(1L)).thenReturn(Optional.of(member));
        when(tokenProvider.createAccessToken(any(), any(), any())).thenReturn("access-token");
        when(tokenProvider.createRefreshToken(any())).thenReturn("refresh-token");
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);

        // when
        OAuthLoginResult result = oAuthService.loginOrRegister(userInfo);

        // then
        assertThat(result.isNewUser()).isFalse();
        assertThat(result.getAccessToken()).isEqualTo("access-token");
    }

    @Test
    @DisplayName("신규 소셜 사용자를 등록한다")
    void registerNewSocialUser() {
        // given
        OAuthUserInfo userInfo = OAuthUserInfo.builder()
            .provider(OAuthProvider.GOOGLE)
            .providerId("google-123")
            .email("newuser@gmail.com")
            .name("신규유저")
            .build();

        when(socialAccountRepository.findByProviderAndProviderId(OAuthProvider.GOOGLE, "google-123"))
            .thenReturn(Optional.empty());
        when(memberRepository.findByEmail("newuser@gmail.com"))
            .thenReturn(Optional.empty());
        when(memberRepository.save(any(Member.class))).thenAnswer(i -> {
            Member m = i.getArgument(0);
            ReflectionTestUtils.setField(m, "id", 1L);
            return m;
        });
        when(tokenProvider.createAccessToken(any(), any(), any())).thenReturn("access-token");
        when(tokenProvider.createRefreshToken(any())).thenReturn("refresh-token");
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);

        // when
        OAuthLoginResult result = oAuthService.loginOrRegister(userInfo);

        // then
        assertThat(result.isNewUser()).isTrue();  // 추가 정보 입력 필요
        verify(memberRepository).save(any(Member.class));
        verify(socialAccountRepository).save(any(SocialAccount.class));
    }

    @Test
    @DisplayName("이미 가입된 이메일에 소셜 계정을 연동한다")
    void linkToExistingEmail() {
        // given
        OAuthUserInfo userInfo = OAuthUserInfo.builder()
            .provider(OAuthProvider.GITHUB)
            .providerId("github-456")
            .email("existing@example.com")
            .name("기존유저")
            .build();

        Member existingMember = mock(Member.class);
        when(existingMember.getId()).thenReturn(1L);
        when(existingMember.getEmail()).thenReturn("existing@example.com");
        when(existingMember.getRole()).thenReturn(Role.USER);
        when(existingMember.getNickname()).thenReturn("기존닉네임");

        when(socialAccountRepository.findByProviderAndProviderId(OAuthProvider.GITHUB, "github-456"))
            .thenReturn(Optional.empty());
        when(memberRepository.findByEmail("existing@example.com"))
            .thenReturn(Optional.of(existingMember));
        when(tokenProvider.createAccessToken(any(), any(), any())).thenReturn("access-token");
        when(tokenProvider.createRefreshToken(any())).thenReturn("refresh-token");
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);

        // when
        OAuthLoginResult result = oAuthService.loginOrRegister(userInfo);

        // then
        assertThat(result.isNewUser()).isFalse();  // 이미 프로필 있음
        verify(socialAccountRepository).save(any(SocialAccount.class));  // 소셜 연동
    }

    @Test
    @DisplayName("추가 정보를 입력하여 프로필을 완성한다")
    void completeProfile() {
        // given
        Long userId = 1L;
        String nickname = "새닉네임";
        String phone = "010-1234-5678";
        String location = "서울시 강남구";

        Member member = mock(Member.class);
        when(memberRepository.findById(userId)).thenReturn(Optional.of(member));

        // when
        oAuthService.completeProfile(userId, nickname, phone, location);

        // then
        verify(member).updateProfile(nickname, phone, location);
        verify(memberRepository).save(member);
    }
}
```

**OAuthControllerTest.java**
```java
@WebMvcTest(OAuthController.class)
@DisplayName("OAuthController 테스트")
class OAuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private OAuthService oAuthService;

    @MockBean
    private OAuthClientFactory oAuthClientFactory;

    @MockBean
    private TokenProvider tokenProvider;

    @MockBean
    private CookieUtil cookieUtil;

    @Test
    @DisplayName("POST /api/v1/auth/oauth/google - Google 로그인 성공")
    void googleLogin() throws Exception {
        // given
        OAuthCallbackRequest request = new OAuthCallbackRequest("google-auth-code");

        OAuthClient googleClient = mock(OAuthClient.class);
        OAuthUserInfo userInfo = OAuthUserInfo.builder()
            .provider(OAuthProvider.GOOGLE)
            .providerId("google-123")
            .email("user@gmail.com")
            .name("홍길동")
            .build();

        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn("user@gmail.com");
        when(member.getName()).thenReturn("홍길동");
        when(member.getRole()).thenReturn(Role.USER);

        OAuthLoginResult result = new OAuthLoginResult("access-token", "refresh-token", member, false);

        when(oAuthClientFactory.getClient(OAuthProvider.GOOGLE)).thenReturn(googleClient);
        when(googleClient.getUserInfo("google-auth-code")).thenReturn(userInfo);
        when(oAuthService.loginOrRegister(userInfo)).thenReturn(result);
        when(tokenProvider.getAccessTokenValidity()).thenReturn(3600L);
        when(tokenProvider.getRefreshTokenValidity()).thenReturn(86400L);
        when(cookieUtil.createAccessTokenCookie(any(), anyLong()))
            .thenReturn(ResponseCookie.from("accessToken", "access-token").build());
        when(cookieUtil.createRefreshTokenCookie(any(), anyLong()))
            .thenReturn(ResponseCookie.from("refreshToken", "refresh-token").build());

        // when & then
        mockMvc.perform(post("/api/v1/auth/oauth/google")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.userId").value(1))
            .andExpect(jsonPath("$.email").value("user@gmail.com"))
            .andExpect(jsonPath("$.isNewUser").value(false));
    }

    @Test
    @DisplayName("PATCH /api/v1/auth/oauth/profile - 추가 정보 입력")
    void completeProfile() throws Exception {
        // given
        OAuthProfileRequest request = new OAuthProfileRequest("길동이", "010-1234-5678", "서울시 강남구");

        when(tokenProvider.validateToken("valid-token")).thenReturn(true);
        when(tokenProvider.getUserId("valid-token")).thenReturn(1L);

        Member member = mock(Member.class);
        when(member.getId()).thenReturn(1L);
        when(member.getEmail()).thenReturn("user@gmail.com");
        when(member.getName()).thenReturn("홍길동");
        when(member.getNickname()).thenReturn("길동이");
        when(member.getRole()).thenReturn(Role.USER);

        when(oAuthService.completeProfile(1L, "길동이", "010-1234-5678", "서울시 강남구"))
            .thenReturn(member);

        // when & then
        mockMvc.perform(patch("/api/v1/auth/oauth/profile")
                .cookie(new Cookie("accessToken", "valid-token"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.nickname").value("길동이"));
    }
}
```

### 7.2 Green: 구현

**OAuthProvider.java**
```java
public enum OAuthProvider {
    GOOGLE,
    GITHUB
}
```

**OAuthUserInfo.java**
```java
@Getter
@Builder
public class OAuthUserInfo {
    private OAuthProvider provider;
    private String providerId;
    private String email;
    private String name;
}
```

**SocialAccount.java**
```java
@Getter
public class SocialAccount {
    private Long id;
    private Long userId;
    private OAuthProvider provider;
    private String providerId;
    private LocalDateTime createdAt;

    public static SocialAccount create(Long userId, OAuthProvider provider, String providerId) {
        SocialAccount account = new SocialAccount();
        account.userId = userId;
        account.provider = provider;
        account.providerId = providerId;
        account.createdAt = LocalDateTime.now();
        return account;
    }
}
```

**SocialAccountRepository.java**
```java
public interface SocialAccountRepository {
    SocialAccount save(SocialAccount socialAccount);
    Optional<SocialAccount> findByProviderAndProviderId(OAuthProvider provider, String providerId);
    List<SocialAccount> findByUserId(Long userId);
}
```

**OAuthLoginResult.java**
```java
@Getter
@AllArgsConstructor
public class OAuthLoginResult {
    private final String accessToken;
    private final String refreshToken;
    private final Member member;
    private final boolean isNewUser;
}
```

**OAuthService.java**
```java
@Service
@RequiredArgsConstructor
@Transactional
public class OAuthService {

    private final MemberRepository memberRepository;
    private final SocialAccountRepository socialAccountRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenProvider tokenProvider;

    public OAuthLoginResult loginOrRegister(OAuthUserInfo userInfo) {
        // 1. 소셜 계정으로 기존 회원 찾기
        Optional<SocialAccount> existingSocialAccount = socialAccountRepository
            .findByProviderAndProviderId(userInfo.getProvider(), userInfo.getProviderId());

        Member member;
        boolean isNewUser = false;

        if (existingSocialAccount.isPresent()) {
            // 기존 소셜 로그인 사용자
            member = memberRepository.findById(existingSocialAccount.get().getUserId())
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다"));
        } else {
            // 이메일로 기존 회원 찾기
            Optional<Member> existingMember = memberRepository.findByEmail(userInfo.getEmail());

            if (existingMember.isPresent()) {
                // 기존 이메일 계정에 소셜 연동
                member = existingMember.get();
                linkSocialAccount(member.getId(), userInfo);
            } else {
                // 신규 회원 생성
                member = createOAuthMember(userInfo);
                linkSocialAccount(member.getId(), userInfo);
                isNewUser = true;
            }
        }

        // 추가 정보 미입력 상태 확인
        if (member.getNickname() == null || member.getNickname().isBlank()) {
            isNewUser = true;
        }

        // 토큰 발급
        return issueTokens(member, isNewUser);
    }

    public Member completeProfile(Long userId, String nickname, String phone, String location) {
        Member member = memberRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다"));

        member.updateProfile(nickname, phone, location);
        return memberRepository.save(member);
    }

    private Member createOAuthMember(OAuthUserInfo userInfo) {
        Member member = Member.createOAuthUser(
            userInfo.getEmail(),
            userInfo.getName()
        );
        return memberRepository.save(member);
    }

    private void linkSocialAccount(Long userId, OAuthUserInfo userInfo) {
        SocialAccount socialAccount = SocialAccount.create(
            userId,
            userInfo.getProvider(),
            userInfo.getProviderId()
        );
        socialAccountRepository.save(socialAccount);
    }

    private OAuthLoginResult issueTokens(Member member, boolean isNewUser) {
        // 기존 RT 삭제
        refreshTokenRepository.deleteByUserId(member.getId());

        // 토큰 생성
        String accessToken = tokenProvider.createAccessToken(
            member.getId(), member.getEmail(), member.getRole());
        String refreshToken = tokenProvider.createRefreshToken(member.getId());

        // RT 저장
        RefreshToken refreshTokenEntity = RefreshToken.create(
            member.getId(),
            refreshToken,
            tokenProvider.getRefreshTokenValidity()
        );
        refreshTokenRepository.save(refreshTokenEntity);

        return new OAuthLoginResult(accessToken, refreshToken, member, isNewUser);
    }
}
```

**Member.java (OAuth 관련 메서드 추가)**
```java
@Getter
public class Member {
    // ... 기존 필드 ...

    public static Member createOAuthUser(String email, String name) {
        Member member = new Member();
        member.email = email;
        member.name = name;
        member.password = null;  // OAuth 사용자는 비밀번호 없음
        member.role = Role.USER;
        member.createdAt = LocalDateTime.now();
        member.updatedAt = LocalDateTime.now();
        return member;
    }

    public void updateProfile(String nickname, String phone, String location) {
        this.nickname = nickname;
        this.phone = phone;
        this.location = location;
        this.updatedAt = LocalDateTime.now();
    }
}
```

**OAuthClient.java (Interface)**
```java
public interface OAuthClient {
    OAuthUserInfo getUserInfo(String code);
}
```

**GoogleOAuthClient.java**
```java
@Component
@RequiredArgsConstructor
public class GoogleOAuthClient implements OAuthClient {

    private final RestTemplate restTemplate;

    @Value("${spring.security.oauth2.client.registration.google.client-id}")
    private String clientId;

    @Value("${spring.security.oauth2.client.registration.google.client-secret}")
    private String clientSecret;

    @Value("${app.oauth.google.redirect-uri}")
    private String redirectUri;

    @Override
    public OAuthUserInfo getUserInfo(String code) {
        // 1. Access Token 획득
        String accessToken = getAccessToken(code);

        // 2. 사용자 정보 조회
        return fetchUserInfo(accessToken);
    }

    private String getAccessToken(String code) {
        String tokenUrl = "https://oauth2.googleapis.com/token";

        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("code", code);
        params.add("client_id", clientId);
        params.add("client_secret", clientSecret);
        params.add("redirect_uri", redirectUri);
        params.add("grant_type", "authorization_code");

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(params, headers);

        ResponseEntity<Map> response = restTemplate.postForEntity(tokenUrl, request, Map.class);
        return (String) response.getBody().get("access_token");
    }

    private OAuthUserInfo fetchUserInfo(String accessToken) {
        String userInfoUrl = "https://www.googleapis.com/oauth2/v2/userinfo";

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);

        HttpEntity<Void> request = new HttpEntity<>(headers);

        ResponseEntity<Map> response = restTemplate.exchange(
            userInfoUrl, HttpMethod.GET, request, Map.class);

        Map<String, Object> body = response.getBody();

        return OAuthUserInfo.builder()
            .provider(OAuthProvider.GOOGLE)
            .providerId((String) body.get("id"))
            .email((String) body.get("email"))
            .name((String) body.get("name"))
            .build();
    }
}
```

**GitHubOAuthClient.java**
```java
@Component
@RequiredArgsConstructor
public class GitHubOAuthClient implements OAuthClient {

    private final RestTemplate restTemplate;

    @Value("${spring.security.oauth2.client.registration.github.client-id}")
    private String clientId;

    @Value("${spring.security.oauth2.client.registration.github.client-secret}")
    private String clientSecret;

    @Override
    public OAuthUserInfo getUserInfo(String code) {
        String accessToken = getAccessToken(code);
        return fetchUserInfo(accessToken);
    }

    private String getAccessToken(String code) {
        String tokenUrl = "https://github.com/login/oauth/access_token";

        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("code", code);
        params.add("client_id", clientId);
        params.add("client_secret", clientSecret);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        headers.setAccept(List.of(MediaType.APPLICATION_JSON));

        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(params, headers);

        ResponseEntity<Map> response = restTemplate.postForEntity(tokenUrl, request, Map.class);
        return (String) response.getBody().get("access_token");
    }

    private OAuthUserInfo fetchUserInfo(String accessToken) {
        String userInfoUrl = "https://api.github.com/user";

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);

        HttpEntity<Void> request = new HttpEntity<>(headers);

        ResponseEntity<Map> response = restTemplate.exchange(
            userInfoUrl, HttpMethod.GET, request, Map.class);

        Map<String, Object> body = response.getBody();

        // GitHub은 email이 별도 API
        String email = fetchEmail(accessToken);

        return OAuthUserInfo.builder()
            .provider(OAuthProvider.GITHUB)
            .providerId(String.valueOf(body.get("id")))
            .email(email)
            .name((String) body.get("name"))
            .build();
    }

    private String fetchEmail(String accessToken) {
        String emailUrl = "https://api.github.com/user/emails";

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);

        HttpEntity<Void> request = new HttpEntity<>(headers);

        ResponseEntity<List> response = restTemplate.exchange(
            emailUrl, HttpMethod.GET, request, List.class);

        return response.getBody().stream()
            .filter(e -> Boolean.TRUE.equals(((Map) e).get("primary")))
            .map(e -> (String) ((Map) e).get("email"))
            .findFirst()
            .orElse(null);
    }
}
```

**OAuthClientFactory.java**
```java
@Component
@RequiredArgsConstructor
public class OAuthClientFactory {

    private final GoogleOAuthClient googleOAuthClient;
    private final GitHubOAuthClient gitHubOAuthClient;

    public OAuthClient getClient(OAuthProvider provider) {
        return switch (provider) {
            case GOOGLE -> googleOAuthClient;
            case GITHUB -> gitHubOAuthClient;
        };
    }
}
```

**OAuthController.java**
```java
@RestController
@RequestMapping("/api/v1/auth/oauth")
@RequiredArgsConstructor
public class OAuthController {

    private final OAuthService oAuthService;
    private final OAuthClientFactory oAuthClientFactory;
    private final TokenProvider tokenProvider;
    private final CookieUtil cookieUtil;

    @PostMapping("/{provider}")
    public ResponseEntity<OAuthLoginResponse> oauthLogin(
            @PathVariable String provider,
            @Valid @RequestBody OAuthCallbackRequest request) {

        OAuthProvider oAuthProvider = OAuthProvider.valueOf(provider.toUpperCase());
        OAuthClient client = oAuthClientFactory.getClient(oAuthProvider);

        OAuthUserInfo userInfo = client.getUserInfo(request.getCode());
        OAuthLoginResult result = oAuthService.loginOrRegister(userInfo);

        ResponseCookie accessTokenCookie = cookieUtil.createAccessTokenCookie(
            result.getAccessToken(), tokenProvider.getAccessTokenValidity());
        ResponseCookie refreshTokenCookie = cookieUtil.createRefreshTokenCookie(
            result.getRefreshToken(), tokenProvider.getRefreshTokenValidity());

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, accessTokenCookie.toString())
            .header(HttpHeaders.SET_COOKIE, refreshTokenCookie.toString())
            .body(OAuthLoginResponse.from(result));
    }

    @PatchMapping("/profile")
    public ResponseEntity<OAuthProfileResponse> completeProfile(
            @CookieValue(name = "accessToken") String accessToken,
            @Valid @RequestBody OAuthProfileRequest request) {

        Long userId = tokenProvider.getUserId(accessToken);
        Member member = oAuthService.completeProfile(
            userId, 
            request.getNickname(), 
            request.getPhone(), 
            request.getLocation()
        );

        return ResponseEntity.ok(OAuthProfileResponse.from(member));
    }
}
```

**Request/Response DTOs**
```java
// OAuthCallbackRequest.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class OAuthCallbackRequest {
    @NotBlank(message = "인증 코드는 필수입니다")
    private String code;
}

// OAuthProfileRequest.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class OAuthProfileRequest {
    @NotBlank(message = "닉네임은 필수입니다")
    private String nickname;

    @NotBlank(message = "전화번호는 필수입니다")
    private String phone;

    @NotBlank(message = "주소는 필수입니다")
    private String location;
}

// OAuthLoginResponse.java
@Getter
@AllArgsConstructor
public class OAuthLoginResponse {
    private Long userId;
    private String email;
    private String name;
    private String role;
    private boolean isNewUser;

    public static OAuthLoginResponse from(OAuthLoginResult result) {
        Member member = result.getMember();
        return new OAuthLoginResponse(
            member.getId(),
            member.getEmail(),
            member.getName(),
            member.getRole().name(),
            result.isNewUser()
        );
    }
}

// OAuthProfileResponse.java
@Getter
@AllArgsConstructor
public class OAuthProfileResponse {
    private Long userId;
    private String email;
    private String name;
    private String nickname;
    private String role;

    public static OAuthProfileResponse from(Member member) {
        return new OAuthProfileResponse(
            member.getId(),
            member.getEmail(),
            member.getName(),
            member.getNickname(),
            member.getRole().name()
        );
    }
}
```

---

## 8. 검증

```bash
# 테스트 실행
./gradlew test --tests "*SocialAccount*"
./gradlew test --tests "*OAuthService*"
./gradlew test --tests "*OAuthController*"

# API 수동 테스트
# Google 로그인 (프론트에서 받은 code 사용)
curl -X POST http://localhost:8080/api/v1/auth/oauth/google \
  -H "Content-Type: application/json" \
  -d '{"code": "google-authorization-code"}' \
  -c cookies.txt

# 추가 정보 입력
curl -X PATCH http://localhost:8080/api/v1/auth/oauth/profile \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"nickname": "길동이", "phone": "010-1234-5678", "location": "서울시 강남구"}'
```

---

## 9. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `OAuthProvider.java` | domain | OAuth 제공자 enum |
| `OAuthUserInfo.java` | domain | OAuth 사용자 정보 |
| `SocialAccount.java` | domain | 소셜 계정 도메인 |
| `SocialAccountRepository.java` | domain | Repository 인터페이스 |
| `OAuthService.java` | domain | OAuth 서비스 |
| `OAuthLoginResult.java` | domain | 로그인 결과 |
| `SocialAccountEntity.java` | infra | JPA Entity |
| `GoogleOAuthClient.java` | api | Google OAuth 클라이언트 |
| `GitHubOAuthClient.java` | api | GitHub OAuth 클라이언트 |
| `OAuthController.java` | api | OAuth 컨트롤러 |

---

## 10. 다음 Phase

→ [Phase 11: 통합 테스트](./phase11-integration.md)
