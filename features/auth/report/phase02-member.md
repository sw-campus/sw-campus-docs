# Phase 02: Auth Entity 도메인 - 구현 보고서

> 작성일: 2025-12-05 (최종 수정: 2025-12-06)
> 소요 시간: 약 2시간

---

## 1. 완료 항목

### Member (✅ 완료)

| Task | 상태 | 비고 |
|------|------|------|
| Role enum 정의 | ✅ | USER, ORGANIZATION, ADMIN |
| Member 도메인 객체 | ✅ | 정적 팩토리 메서드 패턴 |
| MemberRepository 인터페이스 | ✅ | domain 모듈 |
| MemberEntity | ✅ | BaseEntity 상속 |
| MemberJpaRepository | ✅ | Spring Data JPA |
| MemberRepositoryImpl | ✅ | Repository 구현체 |
| MemberTest | ✅ | 도메인 단위 테스트 (3개) |
| MemberRepositoryTest | ✅ | 통합 테스트 (5개) |

### Organization (✅ 완료)

| Task | 상태 | 비고 |
|------|------|------|
| Organization 도메인 객체 | ✅ | 정적 팩토리 메서드 패턴 |
| OrganizationRepository 인터페이스 | ✅ | domain 모듈 |
| OrganizationEntity | ✅ | BaseEntity 상속 |
| OrganizationJpaRepository | ✅ | Spring Data JPA |
| OrganizationRepositoryImpl | ✅ | Repository 구현체 |
| OrganizationTest | ✅ | 도메인 단위 테스트 (5개) |
| OrganizationRepositoryTest | ✅ | 통합 테스트 (4개) |

### EmailVerification (✅ 완료)

| Task | 상태 | 비고 |
|------|------|------|
| EmailVerification 도메인 객체 | ✅ | 정적 팩토리 메서드 패턴 |
| EmailVerificationRepository 인터페이스 | ✅ | domain 모듈 |
| EmailVerificationEntity | ✅ | JPA Entity |
| EmailVerificationJpaRepository | ✅ | Spring Data JPA |
| EmailVerificationRepositoryImpl | ✅ | Repository 구현체 |
| EmailVerificationTest | ✅ | 도메인 단위 테스트 (4개) |
| EmailVerificationRepositoryTest | ✅ | 통합 테스트 (2개) |

### RefreshToken (✅ 완료)

| Task | 상태 | 비고 |
|------|------|------|
| RefreshToken 도메인 객체 | ✅ | 정적 팩토리 메서드 패턴 |
| RefreshTokenRepository 인터페이스 | ✅ | domain 모듈 |
| RefreshTokenEntity | ✅ | JPA Entity |
| RefreshTokenJpaRepository | ✅ | Spring Data JPA |
| RefreshTokenRepositoryImpl | ✅ | Repository 구현체 |
| RefreshTokenTest | ✅ | 도메인 단위 테스트 (3개) |
| RefreshTokenRepositoryTest | ✅ | 통합 테스트 (3개) |

### 공통

| Task | 상태 |
|------|------|
| 단위 테스트 통과 | ✅ |
| 빌드 검증 | ✅ |

---

## 2. 변경 파일 목록

### 신규 생성 - Member

| 파일 | 모듈 | 설명 |
|------|------|------|
| `Role.java` | domain | 역할 enum |
| `Member.java` | domain | 회원 도메인 객체 |
| `MemberRepository.java` | domain | Repository 인터페이스 |
| `MemberTest.java` | domain/test | 도메인 단위 테스트 |
| `MemberEntity.java` | infra/db-postgres | JPA Entity |
| `MemberJpaRepository.java` | infra/db-postgres | JPA Repository |
| `MemberRepositoryImpl.java` | infra/db-postgres | Repository 구현체 |
| `MemberRepositoryTest.java` | infra/db-postgres/test | Repository 통합 테스트 |

### 신규 생성 - Organization

| 파일 | 모듈 | 설명 |
|------|------|------|
| `Organization.java` | domain | 기관 도메인 객체 |
| `OrganizationRepository.java` | domain | Repository 인터페이스 |
| `OrganizationTest.java` | domain/test | 도메인 단위 테스트 |
| `OrganizationEntity.java` | infra/db-postgres | JPA Entity |
| `OrganizationJpaRepository.java` | infra/db-postgres | JPA Repository |
| `OrganizationRepositoryImpl.java` | infra/db-postgres | Repository 구현체 |
| `OrganizationRepositoryTest.java` | infra/db-postgres/test | Repository 통합 테스트 |

