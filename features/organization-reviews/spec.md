# 기관별 후기 페이지네이션 Spec

## 개요

기관 상세 페이지에서 해당 기관의 모든 강의에 대한 승인된 후기를 페이지네이션과 정렬 옵션으로 조회하는 기능입니다.

---

## API

### 기관별 승인된 후기 조회 (페이지네이션)

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| GET | `/api/v1/organizations/{organizationId}/reviews` | 기관별 승인된 후기 목록 조회 | X |

**Path Parameters**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| organizationId | Long | O | 기관 ID |

**Query Parameters**:

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|:----:|--------|------|
| page | int | X | 0 | 페이지 번호 (0부터 시작) |
| size | int | X | 6 | 페이지 크기 |
| sort | ReviewSortType | X | LATEST | 정렬 기준 |

**정렬 옵션 (ReviewSortType)**:

| 값 | 설명 |
|----|------|
| LATEST | 최신순 (createdAt DESC) |
| OLDEST | 오래된순 (createdAt ASC) |
| SCORE_DESC | 별점 높은순 (score DESC) |
| SCORE_ASC | 별점 낮은순 (score ASC) |

**Response** (200 OK):

```json
{
  "content": [
    {
      "reviewId": 1,
      "lectureId": 10,
      "memberId": 1,
      "nickname": "수강생A",
      "comment": "정말 훌륭한 강의였습니다.",
      "score": 4.5,
      "detailScores": [
        { "category": "TEACHER", "score": 4.5, "comment": "강사님이 좋았습니다" },
        { "category": "CURRICULUM", "score": 4.0, "comment": "커리큘럼이 체계적입니다" },
        { "category": "MANAGEMENT", "score": 4.5, "comment": "취업 지원이 좋았습니다" },
        { "category": "FACILITY", "score": 4.0, "comment": "시설이 깨끗합니다" },
        { "category": "PROJECT", "score": 5.0, "comment": "프로젝트가 유익했습니다" }
      ],
      "approvalStatus": "APPROVED",
      "blurred": false,
      "createdAt": "2025-12-21T10:00:00",
      "updatedAt": "2025-12-21T10:00:00"
    }
  ],
  "page": {
    "size": 6,
    "number": 0,
    "totalElements": 15,
    "totalPages": 3
  }
}
```

---

## DB 스키마

신규 테이블 없음. 기존 테이블 사용:

- `reviews` - 후기 기본 정보
- `review_details` - 카테고리별 점수
- `lectures` - 강의 정보 (org_id로 기관 연결)

**조회 쿼리**:
```sql
SELECT DISTINCT r.*, rd.*
FROM reviews r
LEFT JOIN review_details rd ON r.review_id = rd.review_id
WHERE EXISTS (
    SELECT 1 FROM lectures l
    WHERE l.lecture_id = r.lecture_id
    AND l.org_id = :organizationId
)
AND r.approval_status = 'APPROVED'
ORDER BY r.created_at DESC
LIMIT :size OFFSET :page * :size
```

---

## 프론트엔드

### 컴포넌트 구조

```
OrganizationDetail.tsx
├── OrganizationReviewsSection
│   ├── 정렬 드롭다운 (Select)
│   ├── 총 후기 수 표시
│   ├── OrganizationReviewCard (반복)
│   │   └── 강의보기 링크 (/lectures/{id}#review)
│   └── ReviewPagination
```

### API 타입

```typescript
// reviewApi.types.ts
export type ReviewSortType = 'LATEST' | 'OLDEST' | 'SCORE_DESC' | 'SCORE_ASC'

export const REVIEW_SORT_LABELS: Record<ReviewSortType, string> = {
  LATEST: '최신순',
  OLDEST: '오래된순',
  SCORE_DESC: '별점 높은순',
  SCORE_ASC: '별점 낮은순',
}

export interface ReviewPageResponse {
  content: Review[]
  page: {
    size: number
    number: number
    totalElements: number
    totalPages: number
  }
}
```

### API 함수

```typescript
// reviewApi.client.ts
export async function getOrganizationReviews(
  organizationId: string | number,
  page: number = 0,
  size: number = 6,
  sort: ReviewSortType = 'LATEST',
): Promise<ReviewPageResponse> {
  const { data } = await api.get<ReviewPageResponse>(
    `/organizations/${organizationId}/reviews`,
    { params: { page, size, sort } }
  )
  return data
}
```

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| - | 200 | 후기가 없어도 빈 배열 반환 |

---

## 보안

| API | 인증 | 권한 | 비고 |
|-----|:----:|------|------|
| `GET /api/v1/organizations/{organizationId}/reviews` | X | 없음 | 공개 API |

---

## 구현 체크리스트

### Domain Layer (sw-campus-domain)
- [x] `ReviewSortType` enum 추가
- [x] `ReviewRepository`에 `findByOrganizationIdAndApprovalStatusWithPagination` 메서드 추가
- [x] `ReviewService`에 `getApprovedReviewsByOrganizationWithPagination` 메서드 추가

### Infra Layer (sw-campus-infra)
- [x] `ReviewJpaRepository`에 JPQL 페이지네이션 쿼리 추가
- [x] `ReviewEntityRepository`에 구현체 추가

### API Layer (sw-campus-api)
- [x] `OrganizationController`에 페이지네이션 파라미터 추가 (page, size, sort)

### Frontend (sw-campus-client)
- [x] `ReviewSortType`, `ReviewPageResponse` 타입 추가
- [x] `getOrganizationReviews` API 함수에 페이지네이션 파라미터 추가
- [x] `OrganizationReviewsSection` 컴포넌트에 정렬 드롭다운 추가
- [x] `ReviewPagination` 컴포넌트 추가
- [x] `OrganizationReviewCard`에 '강의보기' 링크 추가

### Test
- [x] `ReviewServiceTest`에 페이지네이션 테스트 추가
- [x] `OrganizationControllerTest`에 페이지네이션 테스트 추가
- [x] 테스트 데이터 SQL 파일 추가 (`test-review-data.sql`)

---

## 구현 노트

### 2025-12-23 - 기관별 후기 페이지네이션 API 추가

- **Backend PR**: [#205](https://github.com/sw-campus/sw-campus-server/pull/205)
- **Frontend PR**: [#76](https://github.com/sw-campus/sw-campus-client/pull/76)
- **주요 변경**:
  - `GET /api/v1/organizations/{organizationId}/reviews` 엔드포인트에 페이지네이션 지원 추가
  - 정렬 옵션 4가지 제공 (최신순, 오래된순, 별점 높은순, 별점 낮은순)
  - 기본 페이지 크기: 6개 (UI 레이아웃에 맞춤)
  - 프론트엔드에 정렬 드롭다운 및 페이지네이션 UI 추가
  - 후기 카드에서 해당 강의 상세 페이지의 후기 섹션으로 이동하는 '강의보기' 링크 추가
- **설계 결정**:
  - Spring Data Page 응답 형식 사용 (content + page 메타데이터)
  - 기관에 속한 모든 강의의 후기를 조회하기 위해 EXISTS 서브쿼리 사용
  - N+1 문제 해결을 위해 닉네임 배치 로딩 적용
