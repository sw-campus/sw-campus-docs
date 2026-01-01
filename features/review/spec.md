# 후기 (Review) Spec

## 개요

수료증 인증, 후기 작성/수정/삭제, 관리자 승인 기능의 기술 명세입니다.

---

## API

### 수료증 인증

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/certificates/check?lectureId={id}` | 인증 여부 확인 | USER |
| POST | `/api/v1/certificates/verify` | 수료증 인증 (multipart) | USER |

### 후기 CRUD

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/reviews/check?lectureId={id}` | 작성 가능 여부 확인 | USER |
| POST | `/api/v1/reviews` | 후기 작성 | USER |
| GET | `/api/v1/reviews/{reviewId}` | 후기 조회 | X |
| PUT | `/api/v1/reviews/{reviewId}` | 후기 수정 (PENDING/REJECTED만 가능) | USER |

**후기 작성 조건**: 닉네임 설정 완료 + 수료증 인증 완료

**후기 수정 조건**: APPROVED 상태가 아닌 후기만 수정 가능 (PENDING, REJECTED)

### 관리자 - 2단계 검토

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/admin/reviews` | 승인 대기 목록 | ADMIN |
| GET | `/api/v1/admin/reviews/all` | 전체 후기 목록 (필터링/페이지네이션) | ADMIN |
| GET | `/api/v1/admin/reviews/{id}/certificate` | 수료증 조회 (1단계) | ADMIN |
| PATCH | `/api/v1/admin/certificates/{id}/approve` | 수료증 승인 | ADMIN |
| PATCH | `/api/v1/admin/certificates/{id}/reject` | 수료증 반려 | ADMIN |
| GET | `/api/v1/admin/reviews/{id}` | 후기 상세 (2단계) | ADMIN |
| PATCH | `/api/v1/admin/reviews/{id}/approve` | 후기 승인 | ADMIN |
| PATCH | `/api/v1/admin/reviews/{id}/reject` | 후기 반려 | ADMIN |
| PATCH | `/api/v1/admin/reviews/{id}/blind` | 블라인드 처리 | ADMIN |

#### 전체 후기 목록 API 상세

**Endpoint**: `GET /api/v1/admin/reviews/all`

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| status | String | X | 승인 상태 필터 (PENDING, APPROVED, REJECTED) |
| keyword | String | X | 강의명 검색 키워드 |
| page | Integer | X | 페이지 번호 (기본값: 0) |
| size | Integer | X | 페이지 크기 (기본값: 10) |

**응답**: Spring `Page<AdminReviewSummary>` (totalElements, totalPages 등 페이지 메타정보 포함)

---

## DB 스키마

### REVIEWS

| 컬럼 | 타입 | 설명 |
|------|------|------|
| REVIEW_ID | BIGSERIAL PK | 후기 ID |
| LECTURE_ID | BIGINT FK | 강의 ID |
| USER_ID | BIGINT FK | 작성자 ID |
| COMMENT | TEXT | 총평 (선택, 최대 500자) |
| SCORE | DECIMAL(2,1) | 전체 별점 (상세 평균) |
| BLURRED | BOOLEAN | 블라인드 여부 |
| APPROVAL_STATUS | SMALLINT | 0:PENDING, 1:APPROVED, 2:REJECTED |

### REVIEWS_DETAILS

| 컬럼 | 타입 | 설명 |
|------|------|------|
| CATEGORY | VARCHAR(20) | TEACHER, CURRICULUM, MANAGEMENT, FACILITY, PROJECT |
| SCORE | DECIMAL(2,1) | 카테고리별 별점 |
| DETAIL_COMMENT | TEXT | 카테고리별 후기 (20~500자) |

### CERTIFICATES

| 컬럼 | 타입 | 설명 |
|------|------|------|
| STATUS | BOOLEAN | OCR 인증 여부 |
| IMAGE_URL | TEXT | S3 URL |
| APPROVAL_STATUS | SMALLINT | 관리자 승인 상태 |

---

## OCR 연동 (sw-campus-ai)

**Endpoint**: `POST {OCR_SERVER_URL}/ocr/extract`

```json
// Response
{
  "text": "수료증\nJava 풀스택 개발자 과정\n홍길동\n...",
  "lines": ["수료증", "Java 풀스택 개발자 과정", ...],
  "scores": [0.98, 0.95, ...]
}
```

**강의명 매칭**: 공백 제거 + 소문자 변환 후 부분 일치 검사

---

## 에러 코드

### 수료증

| 코드 | HTTP | 설명 |
|------|------|------|
| CERT001 | 400 | 이미지 형식 오류 (jpg, png만) |
| CERT002 | 400 | 이미지 크기 초과 (5MB) |
| CERT003 | 400 | OCR 인식 실패 |
| CERT004 | 400 | 강의명 불일치 |
| CERT005 | 409 | 이미 인증된 수료증 |
| CERT006 | 403 | 수료증 인증 필요 |

### 후기

| 코드 | HTTP | 설명 |
|------|------|------|
| REVIEW001 | 400 | 카테고리별 후기 길이 오류 (20~500자) |
| REVIEW002 | 400 | 5개 카테고리 모두 필수 |
| REVIEW003 | 400 | 별점 범위 오류 (1.0~5.0) |
| REVIEW004 | 403 | 닉네임 설정 필요 |
| REVIEW005 | 409 | 이미 후기 작성한 강의 |
| REVIEW006 | 404 | 후기 없음 |
| REVIEW007 | 403 | 본인 후기만 수정 가능 |
| REVIEW008 | 403 | 승인된 후기는 수정 불가 |

---

## 구현 노트

### 2025-01-01 - OCR 기능 일시 비활성화

- 배경: OCR 서버 CPU 사용량 최적화 필요
- 변경: `certificate.ocr.enabled=false` 설정으로 OCR 검증 우회
- 영향:
  - 이미지 업로드만으로 수료증 인증 완료
  - 에러 코드 CERT003(OCR 실패), CERT004(강의명 불일치) 미발생
  - 관리자 수료증 검토 프로세스는 그대로 유지
- 복구: `certificate.ocr.enabled=true`로 변경 시 OCR 재활성화
- 관련 파일:
  - `CertificateService.java` - OCR 토글 로직
  - `application-*.yml` - 환경별 설정
  - `CertificateServiceTest.java` - OCR 관련 테스트 @Disabled 처리

### 2025-12-21 - 후기 수정 정책 변경 및 Swagger 문서 개선

- PR: #188
- 변경 사항:
  - 후기 수정 가능 상태 확장: REJECTED만 → PENDING, REJECTED 모두 가능
  - APPROVED 상태만 수정 불가로 정책 변경
  - Swagger 문서에 5개 카테고리 전체 예시 추가
  - Jackson 날짜 직렬화 설정 추가 (`WRITE_DATES_AS_TIMESTAMPS: false`)
- 수정 이유:
  - 마이페이지에서 PENDING 상태 후기 수정 시 에러 발생 문제 해결
  - 프론트엔드 개발자를 위한 API 문서 가독성 향상

### 2025-12-21 - 관리자 전체 후기 목록 API 추가

- PR: #183
- 추가된 API: `GET /api/v1/admin/reviews/all`
- 주요 기능:
  - 모든 상태의 후기 조회 (PENDING, APPROVED, REJECTED)
  - 승인 상태 필터링
  - 강의명 키워드 검색
  - 페이지네이션 (page, size)
- 특이사항:
  - N+1 문제 방지를 위한 배치 조회 로직 적용
  - 기존 `GET /reviews`(PENDING만 조회)와 별도 엔드포인트로 분리

### 2025-12-10 - 초기 구현

- 수료증 OCR 인증 (sw-campus-ai 연동)
- 5개 카테고리 상세 별점 후기
- 2단계 관리자 검토 (수료증 → 후기)
- 블라인드 처리
- 반려 시 이메일 발송
