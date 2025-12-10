# 후기 (Review) - Tech Spec

> Technical Specification

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-10 |
| 상태 | Draft |
| 버전 | 0.1 |
| PRD | [prd.md](./prd.md) |

---

## 1. 개요

### 1.1 목적

PRD에 정의된 후기 기능(수료증 인증, 후기 작성/수정/삭제, 관리자 승인)의 기술적 구현 명세를 정의합니다.

### 1.2 기술 스택

| 구분 | 기술 |
|------|------|
| Framework | Spring Boot 3.x |
| Security | Spring Security 6.x |
| Database | PostgreSQL |
| ORM | Spring Data JPA |
| Storage | AWS S3 |
| OCR | sw-campus-ai (FastAPI + PaddleOCR) |

---

## 2. 시스템 아키텍처

### 2.1 모듈 구조

```
sw-campus-server/
├── sw-campus-api/                    # Presentation Layer
│   ├── review/
│   │   ├── ReviewController.java
│   │   ├── request/
│   │   └── response/
│   ├── certificate/
│   │   ├── CertificateController.java
│   │   ├── request/
│   │   └── response/
│   └── admin/
│       └── AdminReviewController.java
│
├── sw-campus-domain/                 # Business Logic Layer
│   ├── review/
│   │   ├── Review.java
│   │   ├── ReviewDetail.java
│   │   ├── ReviewRepository.java
│   │   ├── ReviewDetailRepository.java
│   │   ├── ReviewService.java
│   │   ├── ApprovalStatus.java (enum)
│   │   └── ReviewCategory.java (enum)
│   └── certificate/
│       ├── Certificate.java
│       ├── CertificateRepository.java
│       └── CertificateService.java
│
├── sw-campus-infra/
│   ├── db-postgres/                  # Infrastructure Layer - DB
│   │   ├── review/
│   │   │   ├── ReviewEntity.java
│   │   │   ├── ReviewJpaRepository.java
│   │   │   ├── ReviewEntityRepository.java
│   │   │   ├── ReviewDetailEntity.java
│   │   │   ├── ReviewDetailJpaRepository.java
│   │   │   └── ReviewDetailEntityRepository.java
│   │   └── certificate/
│   │       ├── CertificateEntity.java
│   │       ├── CertificateJpaRepository.java
│   │       └── CertificateEntityRepository.java
│   ├── s3/                           # Infrastructure Layer - S3
│   │   └── S3StorageService.java
│   └── ocr/                          # Infrastructure Layer - OCR (sw-campus-ai 연동)
│       ├── OcrClient.java (interface)
│       ├── OcrClientImpl.java        # FastAPI 서버 호출
│       └── OcrResponse.java          # OCR 응답 DTO
```

### 2.2 컴포넌트 구조

#### sw-campus-api

```
com.swcampus.api/
├── review/
│   ├── ReviewController.java
│   ├── request/
│   │   ├── CreateReviewRequest.java
│   │   ├── UpdateReviewRequest.java
│   │   └── ReviewDetailRequest.java
│   └── response/
│       ├── ReviewResponse.java
│       ├── ReviewDetailResponse.java
│       └── ReviewCheckResponse.java
├── certificate/
│   ├── CertificateController.java
│   ├── request/
│   │   └── VerifyCertificateRequest.java
│   └── response/
│       ├── CertificateCheckResponse.java
│       └── CertificateVerifyResponse.java
└── admin/
    ├── AdminReviewController.java
    └── response/
        ├── AdminReviewListResponse.java
        └── AdminCertificateResponse.java
```

#### sw-campus-domain

```
com.swcampus.domain/
├── review/
│   ├── Review.java
│   ├── ReviewDetail.java
│   ├── ReviewRepository.java
│   ├── ReviewDetailRepository.java
│   ├── ReviewService.java
│   ├── ApprovalStatus.java (enum: PENDING, APPROVED, REJECTED)
│   ├── ReviewCategory.java (enum: TEACHER, CURRICULUM, MANAGEMENT, FACILITY, PROJECT)
│   └── exception/
│       ├── ReviewNotFoundException.java
│       ├── ReviewAlreadyExistsException.java
│       ├── ReviewNotAuthorizedException.java
│       └── CertificateNotVerifiedException.java
├── certificate/
│   ├── Certificate.java
│   ├── CertificateRepository.java
│   ├── CertificateService.java
│   └── exception/
│       ├── CertificateNotFoundException.java
│       └── CertificateVerificationFailedException.java
└── member/
    └── (기존 MemberService - 닉네임 업데이트 메서드 추가)
```

