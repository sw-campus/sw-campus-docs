# Phase 01: 기반 구조 - 구현 완료 리포트

> 작성일: 2025년 12월 10일

## 개요

Review/Certificate 기능의 기반 구조(Domain, Entity, Repository)를 구현했습니다.

---

## 구현 결과

### 1. Domain 모듈 (sw-campus-domain)

#### 1.1 Enum (2개)

| 파일 | 경로 | 설명 |
|------|------|------|
| `ApprovalStatus.java` | `domain/review/` | 승인 상태 (PENDING, APPROVED, REJECTED) |
| `ReviewCategory.java` | `domain/review/` | 후기 카테고리 (TEACHER, CURRICULUM, MANAGEMENT, FACILITY, PROJECT) |

#### 1.2 Domain 객체 (3개)

| 파일 | 경로 | 설명 |
|------|------|------|
| `Certificate.java` | `domain/certificate/` | 수료증 도메인 |
| `Review.java` | `domain/review/` | 후기 도메인 |
| `ReviewDetail.java` | `domain/review/` | 후기 상세 (카테고리별 점수/후기) |

#### 1.3 Repository 인터페이스 (2개)

| 파일 | 경로 | 메서드 |
|------|------|--------|
| `CertificateRepository.java` | `domain/certificate/` | save, findById, findByMemberIdAndLectureId, existsByMemberIdAndLectureId |
| `ReviewRepository.java` | `domain/review/` | save, findById, findByMemberIdAndLectureId, existsByMemberIdAndLectureId, findByLectureIdAndApprovalStatus, findByApprovalStatus, findPendingReviews |

#### 1.4 예외 클래스 (6개)

| 파일 | 경로 | 설명 |
|------|------|------|
| `CertificateNotFoundException.java` | `domain/certificate/exception/` | 수료증 조회 실패 |
| `CertificateAlreadyExistsException.java` | `domain/certificate/exception/` | 수료증 중복 인증 |
| `CertificateLectureMismatchException.java` | `domain/certificate/exception/` | 수료증-강의 불일치 |
| `ReviewNotFoundException.java` | `domain/review/exception/` | 후기 조회 실패 |
| `ReviewAlreadyExistsException.java` | `domain/review/exception/` | 후기 중복 작성 |
| `ReviewNotOwnerException.java` | `domain/review/exception/` | 본인 후기 아님 |

---

### 2. Infra 모듈 (sw-campus-infra/db-postgres)

#### 2.1 Entity 클래스 (3개)

| 파일 | 경로 | 테이블 |
|------|------|--------|
| `CertificateEntity.java` | `infra/postgres/certificate/` | `certificates` |
| `ReviewEntity.java` | `infra/postgres/review/` | `reviews` |
| `ReviewDetailEntity.java` | `infra/postgres/review/` | `reviews_details` |

#### 2.2 JPA Repository (3개)

| 파일 | 경로 |
|------|------|
| `CertificateJpaRepository.java` | `infra/postgres/certificate/` |
| `ReviewJpaRepository.java` | `infra/postgres/review/` |
| `ReviewDetailJpaRepository.java` | `infra/postgres/review/` |

#### 2.3 Repository 구현체 (2개)

| 파일 | 경로 | 구현 인터페이스 |
|------|------|----------------|
| `CertificateEntityRepository.java` | `infra/postgres/certificate/` | `CertificateRepository` |
| `ReviewEntityRepository.java` | `infra/postgres/review/` | `ReviewRepository` |

---

## Plan 대비 변경 사항

### 1. 예외 클래스 패턴 변경

**Plan 문서:**
```java
public class CertificateNotFoundException extends BusinessException {
    public CertificateNotFoundException() {
        super(ErrorCode.CERTIFICATE_NOT_FOUND);
    }
}
```

**실제 구현:**
```java
public class CertificateNotFoundException extends RuntimeException {
    public CertificateNotFoundException() {
        super("수료증을 찾을 수 없습니다");
    }
}
```

**변경 사유:** 기존 프로젝트의 예외 처리 패턴이 `BusinessException`/`ErrorCode`를 사용하지 않고 `RuntimeException`을 직접 상속하는 방식이었기 때문에 일관성을 유지하기 위해 변경했습니다.

### 2. Domain 필드명 변경

**Plan 문서:** `certificateId`, `reviewId`, `reviewDetailId`
**실제 구현:** `id` (기존 `Member` 도메인 패턴과 일치)

**변경 사유:** 기존 `Member` 도메인에서 `id` 필드명을 사용하고 있어 일관성을 유지했습니다.

### 3. Entity 패턴 변경

**Plan 문서:** `of()` 정적 팩토리 메서드, `toEntity()`/`toDomain()` Repository 내부 메서드
**실제 구현:** `from(domain)`, `toDomain()` Entity 내부 메서드

**변경 사유:** 기존 `MemberEntity` 패턴과 일치하도록 변경했습니다.

### 4. Review.calculateAverageScore() NPE 방지

**추가 구현:**
```java
private static Double calculateAverageScore(List<ReviewDetail> details) {
    if (details == null || details.isEmpty()) {
        return 0.0;
    }
    double sum = details.stream()
            .map(ReviewDetail::getScore)
            .filter(score -> score != null)  // NPE 방지
            .mapToDouble(Double::doubleValue)
            .sum();
    long count = details.stream()
            .map(ReviewDetail::getScore)
            .filter(score -> score != null)
            .count();
    if (count == 0) {
        return 0.0;
    }
    return Math.round(sum / count * 10) / 10.0;
}
```

### 5. YAGNI 원칙 적용

**삭제된 메서드:**
- `ReviewDetailJpaRepository.findByReviewId()` - 미사용
- `ReviewDetailJpaRepository.deleteByReviewId()` - 미사용
- `ReviewJpaRepository.findPendingReviewsWithDetails()` - `findByApprovalStatusWithDetails(ApprovalStatus.PENDING)`으로 대체

---

## 빌드 결과

```bash
./gradlew :sw-campus-domain:compileJava :sw-campus-infra:db-postgres:compileJava

BUILD SUCCESSFUL in 1s
3 actionable tasks: 3 executed
```

---

## 파일 목록

### Domain 모듈 (13개)

```
sw-campus-domain/src/main/java/com/swcampus/domain/
├── certificate/
│   ├── Certificate.java
│   ├── CertificateRepository.java
│   └── exception/
│       ├── CertificateAlreadyExistsException.java
│       ├── CertificateLectureMismatchException.java
│       └── CertificateNotFoundException.java
└── review/
    ├── ApprovalStatus.java
    ├── Review.java
    ├── ReviewCategory.java
    ├── ReviewDetail.java
    ├── ReviewRepository.java
    └── exception/
        ├── ReviewAlreadyExistsException.java
        ├── ReviewNotFoundException.java
        └── ReviewNotOwnerException.java
```

### Infra 모듈 (8개)

```
sw-campus-infra/db-postgres/src/main/java/com/swcampus/infra/postgres/
├── certificate/
│   ├── CertificateEntity.java
│   ├── CertificateEntityRepository.java
│   └── CertificateJpaRepository.java
└── review/
    ├── ReviewDetailEntity.java
    ├── ReviewDetailJpaRepository.java
    ├── ReviewEntity.java
    ├── ReviewEntityRepository.java
    └── ReviewJpaRepository.java
```

---

## 다음 단계

**Phase 02: 수료증 인증** - Service Layer 및 Controller 구현

- CertificateService
- CertificateController
- 수료증 업로드 API
- 수료증 조회 API
