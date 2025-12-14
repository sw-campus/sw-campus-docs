# Phase 05: 테스트 및 검증 - 구현 보고서

> 작성일: 2025-12-11  
> 최종 수정일: 2025-12-11

## 개요

Domain 레이어 단위 테스트, Service 레이어 테스트, API Controller 통합 테스트, **시나리오 기반 E2E 테스트**를 구현했습니다. 추가로 OCR 서비스 **Docker 자동화**를 완료했습니다.

## 구현 결과

### 완료 항목

| 레이어 | 테스트 클래스 | 테스트 수 | 상태 |
|--------|-------------|----------|------|
| **Domain** | ReviewTest | 15 | ✅ |
| **Domain** | CertificateTest | 9 | ✅ |
| **Domain** | ReviewServiceTest | 17 | ✅ |
| **Domain** | CertificateServiceTest | 9 | ✅ |
| **API** | CertificateControllerTest | 5 | ✅ |
| **API** | ReviewControllerTest | 13 | ✅ |
| **API** | AdminReviewControllerTest | 12 | ✅ |
| **E2E** | ReviewIntegrationTest | 6 | ✅ |
| **E2E** | CertificateIntegrationTest | 6 | ✅ |
| **총합** | - | **92** | ✅ |

### 테스트 요약

| 모듈 | 테스트 수 | 결과 |
|------|---------|------|
| sw-campus-domain | 50 | ✅ 모두 통과 |
| sw-campus-api | 42 | ✅ 모두 통과 |
| **총합** | **92** | ✅ 모두 통과 |

---

## 생성된 파일

### Domain 테스트 (`sw-campus-domain/src/test/java`)

| 파일 | 경로 | 테스트 수 |
|------|------|----------|
| `ReviewTest.java` | `domain/review/` | 15 |
| `CertificateTest.java` | `domain/certificate/` | 9 |
| `ReviewServiceTest.java` | `domain/review/` | 17 |
| `CertificateServiceTest.java` | `domain/certificate/` | 9 |

### API 테스트 (`sw-campus-api/src/test/java`)

| 파일 | 경로 | 테스트 수 |
|------|------|----------|
| `CertificateControllerTest.java` | `api/certificate/` | 5 |
| `ReviewControllerTest.java` | `api/review/` | 13 |
| `AdminReviewControllerTest.java` | `api/review/` | 12 |

### E2E 통합 테스트 (`sw-campus-api/src/test/java`)

| 파일 | 경로 | 테스트 수 |
|------|------|----------|
| `ReviewIntegrationTest.java` | `api/review/` | 6 |
| `CertificateIntegrationTest.java` | `api/certificate/` | 6 |

---

## 테스트 상세

### 1. ReviewTest (15개)

#### Review 생성 테스트 (5개)
- ✅ 후기 생성 시 평균 점수가 자동 계산된다
- ✅ 후기 생성 시 PENDING 상태로 생성된다
- ✅ 후기 생성 시 블라인드 처리되지 않은 상태로 생성된다
- ✅ 상세 점수가 없으면 평균 점수는 0.0이다
- ✅ 상세 점수가 null이면 평균 점수는 0.0이다

#### Review 수정 테스트 (2개)
- ✅ 후기 수정 시 평균 점수가 재계산된다
- ✅ 후기 수정 시 comment가 변경된다

#### Review 승인/반려 테스트 (2개)
- ✅ 후기 승인 시 상태가 APPROVED로 변경된다
- ✅ 후기 반려 시 상태가 REJECTED로 변경된다

#### Review 블라인드 테스트 (2개)
- ✅ 후기 블라인드 처리
- ✅ 후기 블라인드 해제

#### 평균 점수 계산 테스트 (4개)
- ✅ 소수점 첫째 자리까지 반올림된다
- ✅ 모든 점수가 동일하면 해당 점수가 평균이 된다
- ✅ 최고 점수 5.0일 때 정확히 계산된다
- ✅ 최저 점수 1.0일 때 정확히 계산된다

### 2. CertificateTest (9개)

#### Certificate 생성 테스트 (2개)
- ✅ 수료증 생성 시 PENDING 상태로 생성된다
- ✅ 수료증 생성 시 필수 정보가 올바르게 설정된다

#### Certificate 승인/반려 테스트 (2개)
- ✅ 수료증 승인 시 APPROVED로 변경된다
- ✅ 수료증 반려 시 REJECTED로 변경된다