#### sw-campus-infra

```
com.swcampus.infra/
├── postgres/
│   ├── review/
│   │   ├── ReviewEntity.java
│   │   ├── ReviewJpaRepository.java
│   │   ├── ReviewEntityRepository.java
│   │   ├── ReviewDetailEntity.java
│   │   ├── ReviewDetailJpaRepository.java
│   │   └── ReviewDetailEntityRepository.java
│   └── certificate/
│       ├── CertificateEntity.java
│       ├── CertificateJpaRepository.java
│       └── CertificateEntityRepository.java
├── s3/
│   └── S3StorageService.java
└── ocr/
    ├── OcrClient.java
    └── OcrClientImpl.java
```

---

## 3. API 설계

### 3.1 닉네임 설정

#### `PATCH /api/v1/members/me/nickname`

닉네임 업데이트 (JWT hasNickname 플래그 갱신)

**Request**
```
Cookie: accessToken=...
```

```json
{
  "nickname": "새닉네임"
}
```

**Response** `200 OK`
```
Set-Cookie: accessToken=...; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=3600
```

```json
{
  "userId": 1,
  "nickname": "새닉네임"
}
```

> 닉네임 설정 완료 시 `hasNickname: true`가 포함된 새 Access Token 발급

**Errors**
- `400` MEMBER001: 닉네임 형식 오류
- `409` MEMBER002: 이미 사용 중인 닉네임

---

### 3.2 수료증 인증

#### `GET /api/v1/certificates/check`

수료증 인증 여부 확인

**Request**
```
Cookie: accessToken=...
```

**Query Parameters**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| lectureId | Long | ✅ | 강의 ID |

**Response** `200 OK`
```json
{
  "lectureId": 1,
  "certified": true,
  "certifiedAt": "2025-12-10T10:30:00"
}
```

---

#### `POST /api/v1/certificates/verify`

수료증 인증 요청 (이미지 업로드 + OCR 검증)