### 신규 생성 - EmailVerification

| 파일 | 모듈 | 설명 |
|------|------|------|
| `EmailVerification.java` | domain | 이메일 인증 도메인 객체 |
| `EmailVerificationRepository.java` | domain | Repository 인터페이스 |
| `EmailVerificationTest.java` | domain/test | 도메인 단위 테스트 |
| `EmailVerificationEntity.java` | infra/db-postgres | JPA Entity |
| `EmailVerificationJpaRepository.java` | infra/db-postgres | JPA Repository |
| `EmailVerificationRepositoryImpl.java` | infra/db-postgres | Repository 구현체 |
| `EmailVerificationRepositoryTest.java` | infra/db-postgres/test | Repository 통합 테스트 |

### 신규 생성 - RefreshToken

| 파일 | 모듈 | 설명 |
|------|------|------|
| `RefreshToken.java` | domain | 리프레시 토큰 도메인 객체 |
| `RefreshTokenRepository.java` | domain | Repository 인터페이스 |
| `RefreshTokenTest.java` | domain/test | 도메인 단위 테스트 |
| `RefreshTokenEntity.java` | infra/db-postgres | JPA Entity |
| `RefreshTokenJpaRepository.java` | infra/db-postgres | JPA Repository |
| `RefreshTokenRepositoryImpl.java` | infra/db-postgres | Repository 구현체 |
| `RefreshTokenRepositoryTest.java` | infra/db-postgres/test | Repository 통합 테스트 |

### 신규 생성 - 공통

| 파일 | 모듈 | 설명 |
|------|------|------|
| `TestApplication.java` | infra/db-postgres/test | 테스트용 Spring Boot 설정 |
| `application-test.yml` | infra/db-postgres/test | 테스트 DB 설정 (H2) |

### 수정

| 파일 | 변경 내용 |
|------|----------|
| `build.gradle` (루트) | 공통 테스트 의존성 추가 |
| `sw-campus-domain/build.gradle` | 중복 테스트 의존성 제거 |
| `sw-campus-infra/db-postgres/build.gradle` | 중복 제거, H2만 유지 |
| `sw-campus-api/build.gradle` | 중복 제거, 모듈 전용만 유지 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 Role enum 변경

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| Role 값 | `PROVIDER` | `ORGANIZATION` | 비즈니스 용어 통일 |

### 3.2 YAGNI 원칙 적용

다음 기능은 Admin 스코프 제외로 구현하지 않음:
- `approveOrganization()` 메서드
- `isApprovedOrganization()` 메서드
- 관련 테스트 케이스

### 3.3 build.gradle 구조 개선

**변경 전:** 각 모듈에 테스트 의존성 중복
**변경 후:** 루트 `build.gradle`의 `subprojects`에 공통 테스트 의존성

```groovy
// 루트 build.gradle
subprojects {
    dependencies {
        testImplementation 'org.springframework.boot:spring-boot-starter-test'
        testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
    }
}
```

---

## 4. 테스트 결과

### 4.1 MemberTest (도메인)

| 테스트 | 결과 |
|--------|------|
| 일반 회원을 생성할 수 있다 | ✅ |
| 교육기관을 생성할 수 있다 | ✅ |
| 비밀번호를 변경할 수 있다 | ✅ |

### 4.2 MemberRepositoryTest (통합)

| 테스트 | 결과 |
|--------|------|
| 회원을 저장할 수 있다 | ✅ |
| ID로 회원을 조회할 수 있다 | ✅ |
| 이메일로 회원을 조회할 수 있다 | ✅ |
| 존재하지 않는 이메일로 조회하면 빈 결과를 반환한다 | ✅ |
| 이메일 존재 여부를 확인할 수 있다 | ✅ |

### 4.3 OrganizationTest (도메인)

| 테스트 | 결과 |
|--------|------|
| Organization 생성 - create | ✅ |
| Organization 정보 수정 | ✅ |
| 시설 이미지 수정 | ✅ |
| 로고 URL 수정 | ✅ |
| 정부 인증 설정 | ✅ |