#### Certificate 상태 확인 테스트 (4개)
- ✅ isPending - PENDING 상태일 때 true 반환
- ✅ isPending - APPROVED 상태일 때 false 반환
- ✅ isApproved - APPROVED 상태일 때 true 반환
- ✅ isApproved - REJECTED 상태일 때 false 반환

#### Certificate.of 팩토리 메서드 테스트 (1개)
- ✅ of 메서드로 모든 필드를 가진 Certificate 생성

### 3. ReviewServiceTest (17개)

#### 후기 작성 가능 여부 확인 (6개)
- ✅ 모든 조건 충족 시 eligible = true
- ✅ 닉네임 없으면 eligible = false
- ✅ 빈 닉네임이면 eligible = false
- ✅ 수료증 없으면 eligible = false
- ✅ 이미 후기 작성했으면 eligible = false
- ✅ 회원이 없으면 예외 발생

#### 후기 작성 (3개)
- ✅ 정상적으로 후기 작성 성공
- ✅ 수료증 없이 후기 작성 시 예외 발생
- ✅ 이미 후기가 있는 강의에 작성 시 예외 발생

#### 후기 수정 (4개)
- ✅ 정상적으로 후기 수정 성공
- ✅ 후기가 없으면 예외 발생
- ✅ 본인 후기가 아니면 예외 발생
- ✅ 승인된 후기 수정 시 예외 발생

#### 후기 조회 (2개)
- ✅ 후기 상세 조회 성공
- ✅ 후기가 없으면 예외 발생

#### 강의별 승인된 후기 목록 조회 (2개)
- ✅ 승인된 후기 목록 조회 성공
- ✅ 승인된 후기가 없으면 빈 리스트 반환

### 4. CertificateServiceTest (9개)

#### 수료증 인증 여부 확인 (2개)
- ✅ 수료증이 존재하면 Optional에 담겨 반환
- ✅ 수료증이 없으면 빈 Optional 반환

#### 수료증 인증 처리 (7개)
- ✅ 이미 인증된 수료증이 있으면 예외 발생
- ✅ 강의를 찾을 수 없으면 예외 발생
- ✅ OCR 결과에 강의명이 포함되지 않으면 예외 발생
- ✅ OCR 결과가 빈 리스트면 예외 발생
- ✅ 수료증 인증 성공 - 정확히 일치
- ✅ 유연한 매칭: 공백이 다르더라도 강의명 인식 성공
- ✅ 유연한 매칭: 대소문자가 다르더라도 강의명 인식 성공

---

## 테스트 실행 결과

```
BUILD SUCCESSFUL in 1s

Test Results:
- ReviewTest: 15 tests, 0 failures
- CertificateTest: 9 tests, 0 failures
- ReviewServiceTest: 17 tests, 0 failures
- CertificateServiceTest: 9 tests, 0 failures
- Total: 50 tests, 0 failures
```

---

## E2E 통합 테스트 상세

### 5. ReviewIntegrationTest (6개)

실제 데이터베이스와 Spring Context를 사용한 시나리오 기반 테스트입니다.

#### 후기 작성 가능 여부 조회 (2개)
- ✅ 수료증이 있고 후기를 작성하지 않은 경우 true 반환
- ✅ 수료증이 없는 경우 false 반환

#### 후기 CRUD (4개)
- ✅ 후기 작성 성공
- ✅ 후기 수정 성공
- ✅ 후기 상세 조회 성공
- ✅ 강의별 승인된 후기 목록 조회 성공

### 6. CertificateIntegrationTest (6개)

OCR 연동을 포함한 수료증 인증 시나리오 테스트입니다.

#### 수료증 인증 여부 조회 (2개)
- ✅ 수료증이 있는 경우 인증 정보 반환
- ✅ 수료증이 없는 경우 404 반환

#### 수료증 인증 요청 (4개)
- ✅ 수료증 인증 성공 (이미지 업로드 + OCR)
- ✅ 수료증 인증 실패 - 이미지 없음
- ✅ 수료증 인증 실패 - 지원하지 않는 파일 형식
- ✅ 수료증 인증 실패 - 강의명 불일치