**Request** `multipart/form-data`
```
Cookie: accessToken=...
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| lectureId | Long | ✅ | 강의 ID |
| image | file | ✅ | 수료증 이미지 |

**Response** `201 Created`
```json
{
  "certificateId": 1,
  "lectureId": 1,
  "certified": true,
  "imageUrl": "https://s3.../certificates/...",
  "certifiedAt": "2025-12-10T10:30:00"
}
```

**Errors**
- `400` CERT001: 이미지 형식 오류 (jpg, png만 허용)
- `400` CERT002: 이미지 크기 초과 (최대 5MB)
- `400` CERT003: OCR 인식 실패
- `400` CERT004: 강의명 불일치 (해당 강의의 수료증이 아닙니다)
- `404` LECTURE001: 강의를 찾을 수 없습니다
- `409` CERT005: 이미 인증된 수료증입니다

---

### 3.3 후기 작성

#### `GET /api/v1/reviews/check`

후기 작성 가능 여부 확인

**Request**
```
Cookie: accessToken=...
```

**Query Parameters**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| lectureId | Long | ✅ | 강의 ID |

**Response** `200 OK`
```json
{
  "lectureId": 1,
  "canWrite": true,
  "existingReviewId": null
}
```

또는 이미 작성한 경우:
```json
{
  "lectureId": 1,
  "canWrite": false,
  "existingReviewId": 123
}
```

---

#### `POST /api/v1/reviews`

후기 작성

**Request**
```
Cookie: accessToken=...
```

```json
{
  "lectureId": 1,
  "comment": "전체적으로 만족스러운 강의였습니다.",
  "detailScores": [
    { "category": "TEACHER", "score": 4.5, "comment": "강사님이 친절하고 설명을 잘 해주셔서 이해하기 쉬웠습니다." },
    { "category": "CURRICULUM", "score": 4.0, "comment": "커리큘럼이 체계적이고 실무에 도움이 되는 내용이었습니다." },
    { "category": "MANAGEMENT", "score": 4.5, "comment": "취업지원과 행정 서비스가 잘 되어있었습니다." },
    { "category": "FACILITY", "score": 3.5, "comment": "시설은 보통이었지만 학습에는 문제없었습니다." },
    { "category": "PROJECT", "score": 5.0, "comment": "프로젝트 경험이 정말 유익했고 포트폴리오에 도움이 됐습니다." }
  ]
}
```

**Response** `201 Created`
```json
{
  "reviewId": 1,
  "lectureId": 1,
  "userId": 1,
  "nickname": "사용자닉네임",
  "comment": "정말 유익한 강의였습니다...",
  "score": 4.3,
  "approvalStatus": "PENDING",
  "detailScores": [
    { "category": "TEACHER", "score": 4.5, "comment": "강사님이 친절하고 설명을 잘 해주셨습니다." },
    { "category": "CURRICULUM", "score": 4.0, "comment": "커리큘럼이 체계적이었습니다." },
    { "category": "MANAGEMENT", "score": 4.5, "comment": "취업지원이 잘 되어있었습니다." },
    { "category": "FACILITY", "score": 3.5, "comment": "시설은 보통이었습니다." },
    { "category": "PROJECT", "score": 5.0, "comment": "프로젝트 경험이 유익했습니다." }
  ],
  "createdAt": "2025-12-10T10:30:00"
}
```

> `score`는 `detailScores`의 평균으로 자동 계산
> `comment`(총평)는 선택사항이며 최대 500자입니다

**Errors**
- `400` REVIEW001: 카테고리별 후기는 20~500자입니다
- `400` REVIEW002: 상세 별점은 5개 카테고리 모두 필수입니다
- `400` REVIEW003: 별점은 1.0 ~ 5.0 사이여야 합니다
- `400` REVIEW004: 총평은 최대 500자입니다
- `401` AUTH003: 인증이 필요합니다
- `403` REVIEW004: 닉네임 설정이 필요합니다
- `403` CERT006: 수료증 인증이 필요합니다
- `404` LECTURE001: 강의를 찾을 수 없습니다
- `409` REVIEW005: 이미 후기를 작성한 강의입니다

---

### 3.4 후기 조회/수정/삭제

#### `GET /api/v1/reviews/{reviewId}`

후기 단건 조회

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "lectureId": 1,
  "userId": 1,
  "nickname": "사용자닉네임",
  "comment": "정말 유익한 강의였습니다...",
  "score": 4.3,
  "blurred": false,
  "approvalStatus": "APPROVED",
  "detailScores": [
    { "category": "TEACHER", "score": 4.5, "comment": "강사님이 친절하고 설명을 잘 해주셨습니다." },
    { "category": "CURRICULUM", "score": 4.0, "comment": "커리큘럼이 체계적이었습니다." },
    { "category": "MANAGEMENT", "score": 4.5, "comment": "취업지원이 잘 되어있었습니다." },
    { "category": "FACILITY", "score": 3.5, "comment": "시설은 보통이었습니다." },
    { "category": "PROJECT", "score": 5.0, "comment": "프로젝트 경험이 유익했습니다." }
  ],
  "createdAt": "2025-12-10T10:30:00",
  "updatedAt": "2025-12-10T10:30:00"
}
```

**Errors**
- `404` REVIEW006: 후기를 찾을 수 없습니다

---

#### `PUT /api/v1/reviews/{reviewId}`

후기 수정

**Request**
```
Cookie: accessToken=...
```

