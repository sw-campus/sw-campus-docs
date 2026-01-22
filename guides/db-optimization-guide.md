# SW Campus DB 최적화 가이드

## 1. 개요

### 1.1 현재 상태

- **DB**: PostgreSQL 16
- **주요 테이블**: lectures (1,051건), reviews (60건), organizations (274건)
- **문제점**: FK 컬럼에 인덱스 부재, 텍스트 검색 최적화 없음

### 1.2 최적화 효과 요약

| 최적화 항목               | Before                 | After                   | 개선율        |
| ------------------------- | ---------------------- | ----------------------- | ------------- |
| 기관별 강의 조회          | Seq Scan (146 buffers) | Index Scan (47 buffers) | **68% 감소**  |
| 강의 상세 API             | 4번 쿼리               | 1번 쿼리 (JOIN)         | **75% 감소**  |
| 텍스트 검색 (희귀 키워드) | 1ms                    | 0.1ms                   | **10배 빠름** |

---

## 2. 인덱스 기본 원리

### 2.1 B-Tree 인덱스

PostgreSQL 기본 인덱스는 **B-Tree (Balanced Tree)** 자료구조 사용.

```
탐색 알고리즘: 이진 탐색 (Binary Search)
시간 복잡도: O(log N)

예시: 1,051건에서 검색
- Full Scan: 1,051번 비교
- Index Scan: log₂(1051) ≈ 10번 비교
```

**B-Tree 구조:**

```
                      [500]                        ← 레벨 0 (루트)
                     /     \
              [250]          [750]                 ← 레벨 1
             /     \        /     \
        [100,200] [300,400] [600,700] [800,900]    ← 레벨 2 (리프)
```

### 2.2 스캔 횟수 계산 공식

```
Full Table Scan = N (전체 행 수)
Index Scan = log₂(N) + M (결과 행 수)
```

| 데이터 규모 | Full Scan   | Index Scan | 개선율   |
| ----------- | ----------- | ---------- | -------- |
| 1,000건     | 1,000번     | ~60번      | 17배     |
| 10,000건    | 10,000번    | ~63번      | 159배    |
| 100,000건   | 100,000번   | ~67번      | 1,493배  |
| 1,000,000건 | 1,000,000번 | ~70번      | 14,286배 |

---

## 3. EXPLAIN 분석 결과

### 3.1 기관별 강의 조회 (lectures.org_id)

**쿼리:**

```sql
SELECT * FROM swcampus.lectures
WHERE org_id = 82 AND lecture_auth_status = 'APPROVED';
```

**Before (인덱스 없음):**

```
Seq Scan on lectures  (cost=0.00..161.71 rows=64 width=1054) (actual time=0.062..0.258 rows=64 loops=1)
  Filter: ((org_id = 82) AND ((lecture_auth_status)::text = 'APPROVED'::text))
  Rows Removed by Filter: 987
  Buffers: shared hit=146

Execution Time: 0.272 ms
```

**After (인덱스 추가):**

```
Bitmap Heap Scan on lectures  (cost=4.77..121.94 rows=64 width=563) (actual time=0.032..0.083 rows=64 loops=1)
  Recheck Cond: (org_id = 82)
  Filter: ((lecture_auth_status)::text = 'APPROVED'::text)
  Heap Blocks: exact=42
  Buffers: shared hit=45 read=2
  ->  Bitmap Index Scan on idx_lectures_org_id  (cost=0.00..4.76 rows=64 width=0) (actual time=0.019..0.019 rows=64 loops=1)
        Index Cond: (org_id = 82)
        Buffers: shared hit=3 read=2

Execution Time: 0.104 ms
```

**비교:**
| 항목 | Before | After | 개선 |
|-----|--------|-------|------|
| 스캔 방식 | Seq Scan | Bitmap Index Scan | ✅ |
| Buffers | 146 | 47 | **68% 감소** |
| 실행 시간 | 0.272ms | 0.104ms | **62% 빠름** |

