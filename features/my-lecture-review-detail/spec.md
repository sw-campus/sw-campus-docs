# 내 강의 후기 상세 조회 Spec

## 개요

수강 완료한 강의 목록(`/completed-lectures`)에서 선택한 강의에 대해 본인이 작성한 후기의 상세 정보를 조회하는 API입니다. 기존의 불필요한 `/mypage/reviews` API는 삭제합니다.

---

## API

### 내 강의 후기 상세 조회

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| GET | `/api/v1/mypage/completed-lectures/{lectureId}/review` | 수강 완료 강의에 대한 내 후기 상세 조회 | O |

**Path Parameters**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| lectureId | Long | O | 강의 ID |

**Response** (200 OK):

```json
{
  "review_id": 1,
  "lecture_id": 10,
  "member_id": 1,
  "nickname": "수강생A",
  "comment": "전체적으로 만족스러운 강의였습니다.",
  "score": 4.3,
  "detail_scores": [
    { "category": "TEACHER", "score": 4.5, "comment": "강사님이 좋았습니다" },
    { "category": "CURRICULUM", "score": 4.0, "comment": "커리큘럼이 체계적입니다" },
    { "category": "MANAGEMENT", "score": 4.5, "comment": "행정 서비스가 좋았습니다" },
    { "category": "FACILITY", "score": 3.5, "comment": "시설은 보통입니다" },
    { "category": "PROJECT", "score": 5.0, "comment": "프로젝트가 유익했습니다" }
  ],
  "approval_status": "APPROVED",
  "blurred": false,
  "created_at": "2025-12-21T10:00:00",
  "updated_at": "2025-12-21T10:00:00"
}
```

### 삭제된 API

| Method | Endpoint | 설명 | 상태 |
|--------|----------|------|------|
| GET | `/api/v1/mypage/reviews` | 내 후기 목록 조회 | **삭제 완료** |

---

## DB 스키마

신규 테이블 없음. 기존 테이블 사용:

- `reviews` - 후기 기본 정보
- `review_details` - 카테고리별 점수

**조회 쿼리**:
```sql
SELECT r.*, rd.*
FROM reviews r
LEFT JOIN review_details rd ON r.id = rd.review_id
WHERE r.member_id = :memberId AND r.lecture_id = :lectureId
```

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| REVIEW_NOT_FOUND | 404 | 해당 강의에 대한 후기가 없음 |
| LECTURE_NOT_FOUND | 404 | 강의를 찾을 수 없음 |

---

## 보안

| API | 인증 | 권한 | 비고 |
|-----|:----:|------|------|
| `GET /api/v1/mypage/completed-lectures/{lectureId}/review` | O | USER | 본인 후기만 조회 가능 (JWT memberId 사용) |

---

## 구현 체크리스트

### Domain Layer (sw-campus-domain)
- [x] `ReviewRepository`에 `findByMemberIdAndLectureId` 메서드 (기존 존재)
- [x] `ReviewService`에 `getMyReviewByLecture` 메서드 (기존 존재)

### Infra Layer (sw-campus-infra)
- [x] `ReviewEntityRepository`에 쿼리 구현 (기존 존재)

### API Layer (sw-campus-api)
- [x] `MypageController`에 `GET /completed-lectures/{lectureId}/review` 엔드포인트 추가
- [x] `MypageController`에서 `GET /reviews` 엔드포인트 삭제

### Test
- [x] `MypageControllerTest`에 후기 조회 테스트 추가
- [x] `MypageControllerTest`에서 `/reviews` 테스트 삭제

---

## 구현 노트

### 2025-12-21 - 초기 구현

**변경사항**:
- `MypageController`에 `GET /completed-lectures/{lectureId}/review` 추가
- `MypageController`에서 기존 `GET /reviews` 삭제
- 테스트 코드 추가 및 정리

**설계 결정**:
- 초기에는 `/api/v1/reviews/my?lectureId={id}`로 구현했으나, 사용자 흐름(mypage → completed-lectures → review)에 맞게 `/api/v1/mypage/completed-lectures/{lectureId}/review`로 변경
- Path Parameter 방식이 RESTful하고 리소스 계층 구조를 명확히 표현

**Domain/Infra 레이어**:
- 기존 `ReviewService.getMyReviewByLecture(memberId, lectureId)` 메서드 재사용
- 추가 구현 불필요