```json
{
  "comment": "수정된 후기 내용입니다...",
  "detailScores": [
    { "category": "TEACHER", "score": 5.0 },
    { "category": "CURRICULUM", "score": 4.5 },
    { "category": "MANAGEMENT", "score": 4.5 },
    { "category": "FACILITY", "score": 4.0 },
    { "category": "PROJECT", "score": 5.0 }
  ]
}
```

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "comment": "수정된 후기 내용입니다...",
  "score": 4.6,
  "detailScores": [...],
  "updatedAt": "2025-12-10T11:00:00"
}
```

**Errors**
- `403` REVIEW007: 본인의 후기만 수정할 수 있습니다
- `404` REVIEW006: 후기를 찾을 수 없습니다

---

### 3.5 관리자 - 후기 관리

> **2단계 검토 프로세스**: 수료증 승인 → 후기 승인 (단계별 모달)

#### `GET /api/v1/admin/reviews`

승인 대기 후기 목록 조회

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Query Parameters**
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|-------|------|
| status | String | ❌ | PENDING | 후기 승인 상태 (PENDING, APPROVED, REJECTED) |
| page | Integer | ❌ | 0 | 페이지 번호 |
| size | Integer | ❌ | 20 | 페이지 크기 |

**Response** `200 OK`
```json
{
  "content": [
    {
      "reviewId": 1,
      "lectureId": 1,
      "lectureName": "Java 풀스택 개발자 과정",
      "userId": 1,
      "userName": "홍길동",
      "nickname": "길동이",
      "comment": "정말 유익한 강의였습니다...",
      "score": 4.3,
      "approvalStatus": "PENDING",
      "certificateApprovalStatus": "PENDING",
      "createdAt": "2025-12-10T10:30:00"
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 1,
  "totalPages": 1
}
```

---

#### `GET /api/v1/admin/reviews/{reviewId}/certificate`

후기의 수료증 정보 조회 (1단계 모달용)

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "certificateId": 1,
  "lectureName": "Java 풀스택 개발자 과정",
  "imageUrl": "https://s3.../certificates/...",
  "approvalStatus": "PENDING",
  "certifiedAt": "2025-12-10T10:30:00"
}
```

---

#### `PATCH /api/v1/admin/certificates/{certificateId}/approve`

1단계: 수료증 승인

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Response** `200 OK`
```json
{
  "certificateId": 1,
  "approvalStatus": "APPROVED",
  "message": "수료증이 승인되었습니다. 후기 내용을 확인해주세요."
}
```

---

#### `PATCH /api/v1/admin/certificates/{certificateId}/reject`

1단계: 수료증 반려

> 수료증 반려 시 **반려 이메일**이 사용자에게 발송됩니다.
> 수료증이 반려되면 2단계(후기 검토)로 진행되지 않습니다.

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Response** `200 OK`
```json
{
  "certificateId": 1,
  "approvalStatus": "REJECTED",
  "message": "수료증이 반려되었습니다. 반려 이메일이 발송됩니다."
}
```

---

#### `GET /api/v1/admin/reviews/{reviewId}`

후기 상세 조회 (2단계 모달용)

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "lectureId": 1,
  "lectureName": "Java 풀스택 개발자 과정",
  "userId": 1,
  "userName": "홍길동",
  "nickname": "길동이",
  "comment": "정말 유익한 강의였습니다...",
  "score": 4.3,
  "approvalStatus": "PENDING",
  "certificateApprovalStatus": "APPROVED",
  "detailScores": [
    { "category": "TEACHER", "score": 4.5 },
    { "category": "CURRICULUM", "score": 4.0 },
    { "category": "MANAGEMENT", "score": 4.5 },
    { "category": "FACILITY", "score": 3.5 },
    { "category": "PROJECT", "score": 5.0 }
  ],
  "createdAt": "2025-12-10T10:30:00"
}
```

---

#### `PATCH /api/v1/admin/reviews/{reviewId}/approve`

2단계: 후기 승인

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "approvalStatus": "APPROVED",
  "approvedAt": "2025-12-10T11:00:00",
  "message": "후기가 승인되었습니다. 일반 사용자에게 노출됩니다."
}
```

---

#### `PATCH /api/v1/admin/reviews/{reviewId}/reject`

2단계: 후기 반려

> **전제조건**: 수료증이 **승인**된 상태에서만 후기 반려가 가능합니다.
> 후기 반려 시 **반려 이메일**이 사용자에게 발송됩니다.
> **반려**: 후기가 목록에 **아예 표시되지 않음** (미노출)

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "approvalStatus": "REJECTED",
  "message": "후기가 반려되었습니다. 반려 이메일이 발송됩니다."
}
```

---

#### `PATCH /api/v1/admin/reviews/{reviewId}/blind`

후기 블라인드 처리

> **블라인드**: 후기가 목록에 **표시**됨 (UI 처리는 프론트엔드에서 결정)

**Request**
```
Cookie: accessToken=... (ADMIN 권한 필요)
```

```json
{
  "blurred": true
}
```

**Response** `200 OK`
```json
{
  "reviewId": 1,
  "blurred": true,
  "message": "후기가 블라인드 처리되었습니다"
}
```

> 블라인드 해제 시 `blurred: false`로 요청

---

## 4. 데이터베이스 스키마

### 4.1 기존 테이블 수정

#### REVIEWS

```sql
-- 기존 테이블에 APPROVAL_STATUS 컬럼 추가
ALTER TABLE REVIEWS 
ADD COLUMN APPROVAL_STATUS SMALLINT NOT NULL DEFAULT 0;