---

### 3.2 리뷰 조회 (reviews.lecture_id)

**쿼리:**

```sql
SELECT * FROM swcampus.reviews
WHERE lecture_id = 1127 AND approval_status = 'APPROVED';
```

**Before (인덱스 없음):**

```
Seq Scan on reviews  (cost=0.00..5.90 rows=15 width=199) (actual time=0.008..0.018 rows=15 loops=1)
  Filter: ((lecture_id = 1127) AND ((approval_status)::text = 'APPROVED'::text))
  Rows Removed by Filter: 45
  Buffers: shared hit=5

Execution Time: 0.031 ms
```

**분석:**

- 현재 reviews 테이블이 60건으로 적어서 인덱스 효과 미미
- PostgreSQL 옵티마이저가 "테이블이 작으면 Seq Scan이 더 효율적"이라고 판단
- 데이터가 1,000건 이상 쌓이면 인덱스 효과 발생

---

### 3.3 텍스트 검색 (GIN + pg_trgm)

**쿼리:**

```sql
SELECT lecture_id, lecture_name
FROM swcampus.lectures
WHERE lecture_name ILIKE '%블록체인%';
```

**Before (인덱스 없음):**

```
Seq Scan on lectures  (cost=0.00..159.14 rows=11 width=73) (actual time=0.027..1.050 rows=10 loops=1)
  Filter: ((lecture_name)::text ~~* '%블록체인%'::text)
  Rows Removed by Filter: 1041
  Buffers: shared hit=146

Execution Time: 1.082 ms
```

**After (GIN 인덱스 추가):**

```
Bitmap Heap Scan on lectures  (cost=21.57..56.65 rows=11 width=73) (actual time=0.027..0.049 rows=10 loops=1)
  Recheck Cond: ((lecture_name)::text ~~* '%블록체인%'::text)
  Heap Blocks: exact=10
  Buffers: shared hit=15
  ->  Bitmap Index Scan on idx_lectures_name_trgm  (cost=0.00..21.56 rows=11 width=0) (actual time=0.019..0.019 rows=10 loops=1)
        Index Cond: ((lecture_name)::text ~~* '%블록체인%'::text)
        Buffers: shared hit=5

Execution Time: 0.104 ms
```

**비교:**
| 항목 | Before | After | 개선 |
|-----|--------|-------|------|
| 스캔 방식 | Seq Scan | Bitmap Index Scan | ✅ |
| Buffers | 146 | 15 | **90% 감소** |
| 실행 시간 | 1.082ms | 0.104ms | **10배 빠름** |

**참고:** GIN 인덱스는 결과가 전체의 10% 이하일 때 효과적. 흔한 키워드(예: "개발")는 Seq Scan 유지.

---

## 4. 적용할 인덱스

### 4.1 B-Tree 인덱스 (필수)

```sql
-- 기관별 강의 조회 최적화
CREATE INDEX idx_lectures_org_id ON swcampus.lectures(org_id);
CREATE INDEX idx_lectures_status ON swcampus.lectures(status);
CREATE INDEX idx_lectures_auth_status ON swcampus.lectures(lecture_auth_status);

-- 리뷰 조회 최적화
CREATE INDEX idx_reviews_lecture_id ON swcampus.reviews(lecture_id);
CREATE INDEX idx_reviews_member_id ON swcampus.reviews(member_id);
CREATE INDEX idx_reviews_approval_status ON swcampus.reviews(approval_status);

-- 수료증 조회 최적화
CREATE INDEX idx_certificates_member_id ON swcampus.certificates(member_id);
CREATE INDEX idx_certificates_lecture_id ON swcampus.certificates(lecture_id);

-- 기타 FK 인덱스
CREATE INDEX idx_social_accounts_member_id ON swcampus.social_accounts(member_id);
CREATE INDEX idx_organizations_user_id ON swcampus.organizations(user_id);
```

### 4.2 GIN + pg_trgm 인덱스 (텍스트 검색)

