# 초기 데이터 마이그레이션 Spec

## 개요

CSV 원본 데이터를 정규화하여 Flyway SQL로 변환하는 마이그레이션 기술 명세입니다.

---

## 데이터 흐름

```
Raw CSV Files → Python Script → Flyway SQL Files → PostgreSQL
```

**기술 스택**: Python 3.x, Pandas, Flyway (Spring Boot 내장)

---

## 처리 로직

### Step 0: Admin User 생성

```sql
INSERT INTO swcampus.members (user_id, email, name, role, ...)
VALUES (1, 'admin@swcampus.com', 'Admin', 'ADMIN', ...)
ON CONFLICT DO NOTHING;
```

### Step 1: 전처리

| 처리 | 설명 |
|------|------|
| Encoding | utf-8 또는 cp949 자동 감지 |
| 공백 제거 | 모든 문자열 strip() |
| 금액 변환 | `,` 제거 → int |
| 날짜 변환 | YYYYMMDD → YYYY-MM-DD |

### Step 2: 마스터 데이터 추출

| 테이블 | 소스 | 설명 |
|--------|------|------|
| categories | 통합데이터.csv `대분류` | 고유 카테고리 추출 |
| organizations | 과정정보.csv `교육기관명` | 고유 기관 추출 |
| teachers | 과정정보.csv `강사명` | 고유 강사 추출 ('미상' 등 제외) |
| curriculums | 카테고리별 CSV 헤더 | 커리큘럼 항목 추출 |

### Step 3: 강좌 데이터 (lectures)

| DB 컬럼 | CSV 소스 | 변환 |
|---------|----------|------|
| lecture_name | 과정명 | - |
| org_id | 교육기관명 | organizations Lookup |
| start_date/end_date | 교육시작일자/종료일자 | Date 변환 |
| lecture_fee | 수강료 합계 | 숫자 변환 |
| lecture_loc | 온라인/오프라인 | ONLINE/OFFLINE/MIXED |
| equip_pc | 장비 | PC/PERSONAL/NONE |

### Step 4: 관계 데이터

| 테이블 | 설명 |
|--------|------|
| lecture_curriculums | lecture_id, curriculum_id, level (BASIC/ADVANCED/NONE) |
| lecture_steps | 전형 단계 (DOCUMENT, INTERVIEW, CODING_TEST, PRE_TASK) |
| lecture_quals | 지원 자격 (REQUIRED/PREFERRED) |
| lecture_teachers | 강사 매핑 |
| lecture_adds | 추가 혜택 |

---

## 파일 구조

```
sw-campus-server/scripts/data-migration/
├── convert.py              # 메인 변환 스크립트
├── requirements.txt        # pandas 등
├── data/                   # 원본 CSV
└── output/                 # 생성된 SQL
```

---

## SQL 생성 규칙

- Idempotency: `INSERT ... ON CONFLICT DO NOTHING`
- Sequence Reset: `SELECT setval(...)` 추가

---

## 구현 노트

### 2025-12-XX - 초기 구현

- Python 스크립트로 CSV → SQL 변환
- Flyway 마이그레이션으로 적용
- 271개 기관, 약 300개 강좌 데이터 적재
