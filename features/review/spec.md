# 후기 (Review) Spec

## 설계 결정

### 후기 기본

#### 왜 2단계 승인인가? (수료증 → 후기)

허위 수료증을 먼저 걸러내기 위함.

- 1단계: 수료증 이미지 검증 (OCR + 관리자 확인)
- 2단계: 후기 내용 검토

한 번에 처리하면 관리자가 수료증과 후기를 동시에 봐야 해서 검토 부담 증가.

#### 왜 5개 카테고리 상세 별점인가?

"강의 좋아요" 단일 점수로는 비교 불가.
사용자마다 중요한 기준이 다름 (취업지원 vs 커리큘럼 등).

| 카테고리 | 설명 |
|----------|------|
| TEACHER | 강사진 전문성, 강의력 |
| CURRICULUM | 커리큘럼, 학습 자료 |
| MANAGEMENT | 운영 및 학습환경 |
| FACILITY | 취업지원 서비스 |
| PROJECT | 프로젝트 경험 |

#### 왜 삭제 대신 블라인드인가?

데이터 보존 정책. 후기 이력 추적 필요.

| 처리 | 동작 | 용도 |
|------|------|------|
| 블라인드 (blurred=true) | 목록에 표시, 내용 가림 | 부적절 내용 숨김 |
| 반려 (REJECTED) | 목록에 미노출 | 허위/스팸 후기 |

#### 왜 APPROVED 상태는 수정 불가인가?

승인된 후기는 관리자가 검증 완료한 신뢰성 있는 후기.
수정을 허용하면 검증되지 않은 내용이 노출될 수 있음.
PENDING/REJECTED만 수정 허용.

---

### 수료증 OCR 매칭

#### 왜 4단계 다단계 매칭인가?

성능과 정확성의 균형. 대부분 1차에서 통과.

```
0단계: 유효성 검사 (빠름) → 안전장치
1차: 정확한 매칭 (매우 빠름) → 대부분 여기서 통과
2차: Homoglyph 정규화 (빠름) → OCR 유사 문자 처리
3차: Jaro-Winkler 유사도 (느림) → 마지막 수단
```

#### 왜 Homoglyph 정규화가 필요한가?

OCR이 "모양이 비슷한" 다른 유니코드 문자로 인식.

| 원본 | OCR 인식 | 정규화 |
|------|----------|--------|
| x | × (곱셈 기호) | x |
| - | — (em dash) | - |
| ' | ' (스마트 따옴표) | ' |

#### 왜 Jaro-Winkler 임계값이 0.8인가?

1-2글자 오인식 허용, 거짓 양성 최소화.

```
"자바 스프링 기초" vs "자바 스프링 기쵸" → 0.92 >= 0.8 → 통과
"자바 스프링" vs "파이썬 백엔드" → 0.15 < 0.8 → 실패
```

#### 왜 OCR 검증을 비활성화할 수 있게 했는가?

PaddleOCR 초기 로드 시 수백MB 모델 다운로드 필요.

```yaml
certificate:
  ocr:
    enabled: false  # 이미지 업로드만, OCR 검증 스킵
```

---

### 마이페이지 후기 조회

#### 왜 일반 조회와 마이페이지 조회 엔드포인트를 분리했는가?

권한과 사용 맥락이 다름.

| 엔드포인트 | 용도 | 권한 |
|-----------|------|------|
| `/api/v1/reviews/{reviewId}` | 공개 후기 조회 | Optional |
| `/api/v1/mypage/completed-lectures/{lectureId}/review` | 내 후기 조회 | USER 필수 |

- 일반 조회: 승인된 후기만, reviewId 기준
- 마이페이지: 본인 후기만, lectureId 기준 (사용자 흐름)

#### 왜 ReviewWithNickname 중간 도메인 객체를 만들었는가?

Review 도메인에 nickname을 포함시키지 않음 (도메인 순수성).

```java
public record ReviewWithNickname(Review review, String nickname) {}
```

