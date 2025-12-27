# 쿼리 최적화 요약

---

## 적용된 최적화

| 항목              | 방안                        | 효과                      |
| ----------------- | --------------------------- | ------------------------- |
| `findById()`      | 리뷰 평균/개수 쿼리 통합    | 3회 → 2회 쿼리 (33% 감소) |
| `findAllByIds()`  | 리뷰 통계 쿼리 통합         | 2회 → 1회 쿼리 (50% 감소) |
| 강의 검색         | 리뷰 통계 쿼리 통합         | 2회 → 1회 쿼리 (50% 감소) |
| 장바구니          | 불필요한 리뷰 조회 제거     | 2회 → 1회 쿼리 (50% 감소) |
| 강의 상세         | Redis 캐싱 (Cache-Aside)    | 캐시 히트 시 <5ms         |
| AI 요약           | TanStack Query 캐싱         | 영구 캐싱                 |
| AI 비교           | TanStack Query 캐싱         | 재비교 시 즉시 응답       |
| **GA4 Analytics** | CompletableFuture 병렬 호출 | 1.5초 → 0.5초 (3배 개선)  |
| **GA4 Analytics** | Caffeine 캐시 (5분 TTL)     | 캐시 히트 시 <10ms        |

---

## 최적화 상세

### 1. 리뷰 통계 쿼리 통합

**문제:** 평균 점수와 리뷰 수를 각각 별도 쿼리로 조회

```java
// Before: 2회 쿼리
Double avgScore = reviewRepository.getAverageScoreByLectureId(id);
Long reviewCount = reviewRepository.countReviewsByLectureId(id);
```

**해결:** 한 번의 쿼리로 통합

```java
// After: 1회 쿼리
@Query("SELECT COALESCE(AVG(r.score), 0.0), COUNT(r) " +
       "FROM ReviewEntity r " +
       "WHERE r.lectureId = :lectureId AND r.approvalStatus = 'APPROVED'")
Object[] findReviewStatsByLectureId(@Param("lectureId") Long lectureId);
```

### 2. 장바구니 쿼리 최적화

**문제:** 장바구니에서 불필요한 리뷰 통계까지 조회

```java
// Before: 리뷰 통계 포함 조회
lectureRepository.findAllByIds(lectureIds);  // 내부에서 리뷰 통계 쿼리 추가 발생
```

**해결:** 리뷰 통계 없이 조회하는 전용 메서드 생성

```java
// After: 리뷰 통계 조회 생략
lectureRepository.findAllByIdsWithoutReviewStats(lectureIds);
```

### 3. Redis 캐싱 (Cache-Aside 패턴)

**문제:** 매 요청마다 DB 조회 발생

**해결:** 자주 조회되는 강의 상세 정보를 Redis에 캐싱

```java
public Lecture getLecture(Long lectureId) {
    // 1. 캐시 조회
    Optional<Lecture> cached = lectureCacheRepository.getLecture(lectureId);
    if (cached.isPresent()) return cached.get();

    // 2. DB 조회
    Lecture lecture = lectureRepository.findById(lectureId)...;

    // 3. 캐시 저장
    lectureCacheRepository.saveLecture(lecture);
    return lecture;
}
```

### 4. AI 비교 결과 캐싱

**문제:** 동일한 강의 조합 재비교 시 Gemini API 재호출 (~1.5초)

**해결:** TanStack Query로 클라이언트 캐싱

```typescript
// 캐시 키: [leftId, rightId] 정렬 → 동일 조합 = 동일 캐시
const queryKey = ["ai-compare", sortedIds[0], sortedIds[1]];

return useQuery({
  queryKey,
  staleTime: 30 * 60 * 1000, // 30분
  gcTime: 60 * 60 * 1000, // 1시간
});
```

---

## 성능 개선 결과

| 시나리오                   | Before           | After               |
| -------------------------- | ---------------- | ------------------- |
| 강의 상세 조회 (캐시 미스) | 3회 쿼리, ~30ms  | 2회 쿼리, ~20ms     |
| 강의 상세 조회 (캐시 히트) | 3회 쿼리, ~30ms  | **0회 쿼리, <5ms**  |
| 장바구니 목록 조회         | 4회 쿼리, ~50ms  | **2회 쿼리, ~20ms** |
| 비교 페이지 (2개 강의)     | 6회 쿼리, ~100ms | **0회 쿼리, <10ms** |
| AI 비교 재요청             | ~1.5초           | **<1ms**            |
| **Admin 대시보드 첫 로드** | 3~5초            | **1~1.5초**         |
| **Admin 대시보드 재방문**  | 3~5초            | **< 100ms**         |

