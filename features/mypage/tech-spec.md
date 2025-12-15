# 마이페이지 (Mypage) - Tech Spec

> Technical Specification

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-14 |
| 상태 | Draft |
| 버전 | 0.3 |
| PRD | [prd.md](./prd.md) |

---

## 1. 개요

### 1.1 목적

사용자(USER, ORGANIZATION)별 마이페이지 기능을 구현하기 위한 기술 명세를 정의합니다. 내 정보 관리, 활동 내역(후기, 강의) 조회 및 수정, 설문조사 관리 기능을 포함합니다.

### 1.2 기술 스택

| 구분 | 기술 |
|------|------|
| Framework | Spring Boot 3.x |
| Security | Spring Security 6.x |
| Database | PostgreSQL |
| ORM | Spring Data JPA |

---

## 2. 시스템 아키텍처

### 2.1 모듈 구조

마이페이지 기능은 `sw-campus-api` 계층에서 여러 도메인(`Member`, `Review`, `Lecture`, `Survey`, `Organization`)을 조합하여 제공합니다.

```
sw-campus-server/
├── sw-campus-api/
│   └── mypage/
│       ├── MypageController.java
│       ├── request/
│       │   ├── UpdateProfileRequest.java
│       │   └── UpdateOrganizationRequest.java
│       └── response/
│           ├── MypageProfileResponse.java
│           ├── MyReviewListResponse.java
│           ├── MyLectureListResponse.java
│           └── OrganizationInfoResponse.java
│
└── sw-campus-domain/
    ├── member/
    │   └── MemberService.java
    ├── review/
    │   └── ReviewService.java
    ├── lecture/
    │   └── LectureService.java
    ├── survey/
    │   └── MemberSurveyService.java
    └── organization/
        └── OrganizationService.java
```

### 2.2 컴포넌트 구조

#### sw-campus-api

```
com.swcampus.api/
├── mypage/
│   ├── MypageController.java
│   ├── request/
│   │   ├── UpdateProfileRequest.java
│   │   └── UpdateOrganizationRequest.java
│   └── response/
│       ├── MypageProfileResponse.java
│       ├── MyReviewListResponse.java
│       ├── MyLectureListResponse.java
│       └── OrganizationInfoResponse.java
```

---

## 3. 데이터 모델링

기존 테이블(`member`, `review`, `lecture`, `member_survey`, `organization`)을 그대로 사용합니다.

---

## 4. API 명세

### 4.1 공통 - 내 정보 관리

#### 4.1.1 내 정보 조회

| 항목 | 내용 |
|------|------|
| URL | `GET /api/v1/mypage/profile` |
| Method | GET |
| Permission | `USER`, `ORGANIZATION` |

**Response Body**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| email | String | ✅ | 이메일 |
| name | String | ✅ | 이름 |
| nickname | String | ❌ | 닉네임 (미설정 시 null) |
| phone | String | ❌ | 전화번호 |
| address | String | ❌ | 주소 |
| profileImageUrl | String | ❌ | 프로필 이미지 URL |
| provider | String | ✅ | 가입 경로 (`LOCAL`, `GOOGLE`, `GITHUB`) |
| role | String | ✅ | 역할 (`USER`, `ORGANIZATION`) |
| hasSurvey | Boolean | ✅ | 설문조사 완료 여부 (USER만 해당, ORGANIZATION은 false) |

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 조회 성공 |
| 401 | 인증 필요 |

---

#### 4.1.2 내 정보 수정

| 항목 | 내용 |
|------|------|
| URL | `PATCH /api/v1/mypage/profile` |
| Method | PATCH |
| Permission | `USER`, `ORGANIZATION` |

**Request Body**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| nickname | String | ❌ | 닉네임 |
| phone | String | ❌ | 전화번호 |
| address | String | ❌ | 주소 |

> **Note**: 비밀번호 변경은 기존 Auth API(`PATCH /api/v1/auth/password`) 재사용

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 수정 성공 |
| 400 | 잘못된 요청 |
| 401 | 인증 필요 |

---

### 4.2 일반 사용자 (USER)

#### 4.2.1 내 후기 목록 조회

| 항목 | 내용 |
|------|------|
| URL | `GET /api/v1/mypage/reviews` |
| Method | GET |
| Permission | `USER` |

**Query Parameters**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| page | Integer | ❌ | 페이지 번호 (default: 0) |
| size | Integer | ❌ | 페이지 크기 (default: 10) |
| status | String | ❌ | 승인 상태 필터 (`PENDING`, `APPROVED`, `REJECTED`) |

