# Phase 02: Auth Entity 도메인

> 예상 시간: 3시간

## 1. 목표

Auth 기능에 필요한 모든 Entity를 구현하여 다른 개발자와 협업할 수 있는 기반을 마련합니다.

---

## 2. 완료 조건 (Definition of Done)

### Member (완료 ✅)
- [x] Member 도메인 객체 구현
- [x] MemberRepository 인터페이스 정의 (domain)
- [x] MemberEntity 및 JPA Repository 구현 (infra)
- [x] Role enum 정의

### Organization (완료 ✅)
- [x] Organization 도메인 객체 구현
- [x] OrganizationRepository 인터페이스 정의 (domain)
- [x] OrganizationEntity 및 JPA Repository 구현 (infra)

### EmailVerification (완료 ✅)
- [x] EmailVerification 도메인 객체 구현
- [x] EmailVerificationRepository 인터페이스 정의 (domain)
- [x] EmailVerificationEntity 및 JPA Repository 구현 (infra)

### RefreshToken (완료 ✅)
- [x] RefreshToken 도메인 객체 구현
- [x] RefreshTokenRepository 인터페이스 정의 (domain)
- [x] RefreshTokenEntity 및 JPA Repository 구현 (infra)

### 공통
- [x] 단위 테스트 통과
- [x] 빌드 검증

---

## 3. 관련 User Stories

- 모든 US의 기반이 되는 도메인

---

## 4. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    ├── member/
    │   ├── Member.java ✅
    │   ├── MemberRepository.java ✅
    │   └── Role.java ✅
    ├── organization/
    │   ├── Organization.java (NEW)
    │   └── OrganizationRepository.java (NEW)
    └── auth/
        ├── EmailVerification.java (NEW)
        ├── EmailVerificationRepository.java (NEW)
        ├── RefreshToken.java (NEW)
        └── RefreshTokenRepository.java (NEW)

sw-campus-infra/db-postgres/
└── src/main/java/com/swcampus/infra/postgres/
    ├── member/
    │   ├── MemberEntity.java ✅
    │   ├── MemberJpaRepository.java ✅
    │   └── MemberRepositoryImpl.java ✅
    ├── organization/
    │   ├── OrganizationEntity.java (NEW)
    │   ├── OrganizationJpaRepository.java (NEW)
    │   └── OrganizationRepositoryImpl.java (NEW)
    └── auth/
        ├── EmailVerificationEntity.java (NEW)
        ├── EmailVerificationJpaRepository.java (NEW)
        ├── EmailVerificationRepositoryImpl.java (NEW)
        ├── RefreshTokenEntity.java (NEW)
        ├── RefreshTokenJpaRepository.java (NEW)
        └── RefreshTokenRepositoryImpl.java (NEW)
```

---

## 5. 데이터베이스 스키마

### 5.1 MEMBERS (구현 완료 ✅)

```sql
CREATE TYPE member_role AS ENUM ('USER', 'ORGANIZATION', 'ADMIN');