```sql
-- pg_trgm 확장 설치
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 강의명 검색 최적화 (ILIKE '%keyword%' 지원)
CREATE INDEX idx_lectures_name_trgm ON swcampus.lectures
    USING GIN (lecture_name gin_trgm_ops);

-- 기관명 검색 최적화
CREATE INDEX idx_organizations_name_trgm ON swcampus.organizations
    USING GIN (org_name gin_trgm_ops);
```

**GIN 인덱스 효과:**

- B-Tree는 `LIKE '%keyword%'` 패턴에서 인덱스 사용 불가
- GIN + pg_trgm은 부분 문자열 검색도 인덱스 사용 가능
- 희귀한 키워드일수록 효과 큼 (결과가 전체의 10% 이하일 때)

---

## 5. 쿼리 최적화

### 5.1 강의 상세 API JOIN 통합

**현재 (4번 쿼리):**

```java
// LectureController.java:164-167
var lectureSummary = lectureService.getLectureWithStats(lectureId);  // 3번 쿼리
organization = organizationService.getOrganization(orgId);           // 1번 쿼리
```

```java
// LectureService.java:162-168
Lecture lecture = getPublishedLecture(lectureId);        // 쿼리 1: 강의 조회
Double averageScore = getAverageScoresByLectureIds(...); // 쿼리 2: 평균 점수
Long reviewCount = getReviewCountsByLectureIds(...);     // 쿼리 3: 리뷰 개수
```

**개선안 (1번 쿼리):**

```sql
SELECT
    l.*,
    o.org_name, o.org_logo_url,
    AVG(r.score) as avg_score,
    COUNT(r.review_id) as review_count
FROM lectures l
LEFT JOIN organizations o ON l.org_id = o.org_id
LEFT JOIN reviews r ON r.lecture_id = l.lecture_id
    AND r.approval_status = 'APPROVED'
WHERE l.lecture_id = ?
GROUP BY l.lecture_id, o.org_id;
```

### 5.2 EXISTS → JOIN 변경

**현재 (ReviewJpaRepository.java:29):**

```java
@Query("SELECT r FROM ReviewEntity r LEFT JOIN FETCH r.details " +
       "WHERE EXISTS (SELECT 1 FROM LectureEntity l " +
       "WHERE l.lectureId = r.lectureId AND l.orgId = :organizationId) " +
       "AND r.approvalStatus = :status")
```

**개선안:**

```java
@Query("SELECT DISTINCT r FROM ReviewEntity r " +
       "LEFT JOIN FETCH r.details " +
       "JOIN LectureEntity l ON l.lectureId = r.lectureId " +
       "WHERE l.orgId = :organizationId " +
       "AND r.approvalStatus = :status")
```

---

## 6. 인덱스 알고리즘 선택 가이드

| 쿼리 패턴                | 권장 인덱스   | 예시                            |
| ------------------------ | ------------- | ------------------------------- |
| `=`, `<`, `>`, `BETWEEN` | B-Tree        | `WHERE org_id = 123`            |
| `LIKE 'prefix%'`         | B-Tree        | `WHERE name LIKE 'AI%'`         |
| `LIKE '%keyword%'`       | GIN + pg_trgm | `WHERE name ILIKE '%블록체인%'` |
| 시계열 범위 (대용량)     | BRIN          | `WHERE created_at BETWEEN ...`  |
| 배열, JSONB              | GIN           | `WHERE tags @> ARRAY['java']`   |

### PostgreSQL 옵티마이저 판단 기준

```
결과가 전체의 5~10% 이하 → 인덱스 사용
결과가 전체의 30% 이상  → Seq Scan 선택 (더 효율적)

예시:
- "블록체인" = 10개 / 1,051개 = 0.9% → 인덱스 사용 ✅
- "개발"     = 512개 / 1,051개 = 49% → Seq Scan 선택
```

---

## 7. LIKE vs ILIKE 비교 가이드

