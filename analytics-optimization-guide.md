# Google Analytics API 성능 최적화 가이드

## 개요

Admin 대시보드의 Analytics API가 느린 원인을 분석하고 최적화 방안을 정리한 문서입니다.

**분석 대상 파일:**
- `sw-campus-api/.../analytics/AnalyticsController.java`
- `sw-campus-domain/.../analytics/AnalyticsService.java`
- `sw-campus-infra/analytics/.../GoogleAnalyticsRepository.java`
- `sw-campus-client/.../admin/components/dashboard/AdminDashboard.tsx`

---

## 현재 문제점

### 1. 순차적 GA API 호출 (가장 큰 병목)

`GoogleAnalyticsRepository.java`에서 Google Analytics Data API를 **동기적으로 순차 호출**합니다.

| 메서드 | GA API 호출 횟수 | 예상 소요 시간 |
|--------|-----------------|---------------|
| `getReport()` | 3회 (summary, daily, device) | 600~1500ms |
| `getEventStats()` | 2회 (events, bannerTypes) | 400~1000ms |
| `getTopLecturesByClicks()` | 2회 (clicks, views) | 400~1000ms |
| `getPopularLectures()` | 1회 | 200~500ms |
| `getPopularSearchTerms()` | 1회 | 200~500ms |

GA API 1회 호출당 약 **200~500ms** 소요 (네트워크 지연 포함)

#### 문제 코드 예시 (getReport)

```java
// 1번째 호출 - 총 통계
RunReportResponse summaryResponse = analyticsClient.runReport(...);

// 2번째 호출 - 일별 통계 (1번 완료 후 실행)
RunReportResponse dailyResponse = analyticsClient.runReport(...);

// 3번째 호출 - 기기별 통계 (2번 완료 후 실행)
RunReportResponse deviceResponse = analyticsClient.runReport(...);
```

### 2. 프론트엔드 다중 API 호출

`AdminDashboard.tsx` 페이지 로드 시 **6개 이상의 API를 호출**:

```
GET /admin/analytics              → 내부 3회 GA 호출
GET /admin/analytics/events       → 내부 2회 GA 호출
GET /admin/analytics/events/top-banners  → 1회 GA 호출
GET /admin/analytics/events/top-lectures → 2회 GA 호출
GET /admin/analytics/popular-lectures    → 1회 GA 호출
GET /admin/analytics/popular-search-terms → 1회 GA 호출
```

**총 10회 이상의 GA API 호출** 발생

### 3. 서버 캐싱 미적용

- 동일한 기간(예: 7일)에 대해 반복 요청 시에도 매번 GA API 호출
- GA 데이터는 실시간성이 크게 중요하지 않음 (5~10분 캐싱 가능)

---

## 최적화 방안

### 방안 1: 병렬 GA API 호출 (CompletableFuture)

**구현 난이도:** 낮음
**예상 효과:** 약 3배 성능 개선

#### Before (순차 실행)

```java
public AnalyticsReport getReport(int daysAgo) {
    RunReportResponse summary = analyticsClient.runReport(summaryRequest);   // 500ms
    RunReportResponse daily = analyticsClient.runReport(dailyRequest);       // 500ms
    RunReportResponse device = analyticsClient.runReport(deviceRequest);     // 500ms
    // 총 1500ms
}
```

#### After (병렬 실행)

```java
public AnalyticsReport getReport(int daysAgo) {
    String startDate = daysAgo + "daysAgo";
    String endDate = "today";

    // 병렬 실행
    CompletableFuture<RunReportResponse> summaryFuture = CompletableFuture.supplyAsync(() ->
        analyticsClient.runReport(buildSummaryRequest(startDate, endDate)));

    CompletableFuture<RunReportResponse> dailyFuture = CompletableFuture.supplyAsync(() ->
        analyticsClient.runReport(buildDailyRequest(startDate, endDate)));

    CompletableFuture<RunReportResponse> deviceFuture = CompletableFuture.supplyAsync(() ->
        analyticsClient.runReport(buildDeviceRequest(startDate, endDate)));

    // 모든 Future 완료 대기
    CompletableFuture.allOf(summaryFuture, dailyFuture, deviceFuture).join();

    // 결과 조합
    RunReportResponse summary = summaryFuture.join();
    RunReportResponse daily = dailyFuture.join();
    RunReportResponse device = deviceFuture.join();

    // 총 500ms (가장 오래 걸리는 요청 기준)
    return combineResults(summary, daily, device);
}
```

---

### 방안 2: Spring Cache 적용 (Caffeine)

**구현 난이도:** 낮음
**예상 효과:** 캐시 히트 시 즉시 응답 (< 10ms)

#### 1. 의존성 추가

```kotlin
// build.gradle.kts
implementation("org.springframework.boot:spring-boot-starter-cache")
implementation("com.github.ben-manes.caffeine:caffeine")
```

