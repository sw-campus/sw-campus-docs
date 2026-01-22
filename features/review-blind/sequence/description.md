## 필수 정보

### 1. 참여자 (Participants/Actors)

| 참여자 | 설명 | 기술 스택 |
|--------|------|-----------|
| 사용자 (User) | 서비스 이용자 | 브라우저 |
| 프론트엔드 (Frontend) | 웹 클라이언트 | Next.js |
| 백엔드 (Backend) | API 서버 | Spring |
| DB (Database) | 데이터 저장소 | PostgreSQL |

### 2. 시나리오/흐름 설명

- 블라인드 상태에서 강의 리뷰 조회
- 블라인드 해제 상태 확인
- 블라인드 해제 (설문조사 완료)
- 블라인드 해제 (리뷰 승인)

### 3. 메시지 흐름 순서

#### 3-1. 강의별 리뷰 목록 조회 흐름

```
1. 사용자 → 프론트엔드: 강의 상세 페이지 접근
2. 프론트엔드 → 백엔드: 리뷰 목록 조회 (GET /api/v1/lectures/{lectureId}/reviews)
   - 인증 토큰 포함 (Optional)
3. 백엔드: 요청자 식별
   - 비회원: requesterId = null
   - 회원: requesterId = JWT에서 추출
4. 백엔드 → DB: 블라인드 해제 조건 확인
   - 승인된 리뷰 존재 여부 (reviewRepository.existsByMemberIdAndApprovalStatus)
   - 설문조사 완료 여부 (surveyRepository.findByMemberId → isComplete)
5. 백엔드: 블라인드 상태 결정
   - isUnblinded = hasApprovedReview OR hasSurveyCompleted
6. 백엔드 → DB: 승인된 리뷰 목록 조회
7. 백엔드: 리뷰 필터링
   - [조건] 블라인드 해제 (isUnblinded: true):
     - 모든 리뷰 반환
   - [조건] 블라인드 상태 (isUnblinded: false):
     - 첫 번째 리뷰만 반환 (limit 1)
8. 백엔드 → 프론트엔드: 리뷰 목록 응답
   - reviews: 필터링된 리뷰 목록
   - totalCount: 전체 리뷰 개수 (블라인드 무관)
   - isUnblinded: 블라인드 해제 여부
9. 프론트엔드: UI 렌더링
   - [조건] isUnblinded: true → 모든 리뷰 표시
   - [조건] isUnblinded: false → 1개 리뷰 + 블라인드 오버레이 표시
```

#### 3-2. 블라인드 상태 확인 흐름

```
1. 사용자 → 프론트엔드: 마이페이지 또는 블라인드 오버레이에서 상태 확인
2. 프론트엔드 → 백엔드: 블라인드 상태 조회 (GET /api/v1/reviews/blind-status)
   - 인증 토큰 필수
3. 백엔드 → DB: 승인된 리뷰 존재 여부 조회
4. 백엔드 → DB: 설문조사 완료 여부 조회
5. 백엔드: 상태 계산
   - hasApprovedReview: 승인된 리뷰 1개 이상
   - hasSurveyCompleted: MemberSurvey.completedAt != null
   - isUnblinded: hasApprovedReview OR hasSurveyCompleted
6. 백엔드 → 프론트엔드: 상태 응답
7. 프론트엔드 → 사용자: 상태 표시
   - [조건] isUnblinded: true → "리뷰 전체 열람 가능" 표시
   - [조건] isUnblinded: false → 미충족 조건 안내
     - hasApprovedReview: false → "리뷰를 작성하면 해제됩니다"
     - hasSurveyCompleted: false → "설문조사를 완료하면 해제됩니다"
```

#### 3-3. 블라인드 해제 - 설문조사 완료 흐름

```
1. 사용자: 성향 테스트 완료
2. 백엔드: MemberSurvey.completedAt 설정
   - (기존 survey 기능에서 처리)
3. 사용자 → 프론트엔드: 강의 리뷰 조회
4. 백엔드: hasSurveyCompleted = true
5. 백엔드: isUnblinded = true
6. 프론트엔드: 모든 리뷰 표시
```

#### 3-4. 블라인드 해제 - 리뷰 승인 흐름

```
1. 관리자: 사용자의 리뷰를 APPROVED로 변경
   - (기존 admin review 기능에서 처리)
2. 사용자 → 프론트엔드: 강의 리뷰 조회
3. 백엔드: hasApprovedReview = true
4. 백엔드: isUnblinded = true
5. 프론트엔드: 모든 리뷰 표시
```

---

## 선택 정보 (더 정교한 다이어그램을 위해)

### 4. 조건부 흐름 (alt/opt)

| 시나리오 | 분기 조건 |
|----------|-----------|
| 요청자 식별 | 비회원 (토큰 없음) / 회원 (토큰 있음) |
| 블라인드 상태 | 해제 (isUnblinded: true) / 블라인드 (isUnblinded: false) |
| 해제 조건 | 설문 완료 OR 승인된 리뷰 보유 |

### 5. 반복 (loop)

- 없음

### 6. 병렬 처리 (par)

- 블라인드 조건 확인 시 두 쿼리 병렬 가능 (선택적 최적화)
  - 승인된 리뷰 존재 여부
  - 설문조사 완료 여부

### 7. 비동기 호출

- 모두 동기 호출

### 8. 노트/주석

- 비회원은 항상 블라인드 상태 (isUnblinded: false)
- totalCount는 블라인드 상태와 무관하게 실제 전체 개수 반환
- 기존 `Review.blurred` 필드와는 독립적으로 동작
  - blurred: 관리자가 개별 리뷰 내용 숨김
  - isUnblinded: 사용자별 전체 리뷰 접근 권한

---

## 추가 기술 정보

### 인증/인가 방식

| 항목 | 설명 |
|------|------|
| 리뷰 목록 조회 | Optional (비회원도 접근 가능, 블라인드 적용) |
| 블라인드 상태 조회 | 로그인 필수 |

### 데이터 관계

| 관계 | 설명 |
|------|------|
| Member : Review | 1 : N (회원당 여러 리뷰 작성 가능) |
| Member : MemberSurvey | 1 : 1 (회원당 1개 설문) |

### API 엔드포인트

| 기능 | Method | Endpoint | 인증 | 설명 |
|------|--------|----------|------|------|
| 강의별 리뷰 조회 | GET | /api/v1/lectures/{lectureId}/reviews | Optional | 블라인드 필터링 적용 |
| 블라인드 상태 조회 | GET | /api/v1/reviews/blind-status | 필수 | 현재 사용자의 해제 상태 |

### 응답 형식

**리뷰 목록 응답 (변경)**
```json
{
  "reviews": [...],
  "totalCount": 15,
  "isUnblinded": false
}
```

**블라인드 상태 응답 (신규)**
```json
{
  "isUnblinded": false,
  "hasApprovedReview": false,
  "hasSurveyCompleted": false
}
```

### 에러 케이스

| HTTP Status | 설명 | 발생 조건 |
|-------------|------|-----------|
| 401 Unauthorized | 인증 필요 | 블라인드 상태 조회 시 비로그인 |