**Response Body** (`Page<MyReviewListResponse>`)

| 필드 | 타입 | 설명 |
|------|------|------|
| reviewId | Long | 후기 ID |
| lectureId | Long | 강의 ID |
| lectureName | String | 강의명 |
| rating | Integer | 평점 (1~5) |
| content | String | 후기 내용 (요약) |
| approvalStatus | String | 승인 상태 (`PENDING`, `APPROVED`, `REJECTED`) |
| rejectReason | String | 반려 사유 (반려 시) |
| createdAt | LocalDateTime | 작성일 |
| updatedAt | LocalDateTime | 수정일 |
| canEdit | Boolean | 수정 가능 여부 (REJECTED일 때만 true) |

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 조회 성공 |
| 401 | 인증 필요 |
| 403 | 권한 없음 (USER 아님) |

---

#### 4.2.2 내 설문조사 조회

| 항목 | 내용 |
|------|------|
| URL | `GET /api/v1/mypage/survey` |
| Method | GET |
| Permission | `USER` |

**Response Body** (`SurveyResponse`)

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| surveyId | Long | ❌ | 설문 ID (없으면 null) |
| major | String | ❌ | 전공 |
| bootcampCompleted | Boolean | ❌ | 부트캠프 수료 경험 |
| wantedJobs | String | ❌ | 희망 직무 |
| licenses | String | ❌ | 자격증 |
| hasGovCard | Boolean | ❌ | 내일배움카드 여부 |
| affordableAmount | BigDecimal | ❌ | 자비부담 가능 금액 |
| exists | Boolean | ✅ | 설문 데이터 존재 여부 |

> **Note**: 설문 데이터가 없는 경우 `exists: false`와 함께 null 필드 반환

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 조회 성공 (데이터 없어도 200) |
| 401 | 인증 필요 |
| 403 | 권한 없음 (USER 아님) |

---

#### 4.2.3 내 설문조사 수정 (Upsert)

| 항목 | 내용 |
|------|------|
| URL | `PUT /api/v1/mypage/survey` |
| Method | PUT |
| Permission | `USER` |

**Request Body**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| major | String | ❌ | 전공 |
| bootcampCompleted | Boolean | ❌ | 부트캠프 수료 경험 |
| wantedJobs | String | ❌ | 희망 직무 |
| licenses | String | ❌ | 자격증 |
| hasGovCard | Boolean | ❌ | 내일배움카드 여부 |
| affordableAmount | BigDecimal | ❌ | 자비부담 가능 금액 |

**Logic**
- 기존 데이터 존재 시 → Update
- 기존 데이터 없음 → Insert

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 수정 성공 |
| 201 | 신규 생성 성공 |
| 400 | 잘못된 요청 |
| 401 | 인증 필요 |
| 403 | 권한 없음 (USER 아님) |

---

#### 4.2.4 후기 수정 (재승인 요청)

기존 후기 수정 API를 재사용합니다.

| 항목 | 내용 |
|------|------|
| URL | `PUT /api/v1/reviews/{reviewId}` |
| Method | PUT |
| Permission | `USER` |

> **참고**: 기존 `ReviewController.updateReview()` 재사용. 단, `REJECTED` 상태인 경우에만 수정 가능하며 수정 시 상태가 `PENDING`으로 변경됨.

---

### 4.3 기관 담당자 (ORGANIZATION)

#### 4.3.1 기관 정보 조회

| 항목 | 내용 |
|------|------|
| URL | `GET /api/v1/mypage/organization` |
| Method | GET |
| Permission | `ORGANIZATION` |

**Response Body**

| 필드 | 타입 | 설명 |
|------|------|------|
| organizationId | Long | 기관 ID |
| organizationName | String | 기관명 |
| representativeName | String | 대표자명 |
| businessNumber | String | 사업자등록번호 |
| phone | String | 연락처 |
| address | String | 주소 |
| approvalStatus | String | 기관 승인 상태 (`PENDING`, `APPROVED`, `REJECTED`) |
| rejectReason | String | 반려 사유 (반려 시) |

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 조회 성공 |
| 401 | 인증 필요 |
| 403 | 권한 없음 (ORGANIZATION 아님) |

---

#### 4.3.2 기관 정보 수정

| 항목 | 내용 |
|------|------|
| URL | `PATCH /api/v1/mypage/organization` |
| Method | PATCH |
| Permission | `ORGANIZATION` |

