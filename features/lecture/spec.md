# 강의 Spec

## 설계 결정

### 왜 이중 상태 체계인가? (모집상태 + 승인상태)

독립적인 관심사 분리.

| 상태 | 역할 | 결정 기준 |
|------|------|---------|
| **LectureStatus** | 모집 활성화 | 시간 기반 (deadline) |
| **LectureAuthStatus** | 콘텐츠 검증 | 관리자 승인 |

```
RECRUITING + APPROVED = 신청 가능
FINISHED + APPROVED = 마감됨 (후기 조회용)
RECRUITING + PENDING = 노출 안됨
```

- 모집 상태는 자동화 (시간 기반)
- 승인 상태는 수동 (관리자 개입)
- 마감 후에도 강의 데이터 유지 (통계, 후기)

### 왜 반려된 강의 수정 시 자동 PENDING인가?

재심사 워크플로우 간소화.

```java
if (existingLecture.getLectureAuthStatus() == LectureAuthStatus.REJECTED) {
    newAuthStatus = LectureAuthStatus.PENDING;  // 자동 복원
}
```

- 기관이 수정 완료 = 재심사 요청 의미
- 별도 "재심사 요청" 버튼 불필요
- 수정 즉시 관리자 대기열에 추가

### 왜 이런 필터링 옵션인가?

사용자 의사결정 핵심 요소.

**비용 필터**:
- `isFreeKdt`: 내일배움카드 필수 (정부 지원)
- `isFreeNoKdt`: 내일배움카드 불필요 (일반 무료)
- `isPaid`: 유료 (자부담 발생)

**선발절차 필터**:
- `hasInterview=false`: 면접 없음
- `hasCodingTest=false`: 코딩테스트 없음
- `hasPreTask=false`: 사전학습과제 없음

- 정부 지원 여부가 수강 가능성 결정
- 선발절차는 시간 투자/스트레스와 직결

### 왜 8가지 정렬 옵션인가?

다양한 탐색 패턴 지원.

```java
LATEST          // 최신순 (기본)
FEE_ASC         // 자부담금 낮은순
FEE_DESC        // 자부담금 높은순
START_SOON      // 마감 임박순
DURATION_ASC    // 교육기간 짧은순
DURATION_DESC   // 교육기간 긴순
REVIEW_COUNT_DESC // 후기 많은순
SCORE_DESC      // 별점순
```

- 가격 민감 사용자: FEE_ASC
- 빠른 취업 희망: DURATION_ASC
- 신뢰도 중시: REVIEW_COUNT_DESC, SCORE_DESC

### 왜 카테고리-커리큘럼이 N:M 관계인가?

학습 경로의 유연성.

```
Lecture 1 → [Python 기초(BASIC), Python 웹(ADVANCED)]
Lecture 2 → [Python 기초(BASIC)]
```

- 한 강의가 여러 커리큘럼 경로에 포함 가능
- 각 커리큘럼마다 수준(NONE/BASIC/ADVANCED) 지정
- 첫 번째 커리큘럼 = 주 카테고리

### 왜 Redis 캐시를 사용하는가?

강의 상세 조회 성능 최적화.

```java
// Cache-Aside 패턴
Optional<Lecture> cached = lectureCacheRepository.getLecture(id);
if (cached.isPresent()) return cached.get();

Lecture lecture = lectureRepository.findById(id);
lectureCacheRepository.saveLecture(lecture);
```

- 강의 상세는 변경 빈도 낮음
- 조회 빈도는 높음 (목록, 상세, 비교)
- DB 부하 감소

### 왜 카테고리 기본 이미지를 자동 할당하는가?

일관된 시각적 경험.

```java
CATEGORY_IMAGE_MAP = {
    2L → "web-development.png",
    6L → "mobile.png",
    8L → "data-ai.png",
    ...
}
```

- 강의 이미지 미제공 시 카테고리 이미지 사용
- 검색 결과 화면의 시각적 통일성
- 기관 부담 감소 (이미지 준비 필수 아님)

---

### 관리자 강의 승인 워크플로우

#### 왜 관리자는 모든 강의를 수정할 수 있는가?

운영 효율성 우선.

```java
// LectureService.updateLecture()
if (actor.getRole() != Role.ADMIN && !org.getId().equals(lecture.getOrgId())) {
    throw new AccessDeniedException("본인 기관의 강의만 수정할 수 있습니다.");
}
```

- ADMIN 역할은 소유권 검사 우회
- 기관이 실수로 잘못된 정보 입력 시 관리자가 직접 수정
- 기관에 수정 요청 → 수정 → 재승인 과정 생략

#### 왜 강의 승인/반려 시 이메일 알림이 없는가?

기관 승인과 성격이 다름.

| 알림 대상 | 기관 승인 | 강의 승인 |
|----------|----------|----------|
| 빈도 | 1회 (가입 시) | 여러 번 (강의마다) |
| 긴급성 | 높음 (서비스 이용 불가) | 낮음 (마이페이지에서 확인) |
| 결과 | 이메일 발송 | 이메일 미발송 |

- 기관은 마이페이지 강의 목록에서 승인 상태 즉시 확인 가능
- 대량 강의 등록 시 이메일 폭주 방지
- 반려 사유는 강의 상세에서 확인

#### 왜 관리자 강의 검색에 상태 필터가 있는가?

대기열 우선순위 관리.

```java
// AdminLectureController.searchLectures()
@RequestParam(required = false) LectureAuthStatus lectureAuthStatus
```

| 필터 | 용도 |
|------|------|
| PENDING | 승인 대기 (우선 처리) |
| APPROVED | 승인 완료 목록 |
| REJECTED | 반려 목록 (재심사 대상 확인) |

- 기본: PENDING 필터로 대기열만 표시
- 필요시 전체 조회 (통계, 검색)

#### 왜 승인/대기중 상태 강의도 수정 가능한가?

기관의 정보 수정 자유 보장.

```
Before: APPROVED/PENDING 상태 → 수정 시 예외 발생
After:  모든 상태 → 수정 허용, REJECTED만 자동 PENDING 복원
```

- APPROVED 강의도 정보 업데이트 필요 (일정, 장소 변경)
- 수정 즉시 반영, 재승인 불필요
- REJECTED만 재심사 워크플로우 적용

---

## 구현 노트

### 2025-12-04 - 초기 구현 [Server][Client]

- Server:
  - 강의 CRUD (`LectureController`, `LectureService`)
  - 이중 상태 체계 (LectureStatus + LectureAuthStatus)
  - 검색 필터링 (비용, 선발절차, 지역)
  - Redis 캐시 (Cache-Aside)
  - 리뷰 통계 최적화 (배치 조회)
- Client:
  - 강의 검색 사이드바 (필터 + 정렬)
  - 강의 등록/수정 폼 (10단계)
  - 카테고리 계층 선택 UI
- 관련: `LectureController.java`, `LectureService.java`, `LectureSearchSidebar.tsx`

### 2025-12-XX - 관리자 승인 워크플로우 [Server]

- 변경:
  - 반려된 강의 수정 시 자동 PENDING
  - 관리자 승인/반려 API
  - 대시보드 대기열 조회
- 관련: `AdminLectureService.java`, `AdminLectureController.java`
