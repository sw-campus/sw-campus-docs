# S3 Key 기반 아키텍처 마이그레이션 Spec

## 개요

DB에 S3 full URL 대신 key만 저장하고, 이미지 접근 시 Presigned GET URL을 발급받아 사용하는 방식으로 변경합니다.
Private 파일(수료증, 재직증명서)은 관리자만 조회 가능하며, 업로드한 본인도 조회할 수 없습니다.

---

## API

### Presigned URL 발급

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| GET | `/api/v1/storage/presigned-urls` | 단일 Presigned GET URL 발급 | △ |
| POST | `/api/v1/storage/presigned-urls/batch` | 배치 Presigned GET URL 발급 | △ |
| POST | `/api/v1/storage/presigned-urls/upload` | Presigned PUT URL 발급 (업로드용) | O |

> △: Public key는 인증 불필요, Private key는 관리자 인증 필수

---

### GET /api/v1/storage/presigned-urls

단일 S3 key에 대한 Presigned GET URL을 발급합니다.

**Query Parameters**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| key | String | O | S3 객체 key (예: `lectures/2024/01/01/uuid.jpg`) |

**Response** (200 OK):

```json
{
  "url": "https://bucket.s3.ap-northeast-2.amazonaws.com/lectures/...?X-Amz-Algorithm=...",
  "expiresIn": 900
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| url | String | Presigned GET URL |
| expiresIn | Integer | 만료 시간 (초), 기본 900초 (15분) |

**에러 응답**:

| HTTP | 조건 |
|:----:|------|
| 400 | key 파라미터 누락 |
| 403 | Private key에 대해 관리자 아닌 사용자가 요청 |
| 404 | 존재하지 않는 key |

---

### POST /api/v1/storage/presigned-urls/batch

여러 S3 key에 대한 Presigned GET URL을 일괄 발급합니다.

**Request Body**:

```json
{
  "keys": [
    "lectures/2024/01/01/thumb.jpg",
    "organizations/2024/01/02/facility1.jpg",
    "teachers/2024/01/03/profile.jpg"
  ]
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| keys | String[] | O | S3 key 목록 (최대 50개) |

**Response** (200 OK):

```json
{
  "lectures/2024/01/01/thumb.jpg": "https://bucket.s3.../lectures/...?X-Amz-...",
  "organizations/2024/01/02/facility1.jpg": "https://bucket.s3.../organizations/...?X-Amz-...",
  "teachers/2024/01/03/profile.jpg": "https://bucket.s3.../teachers/...?X-Amz-..."
}
```

> Map<String, String> 형태로 반환. Private key에 대해 권한 없으면 해당 key는 `null` 값으로 반환.

**에러 응답**:

| HTTP | 조건 |
|:----:|------|
| 400 | keys 배열이 비어있거나 50개 초과 |

---

### POST /api/v1/storage/presigned-urls/upload

S3에 파일을 업로드하기 위한 Presigned PUT URL을 발급합니다.

**Request Body**:

```json
{
  "category": "certificates",
  "fileName": "certificate.jpg",
  "contentType": "image/jpeg"
}
```

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| category | String | O | 파일 카테고리 (`lectures`, `organizations`, `teachers`, `banners`, `certificates`, `members`) |
| fileName | String | O | 원본 파일명 (확장자 추출용) |
| contentType | String | O | MIME 타입 |

**Response** (200 OK):

```json
{
  "uploadUrl": "https://bucket.s3.../certificates/2024/01/01/uuid.jpg?X-Amz-...",
  "key": "certificates/2024/01/01/uuid.jpg",
  "expiresIn": 900
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| uploadUrl | String | Presigned PUT URL |
| key | String | 생성된 S3 key (DB 저장용) |
| expiresIn | Integer | 만료 시간 (초) |

**카테고리별 버킷**:

| Category | Bucket | 설명 |
|----------|--------|------|
| lectures | Public | 강의 이미지 |
| organizations | Public | 기관 로고, 시설 이미지 |
| teachers | Public | 강사 프로필 |
| banners | Public | 배너 이미지 |
| certificates | **Private** | 수료증 (USER 업로드) |
| members | **Private** | 재직증명서/사업자등록증 (ORGANIZATION 업로드) |

---

## DB 스키마

### 마이그레이션: URL → Key 변환

기존 컬럼의 full URL을 S3 key로 변환합니다. 컬럼명은 유지합니다.

**Flyway 스크립트**: `V{N}__convert_image_url_to_key.sql`

```sql
-- URL에서 key 추출 (버킷 URL prefix 제거)
-- 예: https://bucket.s3.region.amazonaws.com/lectures/2024/01/01/uuid.jpg
--   → lectures/2024/01/01/uuid.jpg

-- lectures 테이블
UPDATE lectures
SET lecture_image_url = REGEXP_REPLACE(lecture_image_url, '^https?://[^/]+/', '')
WHERE lecture_image_url IS NOT NULL
  AND lecture_image_url LIKE 'http%';

-- organizations 테이블
UPDATE organizations
SET org_logo_url = REGEXP_REPLACE(org_logo_url, '^https?://[^/]+/', ''),
    certificate_url = REGEXP_REPLACE(certificate_url, '^https?://[^/]+/', ''),
    facility_image_url = REGEXP_REPLACE(facility_image_url, '^https?://[^/]+/', ''),
    facility_image_url2 = REGEXP_REPLACE(facility_image_url2, '^https?://[^/]+/', ''),
    facility_image_url3 = REGEXP_REPLACE(facility_image_url3, '^https?://[^/]+/', ''),
    facility_image_url4 = REGEXP_REPLACE(facility_image_url4, '^https?://[^/]+/', '')
WHERE org_logo_url LIKE 'http%'
   OR certificate_url LIKE 'http%'
   OR facility_image_url LIKE 'http%';

-- teachers 테이블
UPDATE teachers
SET teacher_image_url = REGEXP_REPLACE(teacher_image_url, '^https?://[^/]+/', '')
WHERE teacher_image_url IS NOT NULL
  AND teacher_image_url LIKE 'http%';

-- banners 테이블
UPDATE banners
SET image_url = REGEXP_REPLACE(image_url, '^https?://[^/]+/', '')
WHERE image_url IS NOT NULL
  AND image_url LIKE 'http%';

-- certificates 테이블
UPDATE certificates
SET image_url = REGEXP_REPLACE(image_url, '^https?://[^/]+/', '')
WHERE image_url IS NOT NULL
  AND image_url LIKE 'http%';
```

### 영향받는 테이블 (Public)

| 테이블 | 컬럼 | 변경 내용 |
|--------|------|----------|
| lectures | lecture_image_url | URL → Key |
| organizations | org_logo_url | URL → Key |
| organizations | facility_image_url ~ 4 | URL → Key |
| teachers | teacher_image_url | URL → Key |
| banners | image_url | URL → Key |

### 영향받는 테이블 (Private)

| 테이블 | 컬럼 | 변경 내용 |
|--------|------|----------|
| organizations | certificate_url | URL → Key |
| certificates | image_url | URL → Key |

---

## 에러 코드

### Storage 관련 예외

| Exception | HTTP | 메시지 |
|-----------|:----:|--------|
| `StorageKeyNotFoundException` | 404 | 존재하지 않는 파일입니다 |
| `StorageAccessDeniedException` | 403 | 관리자만 접근 가능합니다 |
| `StorageBatchLimitExceededException` | 400 | 최대 50개까지 요청 가능합니다 |
| `InvalidStorageCategoryException` | 400 | 지원하지 않는 카테고리입니다 |

### GlobalExceptionHandler 추가

```java
// === Storage 관련 예외 ===

@ExceptionHandler(StorageKeyNotFoundException.class)
public ResponseEntity<ErrorResponse> handleStorageKeyNotFoundException(StorageKeyNotFoundException e) {
    log.warn("Storage key 조회 실패: {}", e.getMessage());
    return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(ErrorResponse.of(HttpStatus.NOT_FOUND.value(), e.getMessage()));
}

@ExceptionHandler(StorageAccessDeniedException.class)
public ResponseEntity<ErrorResponse> handleStorageAccessDeniedException(StorageAccessDeniedException e) {
    log.warn("Storage 접근 거부: {}", e.getMessage());
    return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(ErrorResponse.of(HttpStatus.FORBIDDEN.value(), e.getMessage()));
}

@ExceptionHandler(StorageBatchLimitExceededException.class)
public ResponseEntity<ErrorResponse> handleStorageBatchLimitExceededException(StorageBatchLimitExceededException e) {
    log.warn("Storage 배치 한도 초과: {}", e.getMessage());
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(ErrorResponse.of(HttpStatus.BAD_REQUEST.value(), e.getMessage()));
}
```

---

## 보안

### 권한 매트릭스

| API | 인증 | Public Key | Private Key |
|-----|:----:|:----------:|:-----------:|
| GET /presigned-urls | X | O | X |
| GET /presigned-urls | O (USER/ORG) | O | X |
| GET /presigned-urls | O (ADMIN) | O | O |
| POST /presigned-urls/batch | X | O | null 반환 |
| POST /presigned-urls/batch | O (ADMIN) | O | O |
| POST /presigned-urls/upload | O | 카테고리별 권한 | 카테고리별 권한 |

### 업로드 카테고리별 권한

| Category | ADMIN | ORGANIZATION | USER |
|----------|:-----:|:------------:|:----:|
| banners | O | X | X |
| lectures | O | O | X |
| organizations | O | O | X |
| teachers | O | O | X |
| thumbnails | O | O | X |
| certificates | O | O | O |
| employment-certificates | O | O | O |
| members | O | O | O |

### Private Key 판별 로직

```java
public boolean isPrivateKey(String key) {
    return key.startsWith("certificates/") || key.startsWith("members/");
}

public boolean canAccessPrivateKey(String key, boolean isAdmin) {
    if (!isPrivateKey(key)) {
        return true;  // Public key는 모두 접근 가능
    }
    return isAdmin;  // Private key는 관리자만 접근 가능
}
```

### 보안 고려사항

1. **Presigned URL 만료**: 15분으로 제한하여 URL 유출 피해 최소화
2. **HTTPS 전용**: Presigned URL은 HTTPS로만 생성
3. **업로드 후 조회 불가**: Private 파일은 업로드한 본인도 조회 불가
4. **S3Presigner**: 로컬에서 서명만 생성 (S3 네트워크 호출 없음)

---

## Backend 구현 파일

### 신규 파일

| 모듈 | 경로 | 설명 |
|------|------|------|
| infra/s3 | `S3PresignedService.java` | Presigned URL 생성 서비스 인터페이스 |
| infra/s3 | `S3PresignedServiceImpl.java` | AWS SDK S3Presigner 구현체 |
| domain | `storage/PresignedUrlService.java` | 도메인 서비스 인터페이스 |
| domain | `storage/StorageAccessService.java` | 권한 체크 서비스 |
| domain | `storage/exception/*.java` | Storage 예외 클래스들 |
| api | `storage/StorageController.java` | Presigned URL API 컨트롤러 |
| api | `storage/request/*.java` | Request DTO |
| api | `storage/response/*.java` | Response DTO |

### 수정 파일

| 모듈 | 경로 | 변경 내용 |
|------|------|----------|
| api | `exception/GlobalExceptionHandler.java` | Storage 예외 핸들러 추가 |
| infra/db | `migration/V{N}__*.sql` | URL→Key 마이그레이션 스크립트 |

---

## Frontend 구현 파일

### 신규 파일

| 경로 | 설명 |
|------|------|
| `features/storage/hooks/usePresignedUrl.ts` | 단일 Presigned URL 훅 |
| `features/storage/hooks/usePresignedUrls.ts` | 배치 Presigned URL 훅 |
| `features/storage/components/S3Image.tsx` | S3 이미지 컴포넌트 |

### 수정 파일

| 경로 | 변경 내용 |
|------|----------|
| `features/storage/types/storage.type.ts` | Presigned GET 타입 추가 |
| `features/storage/api/storageApi.ts` | Presigned GET API 함수 추가 |
| `features/storage/index.ts` | S3Image, usePresignedUrl export |

### 컴포넌트 마이그레이션

기존 `<Image src={imageUrl}>` → `<S3Image s3Key={imageKey}>`로 변경

| 컴포넌트 | 파일 경로 |
|----------|----------|
| LectureIntro | `features/lecture/components/detail/LectureIntro.tsx` |
| LectureOverview | `features/lecture/components/detail/LectureOverview.tsx` |
| LargeBanner | `features/banner/components/LargeBanner.tsx` |
| MidBanner | `features/banner/components/MidBanner.tsx` |
| SmallBanner | `features/banner/components/SmallBanner.tsx` |
| OrganizationCard | `features/organization/components/OrganizationCard.tsx` |
| LectureSummaryCard | `features/cart/components/compare-table/LectureSummaryCard.tsx` |
| CertificateDetailModal | `features/admin/components/certificate/CertificateDetailModal.tsx` |

---

## 성능 요구사항

| 항목 | 목표 | 비고 |
|------|------|------|
| 단일 Presigned URL 발급 | < 100ms | S3Presigner는 네트워크 호출 없음 |
| 배치 Presigned URL (10개) | < 300ms | 루프 처리 |
| 최대 배치 크기 | 50개 | 메모리/응답 크기 제한 |
| React Query staleTime | 5분 | URL 만료(15분)보다 짧게 |
| React Query gcTime | 10분 | staleTime보다 길게 |

---

## 테스트 체크리스트

### Backend

- [ ] Public key에 대해 비인증 Presigned URL 발급 성공
- [ ] Private key에 대해 비인증 요청 시 403 반환
- [ ] Private key에 대해 관리자 요청 시 Presigned URL 발급 성공
- [ ] Private key에 대해 일반 사용자 요청 시 403 반환
- [ ] 배치 API에서 Private key 포함 시 권한 없으면 null 반환
- [ ] 배치 API 50개 초과 요청 시 400 반환
- [ ] Presigned PUT URL 발급 성공 (Public/Private 카테고리)
- [ ] DB 마이그레이션 스크립트 정상 실행

### Frontend

- [ ] usePresignedUrl hook 정상 동작
- [ ] usePresignedUrls hook 정상 동작 (배치)
- [ ] S3Image 컴포넌트 렌더링
- [ ] S3Image key가 null일 때 fallback 표시
- [ ] React Query 캐싱 동작 (5분 staleTime)
- [ ] 기존 컴포넌트 → S3Image 교체 후 정상 표시

---

## 구현 노트

### 2025-12-22 - Private 파일 S3 Key 저장 방식 구현

- Server PR: #200
- Client PR: #68
- 주요 변경:
  - **Backend**
    - `StorageController` 추가: Presigned GET/PUT URL 발급 API
    - `PresignedUrlService` 인터페이스 및 `S3PresignedUrlService` 구현
    - `uploadPrivate()` 메서드가 S3 Key만 반환하도록 변경
    - Certificate: `imageUrl` → `imageKey` 필드명 변경
    - Organization: `certificateUrl` → `certificateKey` 필드명 변경
    - 카테고리별 업로드 권한 체크 로직 추가
    - API URL 컨벤션 준수: `/presigned-urls` (복수형)
  - **Frontend**
    - `S3Image` 컴포넌트 추가: Presigned URL로 이미지 표시
    - `usePresignedUrl`, `usePresignedUrls` 훅 추가
    - `CertificateDetailModal`, `OrganizationDetailModal`에 S3Image 적용
    - 기존 URL 데이터 호환성 유지 (URL이면 직접 사용, Key면 Presigned URL 발급)
- 특이사항:
  - `next/image` 대신 일반 `<img>` 태그 사용 (동적 S3 도메인 호환)
  - staleTime(5분) < URL 만료 시간(15분)으로 캐시 안전성 확보