### 7.1 기본 비교

| 특성                | `LIKE`                  | `ILIKE`                      |
| ------------------- | ----------------------- | ---------------------------- |
| **대소문자 구분**   | O (Case-sensitive)      | X (Case-insensitive)         |
| **성능**            | 약간 더 빠름            | 약간 더 느림                 |
| **인덱스 사용**     | B-tree 인덱스 사용 가능 | 일반 B-tree 인덱스 사용 불가 |
| **PostgreSQL 전용** | X (표준 SQL)            | O (PostgreSQL 확장)          |

### 7.2 언제 ILIKE를 사용할까?

```
✅ ILIKE 권장:
- 사용자 검색 기능 (대소문자 무관하게 검색)
- 데이터 일관성이 보장되지 않는 경우
- UX 관점에서 유연한 검색이 필요할 때

❌ LIKE 권장:
- 정확한 대소문자 매칭이 필요한 경우
- 코드, 식별자 등 정해진 포맷 검색
- 외부 시스템과의 호환성이 중요한 경우
```

**예시:**

```sql
-- ILIKE: "spring", "Spring", "SPRING" 모두 매칭
SELECT * FROM lectures WHERE lecture_name ILIKE '%spring%';

-- LIKE: 정확히 "Spring"만 매칭
SELECT * FROM lectures WHERE lecture_name LIKE '%Spring%';
```

### 7.3 ILIKE 인덱스 최적화

일반 B-Tree 인덱스는 `ILIKE`에서 사용 불가. **pg_trgm + GIN 인덱스**로 해결:

```sql
-- pg_trgm 확장 설치
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN 인덱스 생성
CREATE INDEX idx_lectures_name_trgm ON swcampus.lectures
    USING GIN (lecture_name gin_trgm_ops);

-- 이제 ILIKE도 인덱스 활용 가능!
SELECT * FROM lectures WHERE lecture_name ILIKE '%spring%';
```

### 7.4 대안: LOWER() 함수 + 함수 인덱스

```sql
-- 함수 인덱스 생성
CREATE INDEX idx_lectures_name_lower ON swcampus.lectures (LOWER(lecture_name));

-- LIKE 사용하되 양쪽 다 소문자 변환
SELECT * FROM lectures
WHERE LOWER(lecture_name) LIKE LOWER('%spring%');
```

**주의:** `LIKE '%keyword%'` 패턴에서는 함수 인덱스도 사용 불가.
전방 일치(`LIKE 'keyword%'`)에서만 효과적.

### 7.5 성능 비교 요약

| 방식                | 인덱스 지원          | 성능 | 권장 상황      |
| ------------------- | -------------------- | ---- | -------------- |
| `LIKE 'prefix%'`    | B-Tree ✅            | 빠름 | 전방 일치 검색 |
| `LIKE '%keyword%'`  | X                    | 느림 | 사용 자제      |
| `ILIKE '%keyword%'` | GIN + pg_trgm ✅     | 보통 | 사용자 검색    |
| `LOWER() + LIKE`    | 함수 인덱스 (제한적) | 보통 | 전방 일치만    |

**결론:** 사용자 검색 기능에는 `ILIKE` + `pg_trgm 인덱스` 조합 권장.

---

## 8. 마이그레이션 파일

**파일 위치:** `sw-campus-server/sw-campus-infra/db-postgres/src/main/resources/db/migration/V{N}__add_performance_indexes.sql`

