# Phase 11: 통합 테스트

> 예상 시간: 2시간

## 1. 목표

전체 Auth 기능의 통합 테스트를 작성하고, 코드 품질을 점검합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] E2E 시나리오 테스트 통과
- [ ] 테스트 커버리지 90% 이상
- [ ] 모든 API 엔드포인트 동작 확인
- [ ] 에러 케이스 처리 확인
- [ ] 코드 리뷰 완료

---

## 3. 통합 테스트 시나리오

### 3.1 일반 회원 시나리오

```
1. 이메일 인증 발송 → 인증 완료 → 상태 확인
2. 회원가입 (이메일 인증 필수)
3. 로그인 → JWT 쿠키 발급
4. 인증이 필요한 API 호출
5. Access Token 만료 → Refresh
6. 비밀번호 변경
7. 로그아웃
8. 비밀번호 찾기 → 재설정
```

### 3.2 교육제공자 시나리오

```
1. 이메일 인증 발송 → 인증 완료
2. 교육제공자 회원가입 (재직증명서 업로드)
3. 로그인 → orgAuth: 0 (미승인) 확인
4. (Admin이 승인 후) orgAuth: 1 확인
```

### 3.3 OAuth 시나리오

```
1. Google 로그인 (신규) → needsProfileCompletion: true
2. 추가 정보 입력
3. 로그아웃
4. Google 로그인 (기존) → needsProfileCompletion: false
5. GitHub 로그인 (동일 이메일) → 계정 연동
```

---

## 4. 통합 테스트 코드

### 4.1 회원가입 ~ 로그인 플로우