- Member 조회와 Review 조회 분리 (이후 최적화 가능)
- "닉네임과 함께 반환"을 코드로 명시

---

### 기관별 후기 페이지네이션

#### 왜 기본 페이지 크기가 6인가?

UI 그리드 레이아웃 최적화.

```
Desktop: 3열 × 2행 = 6개
Tablet:  2열 × 3행 = 6개
Mobile:  1열 × 6행 = 6개
```

#### 왜 EXISTS 서브쿼리를 사용했는가?

Review → Lecture → Organization 관계 탐색.

```sql
WHERE EXISTS (
    SELECT 1 FROM LectureEntity l
    WHERE l.lectureId = r.lectureId AND l.orgId = :organizationId
)
```

- Review에 직접적인 organizationId 없음
- EXISTS는 첫 매치에서 즉시 중단 (성능)

#### 왜 닉네임을 배치 조회하는가?

N+1 문제 해결.

```java
// Bad: 6개 리뷰 → 6번 조회
// Good: 1번 배치 조회
Map<Long, String> nicknameMap = memberRepository.findAllByIds(memberIds);
```

- 6개 리뷰 조회: 7 쿼리 → 2 쿼리 (71% 감소)

---

## 구현 노트

### 2025-12-10 - 초기 구현 [Server]

- 수료증 OCR 인증 (sw-campus-ai 연동)
- 5개 카테고리 상세 별점
- 2단계 관리자 검토
- 블라인드 처리
- 반려 시 이메일 발송

### 2025-12-21 - Review API 리팩토링 [Server]

- PR: #178
- 변경:
  - `MypageController`에 `GET /completed-lectures/{lectureId}/review` 추가
  - `ReviewService.getMyReviewWithNicknameByLecture()` 메서드 추가
  - `AdminReviewController`를 Service 패턴으로 리팩토링

### 2025-12-21 - ReviewForm 컴포넌트 [Client]

- 생성 모드 / 수정 모드 동시 지원
- effectiveReadOnly 상태로 수정 불가 처리
- 5개 카테고리 점수 입력 UI
- 관련: `ReviewForm.tsx`, `reviewApi.client.ts`

### 2025-12-21 - 후기 수정 정책 변경 [Server]

- PR: #188
- 변경: REJECTED만 수정 가능 → PENDING, REJECTED 모두 가능

### 2025-12-21 - 관리자 전체 후기 목록 API 추가 [Server]

- PR: #183
- 변경: `GET /api/v1/admin/reviews/all` 추가
- N+1 방지 위해 배치 조회 적용

### 2025-12-23 - 기관별 후기 페이지네이션 API 추가 [Server][Client]

- Server PR: #205, Client PR: #76
- 변경:
  - `GET /api/v1/organizations/{id}/reviews` 페이지네이션 지원
  - `ReviewSortType` enum 추가 (LATEST, OLDEST, SCORE_DESC, SCORE_ASC)
  - 프론트엔드 정렬 드롭다운 및 페이지네이션 UI
- 관련: `OrganizationController.java`, `ReviewService.java`, `OrganizationDetail.tsx`

### 2025-12-27 - 다단계 강의명 매칭 구현 [Server]

- PR: #247
- 변경:
  - `LectureNameMatcher` 클래스 추가
  - 0단계: OCR 유효성 검사 (길이 50% 이상)
  - 1차: 정확한 매칭 (공백/대소문자 무시)
  - 2차: Homoglyph 정규화 (×→x, —→- 등)
  - 3차: Jaro-Winkler 유사도 (≥80%)
  - Apache Commons Text 의존성 추가
- 관련: `LectureNameMatcher.java`, `CertificateService.java`

### 2025-01-01 - OCR 기능 비활성화 [Server]

- 배경: OCR 서버 CPU 사용량 최적화 필요
- 변경: 모든 환경에서 `certificate.ocr.enabled=false`
- 영향: 이미지 업로드만으로 인증 완료, 관리자 수동 검토 의존
