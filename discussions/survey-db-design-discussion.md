# 설문조사(Survey) DB 설계 회의 자료

> **작성일**: 2025년 12월 12일  
> **목적**: 설문조사 기능의 DB 스키마 설계 결정

---

## 📋 요구사항 정리

### 설문 항목

| 항목 | 필드명 | 타입 | Nullable | 입력 방식 |
|------|--------|------|----------|----------|
| 전공 | major | String | ✅ | 자유 입력 |
| 부트캠프 수료 경험 | bootcampCompleted | Boolean | ❌ | 선택 |
| 희망직무 | wantedJobs | **복수** | ❌ | 자유 입력 (복수) |
| 자격증 | licenses | **복수** | ✅ | 자유 입력 (복수) |
| 내일배움카드 여부 | hasGovCard | Boolean | ❌ | 선택 |
| 자비부담 여유 | affordableAmount | BigDecimal | ✅ | 숫자 입력 |

### 비즈니스 요구사항

- 회원가입 후 설문조사 작성
- **수정 가능** (회원정보 수정과 별도로 설문조사 수정)
- **LLM 추천 기능의 핵심 데이터** (프론트 → AI 서버로 프롬프트와 함께 전달)
- 질문 텍스트(지문)는 **프론트엔드에서 관리**

---

## 🎯 핵심 결정 사항: 복수 선택 항목 저장 방식

### 옵션 비교표

| 옵션 | 테이블 수 | 코드 복잡도 | 검색 용이성 | DB 이식성 |
|------|----------|------------|------------|----------|
| **1. @ElementCollection** | 3개 | 낮음 | ⭐⭐⭐ | ⭐⭐⭐ |
| 2. 콤마 구분 문자열 | 1개 | 가장 낮음 | ⭐ | ⭐⭐⭐ |
| 3. PostgreSQL ARRAY | 1개 | 낮음 | ⭐⭐ | ⭐ |
| 4. JSONB | 1개 | 중간 | ⭐⭐ | ⭐⭐ |

---

## 옵션 상세 설명

### 옵션 1: @ElementCollection (JPA 표준)

**구조**
```
member_surveys (메인 테이블)
├─ user_id (PK)
├─ major
├─ bootcamp_completed
├─ has_gov_card
└─ affordable_amount

member_survey_wanted_jobs (자동 생성)
├─ user_id (FK)
└─ wanted_job

member_survey_licenses (자동 생성)
├─ user_id (FK)
└─ license
```

**데이터 예시**

member_surveys:
| user_id | major | bootcamp_completed | has_gov_card | affordable_amount |
|---------|-------|-------------------|--------------|-------------------|
| 1 | 컴퓨터공학 | true | true | 500000 |

member_survey_wanted_jobs:
| user_id | wanted_job |
|---------|------------|
| 1 | 백엔드 개발자 |
| 1 | 데이터 엔지니어 |

member_survey_licenses:
| user_id | license |
|---------|---------|
| 1 | 정보처리기사 |
| 1 | SQLD |

**장점**
- JPA 표준, DB 이식성 좋음
- 정규화된 구조
- 개별 값 검색/필터링 용이

**단점**
- 테이블 3개 생성
- 수정 시 전체 삭제 후 재삽입 (Delete-All-Insert-All)
- 대용량 데이터에 부적합 (단, 이 케이스는 최대 10개 이하로 문제 없음)

---

### 옵션 2: 콤마 구분 문자열

**구조**
```
member_surveys (테이블 1개)
├─ user_id (PK)
├─ major
├─ bootcamp_completed
├─ wanted_jobs: VARCHAR(500)  -- "백엔드 개발자,데이터 엔지니어"
├─ licenses: VARCHAR(500)     -- "정보처리기사,SQLD,AWS SAA"
├─ has_gov_card
└─ affordable_amount
```

**데이터 예시**

| user_id | wanted_jobs | licenses |
|---------|-------------|----------|
| 1 | 백엔드 개발자,데이터 엔지니어 | 정보처리기사,SQLD,AWS SAA |

**장점**
- 가장 단순한 구조
- 테이블 1개
- JOIN 없음

**단점**
- 개별 값 검색 어려움 (LIKE 검색만 가능)
- 구분자 포함 데이터 처리 주의 필요
- 정규화 위반

---

### 옵션 3: PostgreSQL ARRAY