**AuthIntegrationTest.java**
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@Transactional
@DisplayName("Auth 통합 테스트")
class AuthIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private EmailVerificationRepository emailVerificationRepository;

    @MockBean
    private MailSender mailSender;  // 실제 메일 발송 Mock

    @Test
    @DisplayName("일반 회원 가입 플로우: 이메일 인증 → 회원가입 → 로그인 → 로그아웃")
    void userSignupAndLoginFlow() throws Exception {
        String email = "newuser@example.com";
        String password = "Password1!";

        // 1. 이메일 인증 발송
        mockMvc.perform(post("/api/v1/auth/email/send")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "%s"}
                    """.formatted(email)))
            .andExpect(status().isOk());

        verify(mailSender).send(eq(email), anyString(), anyString());

        // 2. 이메일 인증 상태 확인 (아직 미인증)
        mockMvc.perform(get("/api/v1/auth/email/status")
                .param("email", email))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.verified").value(false));

        // 3. 이메일 인증 처리 (직접 DB 업데이트 - 실제로는 이메일 링크 클릭)
        EmailVerification verification = emailVerificationRepository
            .findByEmailAndVerified(email, false).orElseThrow();
        verification.verify();
        emailVerificationRepository.save(verification);

        // 4. 이메일 인증 상태 확인 (인증 완료)
        mockMvc.perform(get("/api/v1/auth/email/status")
                .param("email", email))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.verified").value(true));

        // 5. 회원가입
        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "email": "%s",
                        "password": "%s",
                        "name": "홍길동",
                        "nickname": "길동이",
                        "phone": "010-1234-5678",
                        "location": "서울시 강남구"
                    }
                    """.formatted(email, password)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.email").value(email))
            .andExpect(jsonPath("$.role").value("USER"));

        // 6. 로그인
        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "%s", "password": "%s"}
                    """.formatted(email, password)))
            .andExpect(status().isOk())
            .andExpect(header().exists("Set-Cookie"))
            .andExpect(jsonPath("$.email").value(email))
            .andReturn();

        // 쿠키 추출
        Cookie accessTokenCookie = loginResult.getResponse().getCookie("accessToken");
        Cookie refreshTokenCookie = loginResult.getResponse().getCookie("refreshToken");
        assertThat(accessTokenCookie).isNotNull();
        assertThat(refreshTokenCookie).isNotNull();

        // 7. 로그아웃
        mockMvc.perform(post("/api/v1/auth/logout")
                .cookie(accessTokenCookie, refreshTokenCookie))
            .andExpect(status().isOk())
            .andExpect(cookie().maxAge("accessToken", 0))
            .andExpect(cookie().maxAge("refreshToken", 0));
    }

    @Test
    @DisplayName("이메일 미인증 시 회원가입 실패")
    void signupWithoutEmailVerification() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                        "email": "unverified@example.com",
                        "password": "Password1!",
                        "name": "홍길동",
                        "nickname": "길동이",
                        "phone": "010-1234-5678",
                        "location": "서울시 강남구"
                    }
                    """))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("AUTH006"));
    }

    @Test
    @DisplayName("잘못된 비밀번호로 로그인 실패")
    void loginWithWrongPassword() throws Exception {
        // 사전 조건: 가입된 사용자
        setupVerifiedUser("existing@example.com", "Password1!");

        mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "existing@example.com", "password": "WrongPassword!"}
                    """))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("AUTH003"));
    }

    private void setupVerifiedUser(String email, String password) {
        // 테스트용 사용자 생성 헬퍼 메서드
        // ...
    }
}
```

### 4.2 토큰 갱신 테스트

**TokenRefreshIntegrationTest.java**
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@Transactional
@DisplayName("토큰 갱신 통합 테스트")
class TokenRefreshIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private TokenProvider tokenProvider;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Test
    @DisplayName("유효한 Refresh Token으로 Access Token 갱신")
    void refreshWithValidToken() throws Exception {
        // Given: 로그인된 사용자
        Long userId = 1L;
        String refreshToken = tokenProvider.createRefreshToken(userId);
        refreshTokenRepository.save(RefreshToken.create(userId, refreshToken, 86400L));

        // When & Then
        mockMvc.perform(post("/api/v1/auth/refresh")
                .cookie(new Cookie("refreshToken", refreshToken)))
            .andExpect(status().isOk())
            .andExpect(cookie().exists("accessToken"));
    }

    @Test
    @DisplayName("만료된 Refresh Token으로 갱신 실패")
    void refreshWithExpiredToken() throws Exception {
        // Given: 만료된 토큰
        Long userId = 1L;
        String refreshToken = tokenProvider.createRefreshToken(userId);
        RefreshToken expiredToken = RefreshToken.create(userId, refreshToken, 0L);
        refreshTokenRepository.save(expiredToken);

        // When & Then
        mockMvc.perform(post("/api/v1/auth/refresh")
                .cookie(new Cookie("refreshToken", refreshToken)))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("AUTH004"));
    }

    @Test
    @DisplayName("다른 기기 로그인 후 기존 Refresh Token 무효화")
    void refreshAfterAnotherLogin() throws Exception {
        // Given: 기존 로그인
        Long userId = 1L;
        String oldRefreshToken = tokenProvider.createRefreshToken(userId);
        refreshTokenRepository.save(RefreshToken.create(userId, oldRefreshToken, 86400L));

        // 다른 기기에서 로그인 (새 RT 발급)
        String newRefreshToken = tokenProvider.createRefreshToken(userId);
        refreshTokenRepository.deleteByUserId(userId);
        refreshTokenRepository.save(RefreshToken.create(userId, newRefreshToken, 86400L));

        // When: 기존 토큰으로 갱신 시도
        mockMvc.perform(post("/api/v1/auth/refresh")
                .cookie(new Cookie("refreshToken", oldRefreshToken)))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("AUTH005"));
    }
}
```

### 4.3 비밀번호 관리 테스트

**PasswordIntegrationTest.java**
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@Transactional
@DisplayName("비밀번호 관리 통합 테스트")
class PasswordIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private TokenProvider tokenProvider;

    @MockBean
    private MailSender mailSender;

    @Test
    @DisplayName("비밀번호 변경 플로우")
    void changePasswordFlow() throws Exception {
        // Given: 로그인된 사용자
        Long userId = 1L;
        String accessToken = tokenProvider.createAccessToken(userId, "user@example.com", Role.USER);

        // When & Then
        mockMvc.perform(patch("/api/v1/auth/password")
                .cookie(new Cookie("accessToken", accessToken))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"currentPassword": "OldPassword1!", "newPassword": "NewPassword1!"}
                    """))
            .andExpect(status().isOk());
    }

    @Test
    @DisplayName("비밀번호 재설정 플로우")
    void resetPasswordFlow() throws Exception {
        // 1. 재설정 요청
        mockMvc.perform(post("/api/v1/auth/password/reset-request")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email": "user@example.com"}
                    """))
            .andExpect(status().isOk());

        verify(mailSender).send(eq("user@example.com"), anyString(), anyString());

        // 2. 재설정 (토큰은 DB에서 조회 필요)
        // ...
    }
}
```

---

## 5. 테스트 커버리지 확인

```bash
# 전체 테스트 실행 및 커버리지 리포트 생성
./gradlew test jacocoTestReport

# 커버리지 리포트 확인
open build/reports/jacoco/test/html/index.html
```

**커버리지 목표:**
- Line Coverage: 90% 이상
- Branch Coverage: 85% 이상

---

## 6. API 엔드포인트 체크리스트

| API | Method | 테스트 | 상태 |
|-----|--------|--------|------|
| `/api/v1/auth/email/send` | POST | ✅ | |
| `/api/v1/auth/email/verify` | GET | ✅ | |
| `/api/v1/auth/email/status` | GET | ✅ | |
| `/api/v1/auth/signup` | POST | ✅ | |
| `/api/v1/auth/signup/provider` | POST | ✅ | |
| `/api/v1/auth/login` | POST | ✅ | |
| `/api/v1/auth/logout` | POST | ✅ | |
| `/api/v1/auth/refresh` | POST | ✅ | |
| `/api/v1/auth/password` | PATCH | ✅ | |
| `/api/v1/auth/password/reset-request` | POST | ✅ | |
| `/api/v1/auth/password/reset` | POST | ✅ | |
| `/api/v1/auth/oauth/{provider}` | POST | ✅ | |
| `/api/v1/auth/oauth/profile` | PATCH | ✅ | |

---

## 7. 최종 검증

### 7.1 수동 테스트

```bash
# 1. 애플리케이션 실행
./gradlew :sw-campus-api:bootRun

# 2. Postman 또는 curl로 전체 플로우 테스트
# (각 Phase의 검증 섹션 참고)
```

### 7.2 코드 품질 검사

```bash
# 정적 분석 (선택)
./gradlew checkstyleMain
./gradlew spotbugsMain
```

---

## 8. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `AuthIntegrationTest.java` | api/test | 회원가입/로그인 통합 테스트 |
| `TokenRefreshIntegrationTest.java` | api/test | 토큰 갱신 통합 테스트 |
| `PasswordIntegrationTest.java` | api/test | 비밀번호 관리 통합 테스트 |
| `OAuthIntegrationTest.java` | api/test | OAuth 통합 테스트 |

---

## 9. 완료 후 작업

1. **커밋**: `feat(auth): Phase 11 - 통합 테스트 완료`
2. **PR 생성**: 전체 Auth 기능 코드 리뷰
3. **문서 업데이트**: `report.md` 작성 (구현 결과 보고서)
4. **진행 현황 업데이트**: `plan/README.md`의 Progress Bar 100%로 변경

---

## 10. 프로젝트 완료!

🎉 **Auth 기능 개발 완료**

**구현된 기능:**
- ✅ 이메일 인증 (발송/검증/상태확인)
- ✅ 회원가입 (일반/교육제공자)
- ✅ 로그인/로그아웃
- ✅ JWT 토큰 관리 (Access/Refresh)
- ✅ 비밀번호 변경/재설정
- ✅ OAuth (Google/GitHub)

**테스트 커버리지:** 90%+

→ [Implementation Report](../report.md) 작성으로 이동