```sql
-- =============================================
-- V{N}__add_performance_indexes.sql
-- 성능 최적화를 위한 인덱스 추가
-- =============================================

-- 1. B-Tree 인덱스
CREATE INDEX IF NOT EXISTS idx_lectures_org_id
    ON swcampus.lectures(org_id);
CREATE INDEX IF NOT EXISTS idx_lectures_status
    ON swcampus.lectures(status);
CREATE INDEX IF NOT EXISTS idx_lectures_auth_status
    ON swcampus.lectures(lecture_auth_status);

CREATE INDEX IF NOT EXISTS idx_reviews_lecture_id
    ON swcampus.reviews(lecture_id);
CREATE INDEX IF NOT EXISTS idx_reviews_member_id
    ON swcampus.reviews(member_id);
CREATE INDEX IF NOT EXISTS idx_reviews_approval_status
    ON swcampus.reviews(approval_status);

CREATE INDEX IF NOT EXISTS idx_certificates_member_id
    ON swcampus.certificates(member_id);
CREATE INDEX IF NOT EXISTS idx_certificates_lecture_id
    ON swcampus.certificates(lecture_id);

CREATE INDEX IF NOT EXISTS idx_social_accounts_member_id
    ON swcampus.social_accounts(member_id);
CREATE INDEX IF NOT EXISTS idx_organizations_user_id
    ON swcampus.organizations(user_id);

-- 2. GIN + pg_trgm 인덱스 (텍스트 검색)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_lectures_name_trgm
    ON swcampus.lectures USING GIN (lecture_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_organizations_name_trgm
    ON swcampus.organizations USING GIN (org_name gin_trgm_ops);
```

---

## 9. 검증 방법

### 9.1 EXPLAIN으로 인덱스 사용 확인

```sql
-- 인덱스 사용 여부 확인
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM swcampus.lectures WHERE org_id = 82;

-- 기대 결과: "Index Scan" 또는 "Bitmap Index Scan"
-- 나쁜 결과: "Seq Scan"
```

### 9.2 테이블별 스캔 통계 확인

```sql
SELECT
    relname as table_name,
    seq_scan,        -- Sequential Scan 횟수
    seq_tup_read,    -- Seq Scan으로 읽은 행 수
    idx_scan,        -- Index Scan 횟수
    idx_tup_fetch    -- Index Scan으로 읽은 행 수
FROM pg_stat_user_tables
WHERE schemaname = 'swcampus'
ORDER BY seq_tup_read DESC;
```

### 9.3 인덱스 목록 확인

```sql
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'swcampus'
ORDER BY tablename;
```

---

## 10. 주의사항

### 10.1 인덱스 추가 시 고려사항

```
✅ 인덱스 추가 권장:
- WHERE 절에 자주 사용되는 컬럼
- JOIN 조건에 사용되는 FK 컬럼
- ORDER BY에 자주 사용되는 컬럼

❌ 인덱스 추가 비권장:
- 자주 UPDATE되는 컬럼 (인덱스 유지 비용)
- 카디널리티가 낮은 컬럼 (예: boolean - true/false만)
- 거의 사용되지 않는 컬럼
```

### 10.2 PostgreSQL 특성

```
- VARCHAR vs TEXT: 성능 차이 없음 (동일 저장 방식)
- VARCHAR(255) vs VARCHAR(100): 성능 차이 없음 (실제 크기만큼만 저장)
- 컬럼 크기 최적화보다 인덱스 최적화가 효과적
```

### 10.3 인덱스 부작용

```
인덱스 추가 시:
- SELECT 속도 향상 ✅
- INSERT/UPDATE/DELETE 속도 저하 ⚠️ (인덱스도 함께 수정해야 함)
- 저장 공간 추가 사용 ⚠️

→ 자주 조회하는 컬럼에만 인덱스 추가
```

---

## 11. 참고: 현재 테이블 통계

### 11.1 테이블별 데이터 수

| 테이블          | 행 수 | 테이블 크기 | 평균 행 크기 |
| --------------- | ----- | ----------- | ------------ |
| lectures        | 1,051 | 1,168 KB    | 1,137 bytes  |
| reviews         | 60    | 40 KB       | 682 bytes    |
| reviews_details | 300   | 48 KB       | 163 bytes    |
| organizations   | 274   | 72 KB       | -            |
| certificates    | 60    | 40 KB       | 682 bytes    |
| members         | 19    | 8 KB        | 431 bytes    |

### 11.2 테이블 스캔 현황 (최적화 전)