### E2E 테스트 특징

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc(addFilters = false)  // Security 필터 비활성화
@Transactional  // 테스트 후 롤백
class ReviewIntegrationTest {
    // SecurityContext 수동 설정으로 인증 처리
    private void setAuthentication(Long memberId) {
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(new TestingAuthenticationToken(memberId, null));
        SecurityContextHolder.setContext(context);
    }
}
```

---

## Docker 자동화 (부가 작업)

### 구현 내용

OCR AI 서비스를 Docker 이미지화하여 docker-compose로 관리할 수 있도록 구성했습니다.

### 생성된 파일

| 파일 | 위치 | 설명 |
|------|------|------|
| `Dockerfile` | `sw-campus-ai/` | OCR 서비스 컨테이너화 |
| `.dockerignore` | `sw-campus-ai/` | 빌드 제외 파일 |
| `docker-compose.yml` | `sw-campus-server/` | OCR 서비스 추가 |

### Docker 이미지

- **이미지명**: `zionge2k/sw-campus-ocr:latest`
- **베이스 이미지**: `python:3.11-slim`
- **포트**: 8001 → 8000

### docker-compose.yml 구성

```yaml
services:
  postgres:
    image: postgres:16
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]

  ocr:
    image: zionge2k/sw-campus-ocr:latest
    ports:
      - "8001:8000"
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      start_period: 60s
```

### 사용법

```bash
# 서비스 시작
docker compose up -d

# 서비스 상태 확인
docker compose ps

# OCR 헬스체크
curl http://localhost:8001/health
```

---

## 파일 구조

```
sw-campus-server/
├── docker-compose.yml                    ✅ 수정 (OCR 서비스 추가)
├── sw-campus-domain/
│   └── src/test/java/com/swcampus/domain/
│       ├── review/
│       │   ├── ReviewTest.java           ✅ 신규
│       │   └── ReviewServiceTest.java    ✅ 신규
│       └── certificate/
│           ├── CertificateTest.java      ✅ 신규
│           └── CertificateServiceTest.java ✅ 신규
└── sw-campus-api/
    └── src/test/java/com/swcampus/api/
        ├── review/
        │   ├── ReviewControllerTest.java     ✅ 신규
        │   ├── AdminReviewControllerTest.java ✅ 신규
        │   └── ReviewIntegrationTest.java    ✅ 신규 (E2E)
        └── certificate/
            ├── CertificateControllerTest.java ✅ 신규
            └── CertificateIntegrationTest.java ✅ 신규 (E2E)

sw-campus-ai/
├── Dockerfile                            ✅ 신규
├── .dockerignore                         ✅ 신규
└── app/
    └── main.py                           ✅ 수정 (/health 엔드포인트 추가)
```

---

## 테스트 기법

### 사용된 라이브러리
- JUnit 5 (`@Test`, `@DisplayName`, `@Nested`)
- AssertJ (`assertThat`, `assertThatThrownBy`)
- Mockito (`@Mock`, `@InjectMocks`, `given`, `willReturn`)

### 테스트 패턴
- **Given-When-Then**: 모든 테스트에 명확한 구조 적용
- **Nested 클래스**: 기능별 테스트 그룹화
- **DisplayName**: 한글 테스트명으로 가독성 향상

---

## 테스트 환경 설정 수정 (2025-12-13)

### H2 Database 스키마 설정

통합 테스트에서 `Schema "SWCAMPUS" not found` 오류가 발생하여, H2 설정에 스키마 자동 생성 옵션을 추가했습니다.

**수정 파일:**
- `sw-campus-api/src/test/resources/application-test.yml`
- `sw-campus-infra/db-postgres/src/test/resources/application-test.yml`

**수정 내용:**
```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL;INIT=CREATE SCHEMA IF NOT EXISTS swcampus
```

### Mockito Matcher 수정

`any()`와 원시 값을 혼용할 때 발생하는 `InvalidUseOfMatchersException` 해결을 위해 `eq()` 래퍼를 적용했습니다.

**수정 파일:**
- `CertificateServiceTest.java`
- `CertificateIntegrationTest.java`

**수정 예시:**
```java
// Before
given(fileStorageService.upload(any(), "certificates", anyString(), anyString()))

// After
given(fileStorageService.upload(any(), eq("certificates"), anyString(), anyString()))
```

---

## 향후 작업

- [x] Controller 통합 테스트 작성
- [x] 시나리오 기반 E2E 테스트
- [x] Docker 자동화 (OCR 서비스)
- [x] 테스트 환경 설정 수정 (H2 스키마, Mockito)
- [ ] 코드 커버리지 측정 및 리포트

---

## 참고

- 계획 문서: `sw-campus-docs/features/review/plan/phase05-testing.md`
- Docker 이미지: `docker pull zionge2k/sw-campus-ocr:latest`
