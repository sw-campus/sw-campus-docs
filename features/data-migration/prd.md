# Product Requirements Document: 초기 데이터 구축 및 마이그레이션

## 1. 개요 (Overview)

### 1.1 배경 및 목적
본 프로젝트(sw-campus-server)는 SW 교육 과정을 중개하고 관리하는 플랫폼입니다. 서비스 런칭 시점에 사용자에게 유의미한 정보를 제공하기 위해, 사전에 수집된 약 1,400건의 교육 과정 데이터(CSV)를 데이터베이스에 적재해야 합니다.

이 데이터는 카테고리, 커리큘럼, 교육기관, 강사, 강좌 정보 등 서비스의 근간이 되는 기초 데이터입니다. 운영 환경에서의 안정성과 데이터 무결성을 보장하기 위해, 수동 입력이나 런타임 로딩 방식 대신 **검증된 SQL 스크립트를 통한 마이그레이션** 방식을 채택합니다.

### 1.2 목표 (Goals)
1.  **데이터 정합성 확보**: 원본 CSV 데이터의 오류(날짜 형식, 중복, 외래키 누락 등)를 사전에 식별하고 정제합니다.
2.  **배포 안정성**: Flyway를 통해 개발, 스테이징, 운영 환경에 동일한 데이터가 안전하게 배포되도록 합니다.
3.  **유지보수성**: 데이터 변환 로직을 스크립트(Python)로 관리하여, 향후 데이터 업데이트 시 재사용 가능하게 합니다.

---

## 2. 사용자 스토리 (User Stories)

| 페르소나 | 행위 | 목적 |
|:---:|---|---|
| **백엔드 개발자** | CSV 데이터를 변환 스크립트를 통해 SQL 파일로 생성한다. | 복잡한 관계형 데이터를 실수 없이 DB에 적재하기 위함이다. |
| **DevOps 엔지니어** | 서버 배포 시 Flyway가 자동으로 초기 데이터를 적재한다. | 별도의 수동 작업 없이 배포 프로세스를 자동화하기 위함이다. |
| **서비스 관리자** | 서비스 오픈 즉시 1,400여 개의 강좌 정보를 확인한다. | 사용자에게 풍부한 콘텐츠를 제공하기 위함이다. |

---

## 3. 기능 요구사항 (Functional Requirements)

### 3.1 데이터 소스 (Input)
- **형식**: CSV 파일
- **주요 파일**:
    - `소프트웨어캠퍼스과정정보.csv` (540건): 메인 강좌 정보, 기관, 강사, 일정, 비용 등
    - `통합데이터.csv` (422건): 커리큘럼 레벨(기본/심화) 매핑 정보
    - `*.csv` (카테고리별 파일): 카테고리 분류 참조용

- **파일 간 관계**:
    - `소프트웨어캠퍼스과정정보.csv`의 **"과정명"** = `통합데이터.csv`의 **"훈련과정명"**
    - `통합데이터.csv`는 각 과정별 커리큘럼 항목의 레벨(기본/심화/없음) 점수를 저장
    - 이 조인 관계를 통해 `lecture_curriculums` 테이블 데이터를 생성함

### 3.2 데이터 변환 및 정제 (Processing)
- **도구**: Python (Pandas 라이브러리 활용)
- **주요 로직**:
    1.  **마스터 데이터 추출**: 중복된 텍스트(기관명, 강사명, 카테고리 등)를 추출하여 고유 ID를 부여하고 정규화합니다.
    2.  **데이터 매핑**:
        - `카테고리` → `categories`
        - `커리큘럼` → `curriculums`
        - `교육기관` → `organizations`
        - `강사` → `teachers`
        - `강좌` → `lectures`
    3.  **형식 변환**:
        - 날짜: `YYYYMMDD` 문자열 → `YYYY-MM-DD` Date 타입
        - 금액: 천 단위 콤마(`,`) 및 공백 제거 후 Numeric 타입 변환
        - ENUM 매핑: 한글 값(예: '기본', '심화') → 영문 ENUM(예: 'BASIC', 'ADVANCED') 변환
    4.  **관계 설정**: 생성된 ID를 기반으로 외래키(FK) 관계를 연결합니다.