| 테이블              | Seq Scan 횟수 | 읽은 행 수 | 문제점              |
| ------------------- | ------------- | ---------- | ------------------- |
| lecture_curriculums | 159           | 1,671,462  | 40행을 167만번 읽음 |
| reviews             | 4,599         | 163,917    | 60행을 16만번 읽음  |
| lectures            | 142           | 149,319    | -                   |

---

## 12. CompletableFuture vs WebFlux 개념 비교

### 12.1 CompletableFuture는 WebFlux가 아닙니다!

많은 개발자들이 CompletableFuture와 WebFlux를 혼동하는데, 두 기술은 **완전히 다른 목적과 복잡도**를 가지고 있습니다.

| 구분               | CompletableFuture             | WebFlux (Reactor)                  |
| :----------------- | :---------------------------- | :--------------------------------- |
| **도입 시점**      | Java 8 (2014년)               | Spring 5 (2017년)                  |
| **패러다임**       | 비동기 처리 유틸리티          | 리액티브 스트림 프레임워크         |
| **복잡도**         | 쉬움 ✅                       | 어려움 ❌                          |
| **현업 사용**      | 매우 많이 사용                | 제한적 사용                        |
| **학습 곡선**      | 낮음 (3가지 메서드만 알면 됨) | 높음 (Mono, Flux, backpressure 등) |
| **기존 코드 호환** | 기존 동기 코드에 쉽게 적용    | 전체 앱을 리액티브로 전환 필요     |
| **디버깅**         | 쉬움 (일반 스택 트레이스)     | 어려움 (비동기 스택 트레이스)      |

### 12.2 CompletableFuture 핵심 패턴 (3가지만 기억하세요)

```java
// 1. 비동기 작업 시작
CompletableFuture<Result> future = CompletableFuture.supplyAsync(() -> {
    return someSlowOperation();
});

// 2. 여러 작업 동시 실행 후 대기
CompletableFuture.allOf(future1, future2, future3).join();

// 3. 결과 가져오기
Result result = future.join();
```

### 12.3 WebFlux가 어려운 이유

```java
// WebFlux 코드 - 전체 앱이 리액티브해야 함
return webClient.get()
    .uri("/api1")
    .retrieve()
    .bodyToMono(A.class)
    .flatMap(a -> webClient.get()
        .uri("/api2/" + a.getId())
        .retrieve()
        .bodyToMono(B.class))
    .zipWith(...)
    .onErrorResume(e -> Mono.empty())
    .subscribeOn(Schedulers.parallel());

// 문제점:
// 1. 콜백 지옥 비슷한 구조
// 2. 디버깅이 매우 어려움
// 3. 팀 전체가 리액티브 프로그래밍을 알아야 함
// 4. 기존 동기 라이브러리와 호환 어려움
```

### 12.4 현업에서의 사용 현황

- **CompletableFuture**:

  - 여러 외부 API를 병렬 호출할 때 **필수적으로 사용**
  - Java 표준 라이브러리라 별도 학습 비용 낮음
  - 대부분의 Spring MVC 프로젝트에서 사용 가능

- **WebFlux**:
  - 높은 동시 연결 처리 (예: 실시간 채팅, 스트리밍)
  - Netflix, Kakao 등 대규모 트래픽 처리 팀에서 사용
  - 팀 전체 학습 비용과 마이그레이션 비용이 큼

### 12.5 결론

> **CompletableFuture는 "단순히 여러 작업을 동시에 실행"하는 유틸리티입니다.**
>
> WebFlux처럼 복잡한 리액티브 프로그래밍이 아니며, 현업에서도 매우 많이 사용됩니다.
> 기존 Spring MVC 프로젝트에서 외부 API 병렬 호출 시 가장 좋은 선택입니다.

---

## 13. 변경 이력

| 날짜       | 작성자 | 내용      |
| ---------- | ------ | --------- |
| 2025-12-26 | -      | 최초 작성 |