**Request Body**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| organizationName | String | ❌ | 기관명 |
| representativeName | String | ❌ | 대표자명 |
| phone | String | ❌ | 연락처 |
| address | String | ❌ | 주소 |

> **Note**: 현재 버전에서는 자유 수정 가능. 추후 고도화 시 관리자 검토 프로세스 추가 검토

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 수정 성공 |
| 400 | 잘못된 요청 |
| 401 | 인증 필요 |
| 403 | 권한 없음 (ORGANIZATION 아님) |

---

#### 4.3.3 내 강의 목록 조회

| 항목 | 내용 |
|------|------|
| URL | `GET /api/v1/mypage/lectures` |
| Method | GET |
| Permission | `ORGANIZATION` |

**Query Parameters**

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| page | Integer | ❌ | 페이지 번호 (default: 0) |
| size | Integer | ❌ | 페이지 크기 (default: 10) |
| status | String | ❌ | 승인 상태 필터 (`PENDING`, `APPROVED`, `REJECTED`) |

**Response Body** (`Page<MyLectureListResponse>`)

| 필드 | 타입 | 설명 |
|------|------|------|
| lectureId | Long | 강의 ID |
| lectureName | String | 강의명 |
| lectureImageUrl | String | 강의 이미지 URL |
| lectureAuthStatus | String | 승인 상태 (`PENDING`, `APPROVED`, `REJECTED`) |
| rejectReason | String | 반려 사유 (반려 시) |
| status | String | 모집 상태 (`RECRUITING`, `FINISHED`) |
| createdAt | LocalDateTime | 등록일 |
| updatedAt | LocalDateTime | 수정일 |
| canEdit | Boolean | 수정 가능 여부 (REJECTED일 때만 true) |

**Response Code**

| 코드 | 설명 |
|:----:|------|
| 200 | 조회 성공 |
| 401 | 인증 필요 |
| 403 | 권한 없음 (ORGANIZATION 아님) |

---

#### 4.3.5 강의 수정 (재승인 요청)

기존 강의 수정 API를 재사용합니다.

| 항목 | 내용 |
|------|------|
| URL | `PUT /api/v1/lectures/{lectureId}` |
| Method | PUT |
| Permission | `ORGANIZATION` |

> **참고**: 기존 `LectureController.updateLecture()` 재사용. 단, `REJECTED` 상태인 경우에만 수정 가능하며 수정 시 상태가 `PENDING`으로 변경됨.

---

#### 4.3.4 강의 등록

기존 강의 등록 API를 재사용합니다.

| 항목 | 내용 |
|------|------|
| URL | `POST /api/v1/lectures` |
| Method | POST |
| Permission | `ORGANIZATION` |
| Content-Type | `multipart/form-data` |

> **참고**: 기존 `LectureController.createLecture()` 재사용

---

## 5. 비즈니스 로직 변경 사항

### 5.1 후기 수정 로직 (ReviewService)

기존 `updateReview` 메서드에 상태 체크 로직을 추가합니다.

```java
public void updateReview(Long reviewId, Long memberId, UpdateReviewRequest request) {
    Review review = reviewRepository.findById(reviewId)
        .orElseThrow(() -> new ReviewNotFoundException());
    
    // 작성자 본인 확인
    if (!review.getMemberId().equals(memberId)) {
        throw new AccessDeniedException("후기 수정 권한이 없습니다.");
    }

    // 상태 체크: REJECTED 상태만 수정 가능
    if (review.getApprovalStatus() != ApprovalStatus.REJECTED) {
        throw new ReviewCannotBeModifiedException();
    }

    // 수정 로직 수행
    Review updatedReview = review.update(request.toUpdateParams());
    
    // 상태 변경: REJECTED -> PENDING
    updatedReview = updatedReview.changeStatus(ApprovalStatus.PENDING);
    
    reviewRepository.save(updatedReview);
}
```

### 5.2 강의 수정 로직 (LectureService)

기존 `updateLecture` 메서드에 상태 체크 로직을 추가합니다.