### 4.4 OrganizationRepositoryTest (통합)

| 테스트 | 결과 |
|--------|------|
| Organization 저장 및 조회 | ✅ |
| userId로 Organization 조회 | ✅ |
| userId 존재 여부 확인 | ✅ |
| 존재하지 않는 Organization 조회 | ✅ |

### 4.5 EmailVerificationTest (도메인)

| 테스트 | 결과 |
|--------|------|
| 이메일 인증 생성 | ✅ |
| 인증 코드 일치 확인 | ✅ |
| 인증 완료 처리 | ✅ |
| 만료되지 않은 인증은 isExpired가 false | ✅ |

### 4.6 EmailVerificationRepositoryTest (통합)

| 테스트 | 결과 |
|--------|------|
| 이메일 인증 저장 및 조회 | ✅ |
| 존재하지 않는 이메일 조회 | ✅ |

### 4.7 RefreshTokenTest (도메인)

| 테스트 | 결과 |
|--------|------|
| RefreshToken 생성 | ✅ |
| 토큰 갱신 | ✅ |
| 만료되지 않은 토큰은 isExpired가 false | ✅ |

### 4.8 RefreshTokenRepositoryTest (통합)

| 테스트 | 결과 |
|--------|------|
| RefreshToken 저장 및 memberId로 조회 | ✅ |
| token 값으로 조회 | ✅ |
| 존재하지 않는 memberId로 조회 | ✅ |

---

## 5. 검증 결과

```bash
$ ./gradlew clean build
BUILD SUCCESSFUL in 6s
28 actionable tasks: 28 executed
```

---

## 6. 아키텍처 준수 사항

| 규칙 | 준수 여부 | 내용 |
|------|----------|------|
| 레이어 분리 | ✅ | domain ← infra 의존성 방향 준수 |
| 네이밍 컨벤션 | ✅ | `Member`, `MemberEntity`, `MemberRepositoryImpl` |
| 네이밍 컨벤션 | ✅ | `Organization`, `OrganizationEntity`, `OrganizationRepositoryImpl` |
| 네이밍 컨벤션 | ✅ | `EmailVerification`, `EmailVerificationEntity`, `EmailVerificationRepositoryImpl` |
| 네이밍 컨벤션 | ✅ | `RefreshToken`, `RefreshTokenEntity`, `RefreshTokenRepositoryImpl` |
| BaseEntity 상속 | ✅ | `createdAt`, `updatedAt` 자동 관리 (Member, Organization) |
| 정적 팩토리 패턴 | ✅ | `create()`, `of()` 메서드 |

---

## 7. Organization 스키마

실제 테이블 스키마 기반으로 구현:

```sql
CREATE TABLE ORGANIZATIONS (
    ORG_ID BIGSERIAL PRIMARY KEY,
    USER_ID BIGINT NOT NULL,           -- 기관 소유자
    ORG_NAME TEXT,
    DESCRIPTION TEXT,
    GOV_AUTH VARCHAR(100),             -- 정부 인증
    FACILITY_IMAGE_URL TEXT,
    FACILITY_IMAGE_URL2 TEXT,
    FACILITY_IMAGE_URL3 TEXT,
    FACILITY_IMAGE_URL4 TEXT,
    ORG_LOGO_URL TEXT,
    CREATED_AT TIMESTAMP,
    UPDATED_AT TIMESTAMP
);
```

---

## 8. 다음 작업

### Phase 02 ✅ 완료
- [x] Member 도메인/인프라 구현
- [x] Organization 도메인/인프라 구현
- [x] EmailVerification 도메인/인프라 구현
- [x] RefreshToken 도메인/인프라 구현

### Phase 03 준비 사항
- `SecurityConfig` 설정
- `JwtTokenProvider` 구현
- `CustomUserDetailsService` 구현

---

## 9. 참고 사항

- infra 모듈 테스트를 위해 `TestApplication.java` 생성 필요
- H2 DB는 PostgreSQL 모드로 실행 (`MODE=PostgreSQL`)
- Organization은 실제 DDL 스키마 기반으로 구현 (USER_ID, ORG_NAME, GOV_AUTH 등)