-- 인덱스 추가
CREATE INDEX idx_reviews_approval_status ON REVIEWS(APPROVAL_STATUS);
CREATE INDEX idx_reviews_lecture_id ON REVIEWS(LECTURE_ID);
CREATE INDEX idx_reviews_user_id ON REVIEWS(USER_ID);
CREATE UNIQUE INDEX idx_reviews_user_lecture ON REVIEWS(USER_ID, LECTURE_ID);
```

**컬럼 정의**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| REVIEW_ID | BIGSERIAL | PK |
| LECTURE_ID | BIGINT | FK → LECTURES |
| USER_ID | BIGINT | FK → MEMBERS |
| COMMENT | TEXT | 후기 내용 |
| SCORE | DECIMAL(2,1) | 전체 별점 (상세 별점 평균) |
| BLURRED | BOOLEAN | 블라인드 여부 (기본값: false) |
| APPROVAL_STATUS | SMALLINT | 승인 상태 (0: PENDING, 1: APPROVED, 2: REJECTED) |
| CREATED_AT | TIMESTAMPTZ | 생성일시 |
| UPDATED_AT | TIMESTAMPTZ | 수정일시 |

#### CERTIFICATES

```sql
-- 기존 테이블에 APPROVAL_STATUS, CREATED_AT 컬럼 추가
ALTER TABLE CERTIFICATES 
ADD COLUMN APPROVAL_STATUS SMALLINT NOT NULL DEFAULT 0,
ADD COLUMN CREATED_AT TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- 인덱스 추가
CREATE INDEX idx_certificates_user_id ON CERTIFICATES(USER_ID);
CREATE INDEX idx_certificates_approval_status ON CERTIFICATES(APPROVAL_STATUS);
CREATE UNIQUE INDEX idx_certificates_user_lecture ON CERTIFICATES(USER_ID, LECTURE_ID);
```

**컬럼 정의**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| CERTIFICATE_ID | BIGSERIAL | PK |
| USER_ID | BIGINT | FK → MEMBERS |
| LECTURE_ID | BIGINT | FK → LECTURES |
| STATUS | BOOLEAN | OCR 인증 여부 |
| IMAGE_URL | TEXT | 수료증 이미지 S3 URL |
| APPROVAL_STATUS | SMALLINT | 관리자 승인 상태 (0: PENDING, 1: APPROVED, 2: REJECTED) |
| CREATED_AT | TIMESTAMPTZ | 인증 일시 |

### 4.2 기존 테이블 확인 (REVIEWS_DETAILS)

```sql
-- 기존 ERD 기반
-- 주의: 원본 스키마의 PK 컬럼명은 "REVEIW_DETAIL_ID" (오타)
-- Entity에서 @Column(name = "REVEIW_DETAIL_ID")로 매핑 필요
CREATE TABLE REVIEWS_DETAILS (
    REVEIW_DETAIL_ID BIGSERIAL PRIMARY KEY,
    REVIEW_ID BIGINT NOT NULL REFERENCES REVIEWS(REVIEW_ID) ON DELETE CASCADE,
    CATEGORY VARCHAR(20) NOT NULL,
    SCORE DECIMAL(2,1) NOT NULL,
    DETAIL_COMMENT TEXT,
    CONSTRAINT chk_category CHECK (CATEGORY IN ('TEACHER', 'CURRICULUM', 'MANAGEMENT', 'FACILITY', 'PROJECT'))
);

CREATE INDEX idx_review_details_review_id ON REVIEWS_DETAILS(REVIEW_ID);
```

---

## 5. Enum 정의

### 5.1 ApprovalStatus

```java
public enum ApprovalStatus {
    PENDING(0),    // 승인 대기
    APPROVED(1),   // 승인 완료
    REJECTED(2);   // 반려