```java
public void updateLecture(Long lectureId, Long orgId, LectureUpdateRequest request) {
    Lecture lecture = lectureRepository.findById(lectureId)
        .orElseThrow(() -> new LectureNotFoundException());
    
    // 기관 소유 확인
    if (!lecture.getOrgId().equals(orgId)) {
        throw new AccessDeniedException("강의 수정 권한이 없습니다.");
    }

    // 상태 체크: REJECTED 상태만 수정 가능
    if (lecture.getLectureAuthStatus() != LectureAuthStatus.REJECTED) {
        throw new LectureCannotBeModifiedException();
    }

    // 수정 로직 수행
    Lecture updatedLecture = lecture.update(request.toUpdateParams());
    
    // 상태 변경: REJECTED -> PENDING
    updatedLecture = updatedLecture.changeAuthStatus(LectureAuthStatus.PENDING);
    
    lectureRepository.save(updatedLecture);
}
```

### 5.3 설문조사 Upsert 로직 (MemberSurveyService)

```java
public void upsertSurvey(Long memberId, SurveyRequest request) {
    Optional<MemberSurvey> existingSurvey = memberSurveyRepository.findByMemberId(memberId);
    
    if (existingSurvey.isPresent()) {
        // Update
        MemberSurvey updated = existingSurvey.get().update(request.toUpdateParams());
        memberSurveyRepository.save(updated);
    } else {
        // Insert
        MemberSurvey newSurvey = MemberSurvey.builder()
            .memberId(memberId)
            .major(request.getMajor())
            .bootcampCompleted(request.getBootcampCompleted())
            .wantedJobs(request.getWantedJobs())
            .licenses(request.getLicenses())
            .hasGovCard(request.getHasGovCard())
            .affordableAmount(request.getAffordableAmount())
            .build();
        memberSurveyRepository.save(newSurvey);
    }
}
```

---

## 6. Swagger 문서화

### 6.1 Controller 레벨

```java
@RestController
@RequestMapping("/api/v1/mypage")
@RequiredArgsConstructor
@Tag(name = "Mypage", description = "마이페이지 API")
public class MypageController {

    @GetMapping("/profile")
    @Operation(summary = "내 정보 조회", description = "로그인한 사용자의 기본 정보를 조회합니다.")
    @SecurityRequirement(name = "cookieAuth")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    public ResponseEntity<MypageProfileResponse> getProfile(@CurrentMember MemberPrincipal member) {
        // ...
    }
}
```

---

## 7. 에러 코드

| 코드 | HTTP Status | 메시지 | 설명 |
|------|:-----------:|--------|------|
| REVIEW_NOT_FOUND | 404 | 후기를 찾을 수 없습니다 | 존재하지 않는 후기 ID |
| REVIEW_CANNOT_BE_MODIFIED | 400 | 수정할 수 없는 후기입니다 | REJECTED 상태가 아닌 후기 수정 시도 |
| LECTURE_NOT_FOUND | 404 | 강의를 찾을 수 없습니다 | 존재하지 않는 강의 ID |
| LECTURE_CANNOT_BE_MODIFIED | 400 | 수정할 수 없는 강의입니다 | REJECTED 상태가 아닌 강의 수정 시도 |
| ORGANIZATION_NOT_FOUND | 404 | 기관 정보를 찾을 수 없습니다 | 기관 정보 조회 실패 |
| ACCESS_DENIED | 403 | 접근 권한이 없습니다 | 본인 소유가 아닌 리소스 접근 |
| INVALID_ROLE | 403 | 해당 기능을 사용할 수 없는 역할입니다 | USER가 강의 관리 접근 등 |

---

## 8. 테스트 계획

### 8.1 Unit Test

| 대상 | 테스트 항목 |
|------|-----------|
| MypageController | 각 엔드포인트 호출 및 권한 검증 |
| ReviewService | 반려 상태 후기 수정 시 상태 변경(PENDING) 확인 |
| ReviewService | 승인된/대기 중 후기 수정 시 예외 발생 확인 |
| LectureService | 반려 상태 강의 수정 시 상태 변경(PENDING) 확인 |
| LectureService | 승인된/대기 중 강의 수정 시 예외 발생 확인 |
| MemberSurveyService | Upsert - 기존 데이터 있을 때 Update 확인 |
| MemberSurveyService | Upsert - 기존 데이터 없을 때 Insert 확인 |

### 8.2 Integration Test

| 대상 | 테스트 항목 |
|------|-----------|
| 내 정보 수정 | 실제 DB 연동하여 프로필 수정 후 조회 검증 |
| 내 후기 목록 | 페이징, 상태 필터링 쿼리 검증 |
| 내 강의 목록 | 페이징, 상태 필터링 쿼리 검증 |
| 설문조사 Upsert | 신규 생성 및 수정 시나리오 검증 |
