# Phase 03: 후기 CRUD API - 구현 보고서

> 작성일: 2025-12-11

## 개요

후기 작성/수정/조회 API 및 작성 가능 여부 확인 API를 구현했습니다.

## 구현 결과

### 완료 항목

| 항목 | 상태 | 비고 |
|------|------|------|
| ReviewService 구현 | ✅ | domain 모듈 |
| ReviewEligibility DTO 생성 | ✅ | domain 모듈 |
| 예외 클래스 생성 | ✅ | 4개 예외 클래스 |
| Request DTO 생성 | ✅ | 3개 DTO |
| Response DTO 생성 | ✅ | 3개 DTO |
| ReviewController 구현 | ✅ | 4개 API 엔드포인트 |
| Validation 적용 | ✅ | Jakarta Validation |
| GlobalExceptionHandler 추가 | ✅ | 예외 핸들러 등록 |
| 컴파일 | ✅ | 성공 |

---

## 생성된 파일

### Domain 모듈 (`sw-campus-domain`)

| 파일 | 경로 | 설명 |
|------|------|------|
| `ReviewService.java` | `domain/review/` | 후기 비즈니스 로직 |
| `ReviewEligibility.java` | `domain/review/` | 작성 가능 여부 DTO |
| `ReviewNotFoundException.java` | `domain/review/exception/` | 후기 없음 예외 |
| `ReviewAlreadyExistsException.java` | `domain/review/exception/` | 후기 중복 예외 |
| `ReviewNotOwnerException.java` | `domain/review/exception/` | 작성자 불일치 예외 |
| `ReviewNotModifiableException.java` | `domain/review/exception/` | 수정 불가 예외 |

### API 모듈 (`sw-campus-api`)

| 파일 | 경로 | 설명 |
|------|------|------|
| `ReviewController.java` | `api/review/` | 후기 컨트롤러 |
| `CreateReviewRequest.java` | `api/review/request/` | 후기 작성 요청 DTO |
| `UpdateReviewRequest.java` | `api/review/request/` | 후기 수정 요청 DTO |
| `DetailScoreRequest.java` | `api/review/request/` | 상세 점수 요청 DTO |
| `ReviewResponse.java` | `api/review/response/` | 후기 응답 DTO |
| `ReviewEligibilityResponse.java` | `api/review/response/` | 작성 가능 여부 응답 DTO |
| `DetailScoreResponse.java` | `api/review/response/` | 상세 점수 응답 DTO |

---

## API 엔드포인트

| 기능 | Method | Endpoint | 인증 | 설명 |
|------|--------|----------|------|------|
| 작성 가능 여부 확인 | GET | `/api/v1/reviews/eligibility?lectureId={id}` | 필요 | 닉네임, 수료증, 중복 확인 |
| 후기 작성 | POST | `/api/v1/reviews` | 필요 | 수료증 인증 필수 |
| 후기 수정 | PUT | `/api/v1/reviews/{reviewId}` | 필요 | 본인만, PENDING만 수정 가능 |
| 후기 상세 조회 | GET | `/api/v1/reviews/{reviewId}` | 불필요 | 공개 API |

---

## 구현 세부 사항

### 1. 후기 작성 가능 여부 확인 (Eligibility)

```java
public ReviewEligibility checkEligibility(Long memberId, Long lectureId) {
    // 1. 닉네임 설정 여부
    boolean hasNickname = member.getNickname() != null && !member.getNickname().isBlank();
    
    // 2. 수료증 인증 여부
    boolean hasCertificate = certificateRepository.existsByMemberIdAndLectureId(memberId, lectureId);
    
    // 3. 기존 후기 존재 여부 (없어야 작성 가능)
    boolean canWrite = !reviewRepository.existsByMemberIdAndLectureId(memberId, lectureId);
    
    return ReviewEligibility.of(hasNickname, hasCertificate, canWrite);
}
```