    private final int value;
}
```

### 5.2 ReviewCategory

```java
public enum ReviewCategory {
    TEACHER,       // 강사진
    CURRICULUM,    // 커리큘럼(학습지원)
    MANAGEMENT,    // 운영 및 학습환경
    FACILITY,      // 취업지원
    PROJECT        // 프로젝트
}
```

---

## 6. JWT 변경사항

### 6.1 Access Token Payload

**기존**
```json
{
  "sub": "1",
  "email": "user@example.com",
  "role": "USER",
  "iat": 1701763200,
  "exp": 1701766800
}
```

**변경 (hasNickname 추가)**
```json
{
  "sub": "1",
  "email": "user@example.com",
  "role": "USER",
  "hasNickname": true,
  "iat": 1701763200,
  "exp": 1701766800
}
```

### 6.2 닉네임 설정 시 토큰 재발급

1. 사용자가 닉네임 설정
2. DB에 닉네임 업데이트
3. `hasNickname: true`가 포함된 새 Access Token 발급
4. 프론트엔드에서 새 토큰으로 교체

---

## 7. 보안 설계

### 7.1 인증/인가 규칙

| API | 인증 | 권한 | 추가 조건 |
|-----|:----:|------|----------|
| 수료증 확인 | ✅ | USER | - |
| 수료증 인증 | ✅ | USER | - |
| 후기 작성 가능 확인 | ✅ | USER | - |
| 후기 작성 | ✅ | USER | hasNickname: true, 수료증 인증 완료 |
| 후기 조회 | ❌ | - | - |
| 후기 수정 | ✅ | USER | 작성자 본인만 |
| 관리자 후기 목록 | ✅ | ADMIN | - |
| 관리자 수료증 조회 | ✅ | ADMIN | - |
| 관리자 수료증 승인 | ✅ | ADMIN | 1단계 검토 |
| 관리자 수료증 반려 | ✅ | ADMIN | 1단계 검토, 반려 이메일 발송 |
| 관리자 후기 상세 조회 | ✅ | ADMIN | 2단계 검토 |
| 관리자 후기 승인 | ✅ | ADMIN | 2단계 검토, 수료증 승인 후 |
| 관리자 후기 반려 | ✅ | ADMIN | 2단계 검토 |
| 관리자 블라인드 처리 | ✅ | ADMIN | - |

### 7.2 수료증 이미지 보안

| 항목 | 설정 |
|------|------|
| 저장 위치 | AWS S3 (private bucket) |
| 접근 방식 | Presigned URL (15분 만료) |
| 허용 형식 | jpg, jpeg, png |
| 최대 크기 | 5MB |

### 7.3 후기 작성 조건 검증 순서

```
1. 로그인 확인 (JWT 유효성)
2. hasNickname 확인 (JWT payload)
3. 수료증 인증 확인 (DB 조회)
4. 기존 후기 존재 여부 확인 (DB 조회)
5. 후기 작성 처리
```

---

## 8. 에러 코드

### 8.1 회원 (Member)

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| MEMBER001 | 400 | 닉네임 형식이 올바르지 않습니다 |
| MEMBER002 | 409 | 이미 사용 중인 닉네임입니다 |

### 8.2 수료증 (Certificate)

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| CERT001 | 400 | 이미지 형식이 올바르지 않습니다 (jpg, png만 허용) |
| CERT002 | 400 | 이미지 크기가 5MB를 초과합니다 |
| CERT003 | 400 | 수료증 이미지를 인식할 수 없습니다 |
| CERT004 | 400 | 해당 강의의 수료증이 아닙니다 |
| CERT005 | 409 | 이미 인증된 수료증입니다 |
| CERT006 | 403 | 수료증 인증이 필요합니다 |

### 8.3 후기 (Review)

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| REVIEW001 | 400 | 후기 내용은 필수입니다 |
| REVIEW002 | 400 | 상세 별점은 5개 카테고리 모두 필수입니다 |
| REVIEW003 | 400 | 별점은 1.0 ~ 5.0 사이여야 합니다 |
| REVIEW004 | 403 | 닉네임 설정이 필요합니다 |
| REVIEW005 | 409 | 이미 후기를 작성한 강의입니다 |
| REVIEW006 | 404 | 후기를 찾을 수 없습니다 |
| REVIEW007 | 403 | 본인의 후기만 수정할 수 있습니다 |
| REVIEW008 | 400 | 승인 대기 상태의 후기만 반려할 수 있습니다 |

### 8.4 강의 (Lecture)

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| LECTURE001 | 404 | 강의를 찾을 수 없습니다 |

---

## 9. 외부 연동

### 9.1 OCR 서버 연동 (sw-campus-ai)

> OCR 서버는 `sw-campus-ai` (Python FastAPI) 서버를 사용합니다.
> PaddleOCR 기반으로 수료증 이미지에서 텍스트를 추출합니다.

**서버 정보**

| 항목 | 값 |
|------|-----|
| 서버 | sw-campus-ai |
| 프레임워크 | FastAPI |
| OCR 엔진 | PaddleOCR 3.3.2 |
| 환경변수 | `OCR_SERVER_URL` (예: http://localhost:8000) |

**Request**
```
POST {OCR_SERVER_URL}/ocr/extract
Content-Type: multipart/form-data