### 3.3 결과물 생성 (Output)
- **형식**: Flyway SQL Migration 파일 (`.sql`)
- **위치**: `sw-campus-infra/db-postgres/src/main/resources/db/migration/`
- **파일 구성 (예시)**:
    - `V2__seed_categories.sql`
    - `V3__seed_curriculums.sql`
    - `V4__seed_organizations.sql`
    - `V5__seed_teachers.sql`
    - `V6__seed_lectures.sql`
    - `V7__seed_relations.sql`

---

## 4. 비기능 요구사항 (Non-Functional Requirements)

### 4.1 데이터 무결성
- **참조 무결성**: 부모 테이블(카테고리, 기관 등)의 데이터가 먼저 적재되어야 합니다.
- **중복 방지**: `ON CONFLICT DO NOTHING` 구문을 사용하여 스크립트 재실행 시에도 중복 에러가 발생하지 않아야 합니다 (멱등성).
- **시퀀스 동기화**: 데이터 적재 후 각 테이블의 Primary Key Sequence(`_seq`) 값을 최대 ID 값으로 업데이트해야 합니다.

### 4.2 성능
- 대량 Insert 시 성능 저하를 방지하기 위해, 적절한 크기의 배치(Batch) 또는 단일 트랜잭션으로 처리합니다. (현재 1,400건 수준이므로 단일 파일 실행 문제없음)

---

## 5. 데이터 스키마 매핑 (Schema Mapping)

### 5.1 주요 테이블 매핑

| CSV 컬럼 | DB 테이블 | DB 컬럼 | 비고 |
|---|---|---|---|
| 대분류 | `categories` | `category_name` | 고유값 추출 |
| 훈련과정명 | `lectures` | `lecture_name` | |
| 교육기관명 | `organizations` | `org_name` | 고유값 추출 |
| 강사명 | `teachers` | `teacher_name` | 고유값 추출 |
| 교육시작일자 | `lectures` | `start_date` | 날짜 변환 필요 |
| 수강료 합계 | `lectures` | `lecture_fee` | 숫자 변환 필요 |
| 온라인/오프라인 | `lectures` | `lecture_loc` | ENUM (ONLINE/OFFLINE/MIXED) |
| 내일배움카드 | `lectures` | `recruit_type` | ENUM (CARD_REQUIRED/GENERAL) |
| 교재지원/장비 | `lectures` | `books`, `equip_pc` | Boolean/ENUM 변환 |
| 선발절차 | `lecture_steps` | `step_type` | 서류, 면접 등 분리 저장 |
| 지원자격 | `lecture_quals` | `type`, `text` | 필수/우대 구분 저장 |
| 커리큘럼 레벨 | `lecture_curriculums` | `level` | ENUM 변환 필요 |

---

## 6. 제약 사항 및 가정 (Constraints & Assumptions)
- 제공된 CSV 파일의 컬럼 순서나 명칭이 변경되지 않는다고 가정합니다.
- 초기 데이터 적재는 서비스 최초 배포 시 1회 수행되는 것을 원칙으로 합니다.

### 6.1 예외 처리 기준
| 필드 | 누락/오류 시 처리 |
|---|---|
| `과정명`, `시작일` | ❌ 해당 행(Row) 적재 제외 (로그 기록) |
| `강사명` ("미상") | ✅ `NULL` 또는 "정보 없음" 강사로 매핑 |
| `수강료` | ✅ `0`으로 처리 |
| `정원` | ✅ `NULL` 처리 |

---

## 7. 완료 조건 (Done Criteria)
- [ ] 모든 SQL 파일이 로컬 DB에서 에러 없이 실행됨
- [ ] 적재된 데이터 건수가 예상값과 일치함 (예: lectures 약 540건)
- [ ] FK 무결성 검증 쿼리 통과 (고아 데이터 없음)
- [ ] 시퀀스 값이 각 테이블의 최대 ID와 동기화됨

## 8. 롤백 계획 (Rollback Plan)
- **개발 환경**: `flyway clean` 후 `flyway migrate` 재실행
- **운영 환경**:
    - 배포 전: 트랜잭션 롤백
    - 배포 후: 수동 DELETE 스크립트 실행 (Cascade Delete 주의)
