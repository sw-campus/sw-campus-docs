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
| PUT | `/api/v1/reviews/{reviewId}` | 후기 수정 | USER |

**후기 작성 조건**: 닉네임 설정 완료 + 수료증 인증 완료

### 관리자 - 2단계 검토

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/admin/reviews` | 승인 대기 목록 | ADMIN |
| GET | `/api/v1/admin/reviews/{id}/certificate` | 수료증 조회 (1단계) | ADMIN |
| PATCH | `/api/v1/admin/certificates/{id}/approve` | 수료증 승인 | ADMIN |
| PATCH | `/api/v1/admin/certificates/{id}/reject` | 수료증 반려 | ADMIN |
| GET | `/api/v1/admin/reviews/{id}` | 후기 상세 (2단계) | ADMIN |
| PATCH | `/api/v1/admin/reviews/{id}/approve` | 후기 승인 | ADMIN |
| PATCH | `/api/v1/admin/reviews/{id}/reject` | 후기 반려 | ADMIN |
| PATCH | `/api/v1/admin/reviews/{id}/blind` | 블라인드 처리 | ADMIN |

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
| REVIEW008 | 400 | 승인된 후기는 수정 불가 |

---

## 구현 노트

### 2025-12-10 - 초기 구현

- 수료증 OCR 인증 (sw-campus-ai 연동)
- 5개 카테고리 상세 별점 후기
- 2단계 관리자 검토 (수료증 → 후기)
- 블라인드 처리
- 반려 시 이메일 발송
