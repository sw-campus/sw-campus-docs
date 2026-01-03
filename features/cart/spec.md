# 장바구니 및 비교 (Cart) Spec

## 설계 결정

### 장바구니

#### 왜 토글이 아닌 추가/삭제 분리인가?

명확한 API 의도와 에러 처리.

```
POST /carts?lectureId=1  → 추가
DELETE /carts?lectureId=1 → 삭제
```

- REST 원칙 준수 (POST=생성, DELETE=삭제)
- 중복 추가 시 409 Conflict (명시적 에러)
- 토글 방식은 불필요한 DB 조회 발생

#### 왜 인증이 필수인가?

개인화된 장바구니 관리.

- 각 사용자마다 독립적인 장바구니
- 비교 후 수강 신청으로 연결
- 관심 강의 분석 가능

#### 왜 최대 10개 제한인가?

선택 효율성과 성능.

```java
if (count >= 10) {
    throw new CartLimitExceededException(...);
}
```

- 실제 사용: 3-5개 비교 후 선택
- 10개 이상은 선택 장애 유발
- 비교 페이지 렌더링 성능 유지

#### 왜 Redis 캐시 TTL이 7일인가?

활성 사용자 최적화.

```java
// Key: cart:{userId}
// Value: List<Long> (lectureId 리스트)
// TTL: 7일
```

- 1주일 미접속 = 비활성 사용자
- 캐시 자동 정리
- 추가/삭제 시 즉시 무효화

#### 왜 낙관적 업데이트를 사용하는가?

즉각적인 사용자 피드백.

```typescript
onMutate: async lectureId => {
  queryClient.setQueryData(cartLecturesQueryKey, old => [...old, { lectureId }])
}
onError: (_err, _lectureId, ctx) => {
  queryClient.setQueryData(cartLecturesQueryKey, ctx.previous)  // 롤백
}
```

- 버튼 클릭 → 즉시 플로팅 카트에 반영
- 실패 시 자동 롤백 + 에러 토스트

---

### 비교

#### 왜 2개만 비교하는가?

UI 가독성과 의사결정 최적화.

```
현재 UI: [라벨] [강의A] [구분선] [강의B]
3개 비교: 테이블 가로 스크롤 필요 (모바일 최악)
```

- 2개가 직관적인 비교 단위 (A vs B)
- 너무 많은 선택지 = 결정 장애
- 3번째 선택 시 가장 오래된 것(왼쪽)을 교체

#### 왜 같은 카테고리만 비교 가능한가?

의미 있는 비교 보장.

```typescript
const canUseItem = (itemCategory: string) => {
  if (!lockedCategory) return true
  return itemCategory === lockedCategory
}
```

- "웹 개발"과 "빅데이터" 비교는 무의미
- 첫 강의 선택 시 카테고리 잠금

#### 왜 AI 비교 분석을 클라이언트에서 하는가?

비용과 유연성.

```
Server: 순수 데이터 제공 (강의, 장바구니)
Client: UI + 비교 로직 + AI 호출 (Gemini API)
```

- 서버 부담 감소
- AI 분석 규칙 변경 = 프론트만 수정
- 30분 캐싱으로 중복 호출 방지

#### 왜 Zustand + React Query 조합인가?

상태의 생명주기에 따른 분리.

| 상태 | 도구 | 이유 |
|------|------|------|
| 선택된 2개 ID | Zustand | 일시적 UI 상태 |
| 강의 상세 | React Query | 서버 데이터, 캐싱 필요 |
| AI 분석 결과 | TanStack Query | 30분 캐싱 |

#### 왜 10개 비교 섹션인가?

국비지원 직업훈련의 핵심 요소.

| 섹션 | 내용 |
|------|------|
| education | 교육정보 (기간, 시간, 장소) |
| cost | 수강료 및 지원 |
| benefits | 추가 제공 항목 (훈련수당) |
| goal | 훈련목표 |
| quals | 지원자격 |
| equipment | 훈련시설 및 장비 |
| project | 프로젝트 |
| job | 취업 지원 서비스 |
| steps | 선발절차 |
| curriculum | 커리큘럼 |

---

## 구현 노트

### 2025-12-03 - 장바구니 초기 구현 [Server][Client]

- Server:
  - 장바구니 CRUD (`CartController`, `CartService`)
  - Redis 캐시 (7일 TTL)
  - 최대 10개 제한 (`CartLimitExceededException`)
  - 중복 추가 방지 (`AlreadyInCartException`)
- Client:
  - `AddToCartButton` 컴포넌트
  - `FloatingCart` 하단 고정 UI
  - 낙관적 업데이트 (`useAddToCart`, `useRemoveFromCart`)

### 2025-12-04 - 비교 기능 구현 [Client]

- `CartCompareSection` 메인 UI
- 드래그앤드롭 강의 선택
- Gemini API 기반 AI 비교 분석
- 10개 섹션 비교표
- 관련: `CartCompareSection.tsx`, `useAiCompare.ts`, `cartCompare.store.ts`