#### 2. 캐시 설정

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager caffeineCacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager(
            "analyticsReport",
            "eventStats",
            "topBanners",
            "topLectures",
            "popularLectures",
            "popularSearchTerms"
        );
        manager.setCaffeine(Caffeine.newBuilder()
            .expireAfterWrite(5, TimeUnit.MINUTES)  // 5분 TTL
            .maximumSize(100));
        return manager;
    }
}
```

#### 3. 캐시 적용

```java
@Service
public class AnalyticsService {

    @Cacheable(value = "analyticsReport", key = "#daysAgo")
    public AnalyticsReport getReport(int daysAgo) {
        return analyticsRepository.getReport(daysAgo);
    }

    @Cacheable(value = "eventStats", key = "#daysAgo")
    public EventStats getEventStats(int daysAgo) {
        return analyticsRepository.getEventStats(daysAgo);
    }

    @Cacheable(value = "topBanners", key = "#daysAgo + '-' + #limit")
    public List<BannerClickStats> getTopBannersByClicks(int daysAgo, int limit) {
        return analyticsRepository.getTopBannersByClicks(daysAgo, limit);
    }

    // ... 나머지 메서드도 동일
}
```

---

### 방안 3: GA4 BatchRunReportsRequest 활용

**구현 난이도:** 중간
**예상 효과:** HTTP 요청 횟수 감소

Google Analytics Data API는 **Batch 요청**을 지원합니다.

```java
BatchRunReportsResponse batchResponse = analyticsClient.batchRunReports(
    BatchRunReportsRequest.newBuilder()
        .setProperty("properties/" + propertyId)
        .addRequests(RunReportRequest.newBuilder()
            .addMetrics(Metric.newBuilder().setName("totalUsers"))
            // ... summary request
            .build())
        .addRequests(RunReportRequest.newBuilder()
            .addDimensions(Dimension.newBuilder().setName("date"))
            // ... daily request
            .build())
        .addRequests(RunReportRequest.newBuilder()
            .addDimensions(Dimension.newBuilder().setName("deviceCategory"))
            // ... device request
            .build())
        .build()
);

// 결과 추출
RunReportResponse summaryResponse = batchResponse.getReports(0);
RunReportResponse dailyResponse = batchResponse.getReports(1);
RunReportResponse deviceResponse = batchResponse.getReports(2);
```

---

### 방안 4: 통합 Dashboard API 추가

**구현 난이도:** 중간
**예상 효과:** HTTP 왕복 횟수 감소

현재 6개 엔드포인트를 1개로 통합:

```java
@GetMapping("/dashboard")
public ResponseEntity<DashboardResponse> getDashboard(
    @RequestParam(defaultValue = "7") int days,
    @RequestParam(defaultValue = "10") int limit
) {
    // 모든 데이터를 병렬로 조회
    CompletableFuture<AnalyticsReport> reportFuture =
        CompletableFuture.supplyAsync(() -> analyticsService.getReport(days));
    CompletableFuture<EventStats> eventsFuture =
        CompletableFuture.supplyAsync(() -> analyticsService.getEventStats(days));
    CompletableFuture<List<BannerClickStats>> bannersFuture =
        CompletableFuture.supplyAsync(() -> analyticsService.getTopBannersByClicks(days, limit));
    // ... 나머지

    CompletableFuture.allOf(reportFuture, eventsFuture, bannersFuture).join();

    return ResponseEntity.ok(DashboardResponse.builder()
        .report(reportFuture.join())
        .events(eventsFuture.join())
        .topBanners(bannersFuture.join())
        // ...
        .build());
}
```

---

## 구현 우선순위

| 순위 | 방안 | 구현 난이도 | 예상 효과 | 권장 |
|-----|------|-----------|---------|-----|
| 1 | 병렬 API 호출 (CompletableFuture) | 낮음 | 높음 (3배) | ✅ |
| 2 | Spring Cache (Caffeine) | 낮음 | 높음 | ✅ |
| 3 | BatchRunReportsRequest | 중간 | 중간 | 선택 |
| 4 | 통합 Dashboard API | 중간 | 중간 | 선택 |

**권장 구현 순서:**
1. 방안 1 + 방안 2를 함께 적용 (가장 효과적)
2. 필요 시 방안 3, 4 추가 적용

---

## 예상 성능 개선

| 시나리오 | Before | After (방안 1+2) |
|---------|--------|-----------------|
| 첫 로드 | 3~5초 | 1~1.5초 |
| 재방문 (5분 내) | 3~5초 | < 100ms |

---

## 참고 자료

- [Google Analytics Data API - Batch Requests](https://developers.google.com/analytics/devguides/reporting/data/v1/basics#batch)
- [Spring Cache with Caffeine](https://docs.spring.io/spring-boot/docs/current/reference/html/io.html#io.caching)
- [CompletableFuture Guide](https://www.baeldung.com/java-completablefuture)
