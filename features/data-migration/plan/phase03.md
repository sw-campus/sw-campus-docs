# Phase 03: 검증 및 최종화

## 전제 조건
- ✅ Phase 01 완료 (마스터 데이터 SQL 생성됨)
- ✅ Phase 02 완료 (강좌 및 관계 데이터 SQL 생성됨)
- ✅ 모든 SQL 파일이 `output/` 디렉토리에 존재 (V2 ~ V12)

## 목표
- 생성된 SQL 파일을 로컬 데이터베이스에 적용하여 동작을 검증한다.
- 데이터 정합성을 확인하고 스크립트를 보완한다.
- 최종 결과물을 PR로 제출한다.

## 태스크 목록

### 1. 로컬 마이그레이션 테스트
- [x] **SQL 파일 배치**
    - 생성된 `output/*.sql` 파일을 `sw-campus-infra/db-postgres/src/main/resources/db/migration/` 경로로 복사
    - 파일 순서 확인 (V2 → V3 → ... → V12)
- [x] **DB 초기화 및 기동**
    ```bash
    cd sw-campus-server
    docker-compose down -v    # 볼륨 포함 초기화
    docker-compose up -d db   # PostgreSQL 컨테이너 기동
    ```
- [x] **마이그레이션 실행**
    - Spring Boot 앱 기동 시 Flyway 자동 실행
    ```bash
    ./gradlew :sw-campus-api:bootRun
    ```
    - 에러 발생 시: 로그 확인 → 스크립트 수정 → SQL 재생성 → 재시도

### 2. 데이터 정합성 검증
- [x] **Row Count 확인**
    - CSV 원본 Row 수와 DB 테이블 Row 수 비교
    - 검증 쿼리 예시:
    ```sql
    -- 테이블별 Row Count
    SELECT 'lectures' as tbl, COUNT(*) FROM swcampus.lectures
    UNION ALL SELECT 'organizations', COUNT(*) FROM swcampus.organizations
    UNION ALL SELECT 'categories', COUNT(*) FROM swcampus.categories
    UNION ALL SELECT 'teachers', COUNT(*) FROM swcampus.teachers
    UNION ALL SELECT 'curriculums', COUNT(*) FROM swcampus.curriculums
    UNION ALL SELECT 'lecture_steps', COUNT(*) FROM swcampus.lecture_steps
    UNION ALL SELECT 'lecture_quals', COUNT(*) FROM swcampus.lecture_quals
    UNION ALL SELECT 'lecture_adds', COUNT(*) FROM swcampus.lecture_adds
    UNION ALL SELECT 'lecture_teachers', COUNT(*) FROM swcampus.lecture_teachers
    UNION ALL SELECT 'lecture_curriculums', COUNT(*) FROM swcampus.lecture_curriculums;
    ```
- [x] **샘플 데이터 확인**
    - 무작위 5개 강좌 선정하여 상세 필드 값 검증
    ```sql
    -- 샘플 강좌 조회
    SELECT lecture_id, lecture_name, org_id, lecture_loc, recruit_type, equip_pc, start_date, end_date
    FROM swcampus.lectures
    ORDER BY RANDOM() LIMIT 5;
    
    -- 특정 강좌의 1:N 데이터 확인
    SELECT * FROM swcampus.lecture_adds WHERE lecture_id = 1;
    SELECT * FROM swcampus.lecture_quals WHERE lecture_id = 1;
    ```
    - Enum, Boolean, Date 변환 정확성 확인
- [x] **Sequence 동기화 확인**
    ```sql
    -- Sequence 현재값과 테이블 MAX ID 비교
    SELECT 'lectures' as tbl, 
           (SELECT last_value FROM swcampus.lectures_lecture_id_seq) as seq_val,
           (SELECT COALESCE(MAX(lecture_id), 0) FROM swcampus.lectures) as max_id;
    ```
    - 추가 Insert 시 PK 충돌이 없는지 테스트

### 3. 롤백 계획 (실패 시)
- [x] **마이그레이션 실패 시 대응**
    - Flyway `flyway_schema_history` 테이블에서 실패한 버전 확인
    - 해당 SQL 파일 수정 후 `flyway repair` 또는 DB 초기화 후 재시도
    ```bash
    # DB 완전 초기화 (개발 환경에서만)
    docker-compose down -v
    docker-compose up -d db
    ```
- [x] **부분 롤백 불가**
    - Flyway는 기본적으로 롤백을 지원하지 않음
    - 실패 시 DB 초기화 후 수정된 SQL로 재실행

### 4. 문서화 및 PR
- [x] **Report 작성**
    - `features/data-migration/report.md` 작성
    - 포함 내용:
        - 변환 결과 요약 (테이블별 Row 수)
        - 특이사항 및 해결 내역
        - Skip된 데이터 목록 및 사유
- [x] **PR 생성**
    - 포함 파일:
        - `scripts/data-migration/` (Python 스크립트 전체)
        - `sw-campus-infra/.../db/migration/V2~V12*.sql`
        - `sw-campus-docs/features/data-migration/report.md`
    - PR 설명에 검증 결과 스크린샷 첨부

## 완료 기준 (Definition of Done)
- [x] 모든 SQL 파일이 에러 없이 실행됨
- [x] CSV 원본 대비 데이터 손실률 5% 미만
- [x] Sequence가 올바르게 동기화되어 추가 Insert 가능
- [x] Report 문서 작성 완료
- [x] PR 생성 및 리뷰 요청 완료

## 산출물
- `sw-campus-docs/features/data-migration/report.md`
- GitHub PR Link