---

## GA4 Analytics API 최적화

### 문제점

Admin 대시보드 로드 시 **10회 이상의 GA API 순차 호출** 발생 (총 3~5초 소요)

```
GET /admin/analytics              → 내부 3회 GA 호출
GET /admin/analytics/events       → 내부 2회 GA 호출
GET /admin/analytics/events/top-banners  → 1회 GA 호출
GET /admin/analytics/events/top-lectures → 2회 GA 호출
GET /admin/analytics/popular-lectures    → 1회 GA 호출
GET /admin/analytics/popular-search-terms → 1회 GA 호출
```

### 해결: CompletableFuture 병렬 호출

순차 실행되던 GA API 호출을 병렬로 변경:

```java
// Before: 순차 실행 (1500ms)
RunReportResponse summary = analyticsClient.runReport(summaryRequest);
RunReportResponse daily = analyticsClient.runReport(dailyRequest);
RunReportResponse device = analyticsClient.runReport(deviceRequest);

// After: 병렬 실행 (500ms)
CompletableFuture<RunReportResponse> summaryFuture = CompletableFuture.supplyAsync(() ->
    analyticsClient.runReport(summaryRequest));
CompletableFuture<RunReportResponse> dailyFuture = CompletableFuture.supplyAsync(() ->
    analyticsClient.runReport(dailyRequest));
CompletableFuture<RunReportResponse> deviceFuture = CompletableFuture.supplyAsync(() ->
    analyticsClient.runReport(deviceRequest));

CompletableFuture.allOf(summaryFuture, dailyFuture, deviceFuture).join();
```

**적용된 메서드:**

| 메서드                     | GA API 호출 | Before  | After  |
| -------------------------- | ----------- | ------- | ------ |
| `getReport()`              | 3개         | ~1500ms | ~500ms |
| `getEventStats()`          | 2개         | ~1000ms | ~500ms |
| `getTopLecturesByClicks()` | 2개         | ~1000ms | ~500ms |

### 해결: Caffeine 캐시

5분간 API 응답을 캐싱하여 반복 요청 시 즉시 응답:

```java
@Service
public class AnalyticsService {
    @Cacheable(value = "analyticsReport", key = "#daysAgo")
    public AnalyticsReport getReport(int daysAgo) { ... }

    @Cacheable(value = "eventStats", key = "#daysAgo")
    public EventStats getEventStats(int daysAgo) { ... }

    @Cacheable(value = "topBanners", key = "#daysAgo + '-' + #limit")
    public List<BannerClickStats> getTopBannersByClicks(int daysAgo, int limit) { ... }
    // ... 6개 메서드 모두 캐싱 적용
}
```

### 성능 개선 결과

| 시나리오               | Before | After       |
| ---------------------- | ------ | ----------- |
| Admin 대시보드 첫 로드 | 3~5초  | **1~1.5초** |
| 5분 내 재방문          | 3~5초  | **< 100ms** |

---

## 캐시 설정

### Redis (강의 상세)

| 항목    | 값                    |
| ------- | --------------------- |
| 키 패턴 | `lecture:{lectureId}` |
| TTL     | 30분                  |
| 무효화  | 강의 수정 시          |

### TanStack Query (AI 비교)

| 항목      | 값                         |
| --------- | -------------------------- |
| 캐시 키   | `[leftId, rightId]` (정렬) |
| staleTime | 30분                       |
| gcTime    | 1시간                      |

### Caffeine (GA4 Analytics)

| 캐시명             | 키 구조         | TTL |
| ------------------ | --------------- | --- |
| analyticsReport    | `daysAgo`       | 5분 |
| eventStats         | `daysAgo`       | 5분 |
| topBanners         | `daysAgo-limit` | 5분 |
| topLectures        | `daysAgo-limit` | 5분 |
| popularLectures    | `daysAgo-limit` | 5분 |
| popularSearchTerms | `daysAgo-limit` | 5분 |

---

## 참고: PostgreSQL GROUP BY 제약

| DB             | GROUP BY 규칙                                                                 |
| -------------- | ----------------------------------------------------------------------------- |
| MySQL          | 느슨함 (ONLY_FULL_GROUP_BY off 가능)                                          |
| **PostgreSQL** | **엄격함** (모든 SELECT 컬럼이 GROUP BY에 포함되거나 집계함수 안에 있어야 함) |

> LEFT JOIN FETCH는 연관 엔티티의 모든 컬럼을 SELECT에 포함시키므로, `GROUP BY l`만으로는 PostgreSQL 규칙을 충족할 수 없어 쿼리를 분리함.
