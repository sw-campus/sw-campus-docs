# Phase 01: 환경 구성 및 마스터 데이터 구축

## 목표
- Python 마이그레이션 스크립트 실행 환경을 구축한다.
- CSV 파일을 로드하여 전처리하는 공통 유틸리티를 구현한다.
- 마스터 데이터(`Admin User`, `Categories`, `Organizations`, `Teachers`, `Curriculums`)의 Insert SQL을 생성한다.

## 필요 데이터 (CSV 파일 목록)
| 파일명 | 용도 |
|--------|------|
| `소프트웨어캠퍼스과정정보.csv` | 메인 강좌 데이터 (기관명, 강사명, 과정 상세) |
| `통합데이터.csv` | 커리큘럼 매핑 정보 (대분류, 훈련과정명, 커리큘럼 레벨) |
| `AI.csv`, `웹개발(백엔드).csv` 등 | 카테고리별 커리큘럼 항목 헤더 |

## 생성 순서 (의존성)
FK 제약조건을 만족하기 위해 아래 순서대로 데이터를 생성해야 합니다.

```
1. Admin User (members)     → Organizations의 user_id FK
2. Categories               → Curriculums의 category_id FK
3. Organizations            → Lectures의 org_id FK (Phase 02)
4. Teachers                 → Lecture_Teachers의 teacher_id FK (Phase 02)
5. Curriculums              → Lecture_Curriculums의 curriculum_id FK (Phase 02)
```

## 태스크 목록

### 1. 작업 환경 구성
- [ ] **디렉토리 구조 생성**
    - `sw-campus-server/scripts/data-migration/` 폴더 생성
    - 하위 폴더 구조:
      ```
      scripts/data-migration/
      ├── data/           # CSV 원본 파일
      ├── output/         # 생성된 SQL 파일
      └── src/            # Python 소스코드
          ├── utils.py    # 공통 유틸리티
          ├── sql_gen.py  # SQL 생성기
          └── convert.py  # 메인 변환 스크립트
      ```
- [ ] **CSV 파일 배치**
    - `소프트웨어캠퍼스과정정보.csv` → `data/`
    - `통합데이터.csv` → `data/`
    - 카테고리별 CSV 파일들 → `data/categories/`
- [ ] **의존성 관리**
    - `requirements.txt` 작성 (`pandas`, `numpy`)
    - Python 가상환경 생성 및 패키지 설치

### 2. 공통 유틸리티 구현 (`src/utils.py`)
- [ ] **CSV Loader 구현**
    - `load_csv(path)`: 파일 경로를 받아 Pandas DataFrame 반환
    - 인코딩 자동 감지 (`utf-8` 우선 시도 후 `cp949` fallback)
- [ ] **Data Cleaner 구현**
    - `clean_str(text)`: 앞뒤 공백 제거, `NaN` -> 빈 문자열 처리
    - `clean_int(text)`: 콤마(`,`) 제거 후 정수 변환, 실패 시 기본값 처리
    - `parse_date(text)`: `YYYYMMDD` 문자열을 `YYYY-MM-DD` 포맷으로 변환

### 3. SQL 생성기 구현 (`src/sql_gen.py`)
- [ ] **SQL Writer 구현**
    - `write_sql(filename, sql_list)`: SQL 문장 리스트를 파일로 저장
    - Idempotency 보장: `INSERT INTO ... ON CONFLICT DO NOTHING`
    - Sequence 동기화: 각 테이블 Insert 후 `SELECT setval(...)` 추가
- [ ] **에러 처리 및 로깅**
    - 파싱 실패/누락 데이터 발생 시 Skip 후 Warning 로그 출력
    - 처리 결과 요약 출력 (성공/실패 건수)

### 4. 마스터 데이터 처리 로직 구현 (`src/convert.py`)

> ⚠️ **중요**: 아래 순서대로 처리해야 FK 제약조건을 만족합니다.

- [ ] **Step 0: Admin User 처리**
    - `members` 테이블에 ID 1번 관리자 계정 생성
    - `ON CONFLICT DO NOTHING` (이미 존재 시 Skip)
    - → `V2__seed_admin_user.sql` 생성
- [ ] **Step 1: Categories 처리**
    - `통합데이터.csv` 로드 및 `대분류` 컬럼 추출
    - 카테고리별 CSV 파일명 스캔하여 추가 카테고리 확보
    - 중복 제거 후 ID 부여 (1부터 순차)
    - → `V3__seed_categories.sql` 생성
- [ ] **Step 2: Organizations 처리**
    - `소프트웨어캠퍼스과정정보.csv` 로드
    - `교육기관명` 중복 제거 및 ID 부여
    - `user_id=1` (Admin) 매핑
    - → `V4__seed_organizations.sql` 생성
- [ ] **Step 3: Teachers 처리**
    - `강사명` 컬럼 추출 및 중복 제거
    - **필터링**: '미상', '강사', 빈 값 등 무효 데이터 제외 (Skip + 로그)
    - → `V5__seed_teachers.sql` 생성
- [ ] **Step 4: Curriculums 처리**
    - 각 카테고리별 CSV 파일의 헤더(2번째 행) 파싱
    - `category_id` 룩업하여 매핑
    - → `V6__seed_curriculums.sql` 생성

## 산출물

### 스크립트
- `scripts/data-migration/requirements.txt`
- `scripts/data-migration/src/utils.py`
- `scripts/data-migration/src/sql_gen.py`
- `scripts/data-migration/src/convert.py`

### SQL 파일 (Flyway Migration)
| 파일명 | 대상 테이블 | 의존성 |
|--------|------------|--------|
| `V2__seed_admin_user.sql` | `members` | 없음 |
| `V3__seed_categories.sql` | `categories` | 없음 |
| `V4__seed_organizations.sql` | `organizations` | `members` (user_id) |
| `V5__seed_teachers.sql` | `teachers` | 없음 |
| `V6__seed_curriculums.sql` | `curriculums` | `categories` (category_id) |
