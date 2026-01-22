# 리뷰 블라인드 (Review Blind) Spec

## 설계 결정

### 왜 OR 조건인가? (설문 OR 리뷰)

사용자 유형에 따라 해제 가능한 방법이 다름.

```
부트캠프 미참여자 → 수료증 없음 → 리뷰 작성 불가 → 설문으로만 해제
부트캠프 참여자 → 수료증 있음 → 리뷰 작성 가능 → 리뷰로 해제
```

서비스에서 부트캠프 참여 여부를 알 수 없으므로, 둘 중 하나만 충족하면 해제.

| 조건 | 대상 |
|------|------|
| 설문조사 100% 완료 | 모든 사용자 |
| 승인된 리뷰 1개 이상 | 부트캠프 수료자 |

### 왜 totalCount는 항상 실제 값인가?

사용자에게 "숨겨진 리뷰가 있다"는 사실을 알려야 참여 유도 효과.

```
"리뷰 15개 중 1개만 보이는 중"
→ "나머지 14개 보려면 설문 완료 필요"
→ 설문 참여 유도
```

totalCount를 숨기면 사용자가 더 많은 리뷰가 있는지 모름.

### 왜 서버에서 필터링하는가?

클라이언트 우회 방지.

| 방식 | 장점 | 단점 |
|------|------|------|
| 클라이언트 필터링 | 간단 | 개발자도구로 우회 가능 |
| **서버 필터링** | **보안** | 로직 추가 필요 |

API 응답 자체가 필터링되어야 우회 불가.

### 왜 ReviewAccessService를 분리하는가?

단일 책임 원칙.

```
ReviewService: 리뷰 CRUD
ReviewAccessService: 리뷰 접근 권한 (블라인드)
```

- ReviewService가 이미 충분히 큼 (270줄)
- 블라인드 로직은 독립적인 비즈니스 규칙
- 향후 확장 가능 (기관별 블라인드 등)

### 왜 기존 API를 수정하는가? (vs 새 API)

사용자 경험 일관성.

| 방식 | URL | 문제 |
|------|-----|------|
| 새 API | `/api/v1/lectures/{id}/reviews-with-blind` | 클라이언트 분기 필요 |
| **기존 수정** | `/api/v1/lectures/{id}/reviews` | **기존 흐름 유지** |

응답 형식만 확장 (reviews → {reviews, totalCount, isUnblinded}).

### 왜 Review.blurred와 별도인가?

두 개념은 적용 단위와 제어 주체가 다름.

| 개념 | 단위 | 제어 | 용도 |
|------|------|------|------|
| `Review.blurred` | 개별 리뷰 | 관리자 | 부적절 내용 숨김 |
| `isUnblinded` | 사용자 전체 | 시스템 | 참여 유도 |

- blurred=true인 리뷰: 해제 회원에게도 블러 처리
- 미해제 회원: blurred=false 리뷰도 1개만 보임

독립적으로 동작해야 혼란 없음.

---

## 구현 노트

### 2026-01-22 - 리뷰 블라인드 기능 초기 구현 [Server][Client]

- 변경:
  - `ReviewAccessService` 추가 (블라인드 해제 조건 판단)
  - `ReviewBlindStatus` DTO 추가
  - `ReviewRepository.existsByMemberIdAndApprovalStatus()` 추가
  - `GET /api/v1/lectures/{id}/reviews` 응답 확장 (totalCount, isUnblinded)
  - `GET /api/v1/reviews/blind-status` 신규 엔드포인트
  - 프론트엔드 블라인드 오버레이 컴포넌트
- 관련: `ReviewAccessService.java`, `LectureController.java`, `ReviewController.java`