**조건 충족 여부:**
- `hasNickname`: 닉네임 설정 완료
- `hasCertificate`: 수료증 인증 완료
- `canWrite`: 해당 강의에 후기 미작성
- `eligible`: 위 3개 조건 모두 충족

### 2. 후기 작성 검증

| 검증 항목 | 예외 |
|----------|------|
| 수료증 미인증 | `CertificateNotVerifiedException` |
| 후기 중복 | `ReviewAlreadyExistsException` |

### 3. 후기 수정 제한

| 검증 항목 | 예외 |
|----------|------|
| 후기 없음 | `ReviewNotFoundException` |
| 본인 아님 | `ReviewNotOwnerException` |
| 승인된 후기 | `ReviewNotModifiableException` |

> **Note**: 승인된(APPROVED) 후기는 **사용자**가 수정할 수 없습니다.
> 관리자는 Phase 04의 별도 API를 통해 관리합니다.

### 4. Validation 규칙

#### CreateReviewRequest / UpdateReviewRequest
| 필드 | 규칙 |
|------|------|
| `lectureId` | 필수 (작성 시만) |
| `comment` | 선택, 최대 500자 |
| `detailScores` | 필수, 정확히 5개 카테고리 |

#### DetailScoreRequest
| 필드 | 규칙 |
|------|------|
| `category` | 필수 (TEACHER, CURRICULUM, FACILITY, ATMOSPHERE, RECOMMENDATION) |
| `score` | 필수, 1.0 ~ 5.0 |
| `comment` | 필수, 20 ~ 500자 |

### 5. 공개 API 설정

`SecurityConfig`에서 후기 상세 조회를 공개 API로 설정:

```java
.requestMatchers(HttpMethod.GET, "/api/v1/reviews/*").permitAll()
```

---

## 파일 구조

```
sw-campus-server/
├── sw-campus-domain/
│   └── src/main/java/com/swcampus/domain/
│       └── review/
│           ├── ReviewService.java         ✅ 신규
│           ├── ReviewEligibility.java     ✅ 신규
│           └── exception/
│               ├── ReviewNotFoundException.java       ✅ 신규
│               ├── ReviewAlreadyExistsException.java  ✅ 신규
│               ├── ReviewNotOwnerException.java       ✅ 신규
│               └── ReviewNotModifiableException.java  ✅ 신규
│
└── sw-campus-api/
    └── src/main/java/com/swcampus/api/
        └── review/
            ├── ReviewController.java          ✅ 신규
            ├── request/
            │   ├── CreateReviewRequest.java   ✅ 신규
            │   ├── UpdateReviewRequest.java   ✅ 신규
            │   └── DetailScoreRequest.java    ✅ 신규
            └── response/
                ├── ReviewResponse.java            ✅ 신규
                ├── ReviewEligibilityResponse.java ✅ 신규
                └── DetailScoreResponse.java       ✅ 신규
```

---

## 예외 처리

`GlobalExceptionHandler`에 등록된 예외 핸들러:

| 예외 | HTTP Status | 메시지 |
|------|-------------|--------|
| `ReviewNotFoundException` | 404 | 후기를 찾을 수 없습니다 |
| `ReviewAlreadyExistsException` | 409 | 이미 후기를 작성한 강의입니다 |
| `ReviewNotOwnerException` | 403 | 본인의 후기만 수정할 수 있습니다 |
| `ReviewNotModifiableException` | 403 | 승인된 후기는 수정할 수 없습니다 |
| `CertificateNotVerifiedException` | 403 | 수료증 인증이 필요합니다 |

---

## 향후 작업

- [ ] 강의별 후기 목록 조회 API (페이징)
- [ ] 후기 삭제 API
- [ ] 후기 통합 테스트 작성
- [ ] Swagger UI에서 API 테스트

---

## 참고

- 계획 문서: `sw-campus-docs/features/review/plan/phase03-review-crud.md`
- 도메인 모델: `sw-campus-docs/features/review/plan/phase01-foundation.md`