CREATE TABLE MEMBERS (
    USER_ID BIGSERIAL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL UNIQUE,
    PASSWORD VARCHAR(255),
    NAME VARCHAR(255) NOT NULL,
    NICKNAME VARCHAR(255) NOT NULL,
    PHONE VARCHAR(255) NOT NULL,
    ROLE member_role NOT NULL DEFAULT 'USER',
    ORG_AUTH SMALLINT DEFAULT NULL,      -- null: 일반회원, 0: 미승인, 1: 승인
    ORG_ID BIGINT REFERENCES ORGANIZATIONS(ORG_ID),
    LOCATION VARCHAR(255),
    CERTIFICATE_URL VARCHAR(500),         -- 재직증명서 URL
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 5.2 ORGANIZATIONS (NEW)

```sql
CREATE TABLE ORGANIZATIONS (
    ORG_ID BIGSERIAL PRIMARY KEY,
    USER_ID BIGINT NOT NULL REFERENCES MEMBERS(USER_ID),  -- 기관 소유자
    ORG_NAME TEXT,
    DESCRIPTION TEXT,
    GOV_AUTH VARCHAR(100),                -- 정부 인증
    FACILITY_IMAGE_URL TEXT,
    FACILITY_IMAGE_URL2 TEXT,
    FACILITY_IMAGE_URL3 TEXT,
    FACILITY_IMAGE_URL4 TEXT,
    ORG_LOGO_URL TEXT,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 5.3 EMAIL_VERIFICATIONS (NEW)

```sql
CREATE TABLE EMAIL_VERIFICATIONS (
    ID BIGSERIAL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL,
    CODE VARCHAR(6) NOT NULL,              -- 6자리 인증 코드
    VERIFIED BOOLEAN DEFAULT FALSE,
    EXPIRES_AT TIMESTAMP NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_email_verifications_email ON EMAIL_VERIFICATIONS(EMAIL);
```

### 5.4 REFRESH_TOKENS (NEW)

```sql
CREATE TABLE REFRESH_TOKENS (
    ID BIGSERIAL PRIMARY KEY,
    USER_ID BIGINT NOT NULL UNIQUE REFERENCES MEMBERS(USER_ID) ON DELETE CASCADE,
    TOKEN VARCHAR(500) NOT NULL UNIQUE,
    EXPIRES_AT TIMESTAMP NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_refresh_tokens_token ON REFRESH_TOKENS(TOKEN);
```

---

## 6. Entity 구현 (Domain)

### 6.1 Organization

**Organization.java**
```java
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Organization {
    private Long id;
    private Long userId;                  // 기관 소유자 ID
    private String name;
    private String description;
    private String govAuth;               // 정부 인증
    private String facilityImageUrl;
    private String facilityImageUrl2;
    private String facilityImageUrl3;
    private String facilityImageUrl4;
    private String logoUrl;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static Organization create(Long userId, String name, String description) {
        Organization org = new Organization();
        org.userId = userId;
        org.name = name;
        org.description = description;
        org.createdAt = LocalDateTime.now();
        org.updatedAt = LocalDateTime.now();
        return org;
    }

    public static Organization of(Long id, Long userId, String name, String description,
                                  String govAuth, String facilityImageUrl,
                                  String facilityImageUrl2, String facilityImageUrl3,
                                  String facilityImageUrl4, String logoUrl,
                                  LocalDateTime createdAt, LocalDateTime updatedAt) {
        Organization org = new Organization();
        org.id = id;
        org.userId = userId;
        org.name = name;
        org.description = description;
        org.govAuth = govAuth;
        org.facilityImageUrl = facilityImageUrl;
        org.facilityImageUrl2 = facilityImageUrl2;
        org.facilityImageUrl3 = facilityImageUrl3;
        org.facilityImageUrl4 = facilityImageUrl4;
        org.logoUrl = logoUrl;
        org.createdAt = createdAt;
        org.updatedAt = updatedAt;
        return org;
    }

    public void updateInfo(String name, String description) {
        this.name = name;
        this.description = description;
        this.updatedAt = LocalDateTime.now();
    }

    public void updateFacilityImages(String url1, String url2, String url3, String url4) {
        this.facilityImageUrl = url1;
        this.facilityImageUrl2 = url2;
        this.facilityImageUrl3 = url3;
        this.facilityImageUrl4 = url4;
        this.updatedAt = LocalDateTime.now();
    }

    public void updateLogoUrl(String logoUrl) {
        this.logoUrl = logoUrl;
        this.updatedAt = LocalDateTime.now();
    }

    public void setGovAuth(String govAuth) {
        this.govAuth = govAuth;
        this.updatedAt = LocalDateTime.now();
    }
}
```

**OrganizationRepository.java**
```java
public interface OrganizationRepository {
    Organization save(Organization organization);
    Optional<Organization> findById(Long id);
    Optional<Organization> findByUserId(Long userId);
    boolean existsByUserId(Long userId);
}
```

### 6.2 EmailVerification

**EmailVerification.java**
```java
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class EmailVerification {
    private Long id;
    private String email;
    private String code;
    private boolean verified;
    private LocalDateTime expiresAt;
    private LocalDateTime createdAt;

    private static final int EXPIRATION_MINUTES = 5;

    public static EmailVerification create(String email, String code) {
        EmailVerification ev = new EmailVerification();
        ev.email = email;
        ev.code = code;
        ev.verified = false;
        ev.expiresAt = LocalDateTime.now().plusMinutes(EXPIRATION_MINUTES);
        ev.createdAt = LocalDateTime.now();
        return ev;
    }

    public static EmailVerification of(Long id, String email, String code,
                                       boolean verified, LocalDateTime expiresAt,
                                       LocalDateTime createdAt) {
        EmailVerification ev = new EmailVerification();
        ev.id = id;
        ev.email = email;
        ev.code = code;
        ev.verified = verified;
        ev.expiresAt = expiresAt;
        ev.createdAt = createdAt;
        return ev;
    }

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }

    public void verify() {
        if (isExpired()) {
            throw new IllegalStateException("인증 코드가 만료되었습니다");
        }
        this.verified = true;
    }

    public boolean matchCode(String inputCode) {
        return this.code.equals(inputCode);
    }
}
```

**EmailVerificationRepository.java**
```java
public interface EmailVerificationRepository {
    EmailVerification save(EmailVerification emailVerification);
    Optional<EmailVerification> findByEmail(String email);
    Optional<EmailVerification> findByEmailAndVerified(String email, boolean verified);
    void deleteByEmail(String email);
}
```

### 6.3 RefreshToken

**RefreshToken.java**
```java
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RefreshToken {
    private Long id;
    private Long memberId;
    private String token;
    private LocalDateTime expiresAt;
    private LocalDateTime createdAt;

    public static RefreshToken create(Long memberId, String token, long expirationSeconds) {
        RefreshToken rt = new RefreshToken();
        rt.memberId = memberId;
        rt.token = token;
        rt.expiresAt = LocalDateTime.now().plusSeconds(expirationSeconds);
        rt.createdAt = LocalDateTime.now();
        return rt;
    }

    public static RefreshToken of(Long id, Long memberId, String token,
                                  LocalDateTime expiresAt, LocalDateTime createdAt) {
        RefreshToken rt = new RefreshToken();
        rt.id = id;
        rt.memberId = memberId;
        rt.token = token;
        rt.expiresAt = expiresAt;
        rt.createdAt = createdAt;
        return rt;
    }

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }

    public void updateToken(String newToken, long expirationSeconds) {
        this.token = newToken;
        this.expiresAt = LocalDateTime.now().plusSeconds(expirationSeconds);
    }
}
```

**RefreshTokenRepository.java**
```java
public interface RefreshTokenRepository {
    RefreshToken save(RefreshToken refreshToken);
    Optional<RefreshToken> findByMemberId(Long memberId);
    Optional<RefreshToken> findByToken(String token);
    void deleteByMemberId(Long memberId);
}
```

---

## 7. Entity 구현 (Infra)

### 7.1 OrganizationEntity

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

    @Column(name = "gov_auth", length = 100)
    private String govAuth;

    @Column(name = "facility_image_url", columnDefinition = "TEXT")
    private String facilityImageUrl;

    @Column(name = "facility_image_url2", columnDefinition = "TEXT")
    private String facilityImageUrl2;

    @Column(name = "facility_image_url3", columnDefinition = "TEXT")
    private String facilityImageUrl3;

    @Column(name = "facility_image_url4", columnDefinition = "TEXT")
    private String facilityImageUrl4;

    @Column(name = "org_logo_url", columnDefinition = "TEXT")
    private String logoUrl;

    public static OrganizationEntity from(Organization org) { ... }
    public Organization toDomain() { ... }
}
```

### 7.2 EmailVerificationEntity

```java
@Entity
@Table(name = "email_verifications")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class EmailVerificationEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String email;

    @Column(nullable = false)
    private String code;

    @Column(nullable = false)
    private boolean verified;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public static EmailVerificationEntity from(EmailVerification ev) { ... }
    public EmailVerification toDomain() { ... }
}
```

### 7.3 RefreshTokenEntity

```java
@Entity
@Table(name = "refresh_tokens")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RefreshTokenEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false, unique = true)
    private Long memberId;

    @Column(nullable = false, unique = true)
    private String token;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public static RefreshTokenEntity from(RefreshToken rt) { ... }
    public RefreshToken toDomain() { ... }
}
```

---

## 8. 검증

```bash
# 빌드 확인
./gradlew build -x test

# 테스트 실행
./gradlew test

# 특정 테스트만 실행
./gradlew test --tests "*OrganizationTest*"
./gradlew test --tests "*EmailVerificationTest*"
./gradlew test --tests "*RefreshTokenTest*"
```

---

## 9. 산출물

| 파일 | 위치 | 상태 |
|------|------|------|
| `Role.java` | domain/member | ✅ 완료 |
| `Member.java` | domain/member | ✅ 완료 |
| `MemberRepository.java` | domain/member | ✅ 완료 |
| `MemberEntity.java` | infra/member | ✅ 완료 |
| `MemberJpaRepository.java` | infra/member | ✅ 완료 |
| `MemberRepositoryImpl.java` | infra/member | ✅ 완료 |
| `Organization.java` | domain/organization | ✅ 완료 |
| `OrganizationRepository.java` | domain/organization | ✅ 완료 |
| `OrganizationEntity.java` | infra/organization | ✅ 완료 |
| `OrganizationJpaRepository.java` | infra/organization | ✅ 완료 |
| `OrganizationRepositoryImpl.java` | infra/organization | ✅ 완료 |
| `EmailVerification.java` | domain/auth | ✅ 완료 |
| `EmailVerificationRepository.java` | domain/auth | ✅ 완료 |
| `EmailVerificationEntity.java` | infra/auth | ✅ 완료 |
| `EmailVerificationJpaRepository.java` | infra/auth | ✅ 완료 |
| `EmailVerificationRepositoryImpl.java` | infra/auth | ✅ 완료 |
| `RefreshToken.java` | domain/auth | ✅ 완료 |
| `RefreshTokenRepository.java` | domain/auth | ✅ 완료 |
| `RefreshTokenEntity.java` | infra/auth | ✅ 완료 |
| `RefreshTokenJpaRepository.java` | infra/auth | ✅ 완료 |
| `RefreshTokenRepositoryImpl.java` | infra/auth | ✅ 완료 |

---

## 10. Member 수정 사항

Member에 `certificateUrl` 필드 추가 필요:

```java
// Member.java
private String certificateUrl;  // 재직증명서 URL

public void setCertificateUrl(String certificateUrl) {
    this.certificateUrl = certificateUrl;
    this.updatedAt = LocalDateTime.now();
}
```

---

## 11. 다음 Phase

→ [Phase 03: Security + JWT](./phase03-security.md)