image: (binary) - 수료증 이미지 파일
```

**Response** `200 OK`
```json
{
  "text": "수료증\nJava 풀스택 개발자 과정\n홍길동\n2025년 11월 30일\nOO교육기관",
  "lines": [
    "수료증",
    "Java 풀스택 개발자 과정",
    "홍길동",
    "2025년 11월 30일",
    "OO교육기관"
  ],
  "scores": [0.98, 0.95, 0.97, 0.96, 0.94]
}
```

**백엔드 처리 로직**

```
1. 수료증 이미지를 OCR 서버로 전송
2. OCR 서버에서 텍스트 추출 (lines 배열)
3. 추출된 텍스트에서 강의명 포함 여부 검증 (유연한 매칭)
4. 검증 성공 시 수료증 인증 완료 처리
5. 검증 실패 시 에러 반환 (CERT004)
```

**강의명 검증 로직 (유연한 매칭)**

OCR 결과는 이미지 품질, 폰트, 레이아웃에 따라 띄어쓰기/오타가 발생할 수 있으므로 **유연한 매칭**을 적용합니다.

| 단계 | 처리 | 설명 |
|:----:|------|------|
| 1 | 공백 정규화 | 모든 공백을 제거하여 비교 |
| 2 | 대소문자 무시 | 영문은 소문자로 변환 후 비교 |
| 3 | 부분 일치 검사 | OCR 텍스트에 강의명이 포함되어 있는지 확인 |

```java
// 예시 코드
public boolean isLectureNameMatch(String dbLectureName, String ocrText) {
    // 공백 제거 + 소문자 변환
    String normalizedDb = dbLectureName.replaceAll("\\s+", "").toLowerCase();
    String normalizedOcr = ocrText.replaceAll("\\s+", "").toLowerCase();
    
    // 부분 일치 확인
    return normalizedOcr.contains(normalizedDb);
}
```

**매칭 예시**

| DB 강의명 | OCR 추출 결과 | 매칭 결과 |
|----------|--------------|:---------:|
| `Java 풀스택 개발자 과정` | `Java풀스택 개발자과정` | ✅ |
| `Java 풀스택 개발자 과정` | `Java 풀스택  개발자 과정` | ✅ |
| `Java 풀스택 개발자 과정` | `Python 백엔드 과정` | ❌ |

> **Note**: OCR은 텍스트 추출만 담당하고, 강의명 검증 로직은 백엔드에서 처리합니다.
```

### 9.2 S3 연동

| 버킷 | 경로 | 용도 |
|------|------|------|
| sw-campus-bucket | /certificates/{userId}/{filename} | 수료증 이미지 |

### 9.3 이메일 서버 연동

반려 시 사용자에게 이메일이 발송됩니다.

| 반려 유형 | 이메일 제목 | 이메일 내용 |
|----------|-----------|-----------|
| 수료증 반려 | [SW Campus] 수료증 인증이 반려되었습니다 | 제출하신 수료증이 검증에 실패했습니다. 올바른 수료증을 다시 제출해주세요. |
| 후기 반려 | [SW Campus] 후기가 반려되었습니다 | 작성하신 후기가 관리자 검토 결과 반려되었습니다. 부적절한 내용이 포함되어 있습니다. |

> **Note**: 
> - 수료증 반려 시 → 수료증 반려 이메일만 발송 (2단계로 진행되지 않음)
> - 후기 반려 시 → 후기 반려 이메일만 발송 (수료증은 이미 승인된 상태)
> - 둘 다 반려될 일은 없음 (단계별 순차 진행)

---

## 10. 시퀀스 다이어그램

- [후기 시퀀스](../../sequence/review/review_diagram.md)
- [관리자 후기 승인 시퀀스](../../sequence/review/admin_review_approval_diagram.md)

---

## 11. 관련 문서

- [PRD](./prd.md)
- [Development Plan](./plan/)
- [Implementation Report](./report/)

---

## 12. 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 0.1 | 2025-12-10 | 초안 작성 |