**구조**
```
member_surveys (테이블 1개)
├─ user_id (PK)
├─ major
├─ bootcamp_completed
├─ wanted_jobs: TEXT[]  -- PostgreSQL 배열
├─ licenses: TEXT[]     -- PostgreSQL 배열
├─ has_gov_card
└─ affordable_amount
```

**데이터 예시**

| user_id | wanted_jobs | licenses |
|---------|-------------|----------|
| 1 | {백엔드 개발자,데이터 엔지니어} | {정보처리기사,SQLD,AWS SAA} |

```sql
-- 검색 예시
SELECT * FROM member_surveys WHERE '정보처리기사' = ANY(licenses);
```

**장점**
- 테이블 1개
- PostgreSQL 네이티브 배열 연산자 사용 가능
- 성능 좋음

**단점**
- PostgreSQL 전용 (다른 DB 이식 불가)
- Hibernate 설정 추가 필요

---

### 옵션 4: JSONB

**구조**
```
member_surveys (테이블 1개)
├─ user_id (PK)
├─ major
├─ bootcamp_completed
├─ wanted_jobs: JSONB  -- ["백엔드 개발자", "데이터 엔지니어"]
├─ licenses: JSONB     -- ["정보처리기사", "SQLD", "AWS SAA"]
├─ has_gov_card
└─ affordable_amount
```

**데이터 예시**

| user_id | wanted_jobs | licenses |
|---------|-------------|----------|
| 1 | ["백엔드 개발자","데이터 엔지니어"] | ["정보처리기사","SQLD","AWS SAA"] |

```sql
-- 검색 예시
SELECT * FROM member_surveys WHERE licenses ? '정보처리기사';
```

**장점**
- 테이블 1개
- 유연한 구조
- GIN 인덱스로 검색 성능 확보 가능

**단점**
- Hibernate-types 라이브러리 추가 필요
- 약간의 설정 복잡도

---

## 🤔 고려 사항

### 1. 데이터 크기
- 희망직무: 최대 5개 이하 예상
- 자격증: 최대 10개 이하 예상
- → @ElementCollection의 "전체 삭제/재삽입" 오버헤드 무시 가능

### 2. 검색/필터링 필요성
- 현재: LLM 추천용 전체 조회가 주 목적
- 향후: "정보처리기사 보유자 검색" 같은 기능 가능성?

### 3. DB 이식성
- 현재: PostgreSQL 사용 중
- 향후: 다른 DB로 변경 가능성?

---

## ✅ 회의 결정 필요 사항

### 질문 1: 복수 선택 저장 방식
- [ ] 옵션 1: @ElementCollection (테이블 3개, JPA 표준)
- [ ] 옵션 2: 콤마 구분 문자열 (테이블 1개, 가장 단순)
- [ ] 옵션 3: PostgreSQL ARRAY (테이블 1개, DB 종속)
- [ ] 옵션 4: JSONB (테이블 1개, 유연함)

### 질문 2: 향후 검색/필터링 요구사항
- [ ] 개별 값 검색 필요 (예: "SQLD 보유자 목록")
- [ ] 전체 조회만 필요 (LLM 추천용)

---

## 💡 사전 검토 의견

**@ElementCollection 추천 이유:**
1. JPA 표준으로 DB 이식성 좋음
2. 복수 값 개수가 적어서 성능 문제 없음
3. 설문조사 특성상 "전체 저장" 패턴과 맞음
4. 필요 시 개별 값 검색 가능

---

## 참고: Entity 미리보기 (옵션 1 선택 시)

```java
@Entity
@Table(name = "member_surveys")
public class MemberSurveyEntity extends BaseEntity {
    
    @Id
    @Column(name = "user_id")
    private Long userId;
    
    private String major;
    
    @Column(nullable = false)
    private Boolean bootcampCompleted;
    
    @ElementCollection
    @CollectionTable(
        name = "member_survey_wanted_jobs", 
        joinColumns = @JoinColumn(name = "user_id")
    )
    @Column(name = "wanted_job")
    private List<String> wantedJobs = new ArrayList<>();
    
    @ElementCollection
    @CollectionTable(
        name = "member_survey_licenses",
        joinColumns = @JoinColumn(name = "user_id")
    )
    @Column(name = "license")
    private List<String> licenses = new ArrayList<>();
    
    @Column(nullable = false)
    private Boolean hasGovCard;
    
    private BigDecimal affordableAmount;
}
```
