# Phase 02: 강좌 및 관계 데이터 구축

## 전제 조건
- ✅ Phase 01 완료 (Admin User, Categories, Organizations, Teachers, Curriculums SQL 생성됨)
- ✅ Phase 01 산출물이 `output/` 디렉토리에 존재

## 목표
- 핵심 데이터인 강좌(`Lectures`) 정보를 생성한다.
- 강좌와 연결된 1:N 관계 데이터(`Steps`, `Quals`, `Adds`, `Teachers`)를 파싱하여 생성한다.
- `통합데이터.csv`와 조인하여 커리큘럼 매핑 정보를 생성한다.

## 생성 순서 (의존성)
FK 제약조건을 만족하기 위해 아래 순서대로 데이터를 생성해야 합니다.

```
1. Lectures              → 모든 하위 테이블의 lecture_id FK
2. Lecture Steps         → lectures.lecture_id 참조
3. Lecture Quals         → lectures.lecture_id 참조
4. Lecture Adds          → lectures.lecture_id 참조
5. Lecture Teachers      → lectures.lecture_id + teachers.teacher_id 참조
6. Lecture Curriculums   → lectures.lecture_id + curriculums.curriculum_id 참조
```

## 태스크 목록

### 1. Lectures (메인) 데이터 처리
- [ ] **데이터 매핑 로직 구현**
    - `organizations` ID 룩업 (기관명 기준, Phase 01에서 생성된 매핑 사용)
    - **Enum 변환**:
        - `lecture_loc`: 온라인/오프라인 → `ONLINE`, `OFFLINE`, `MIXED`
        - `recruit_type`: 유/무 → `CARD_REQUIRED`, `GENERAL`
        - `equip_pc`: pc/개인장비/없음 → `PC`, `PERSONAL`, `NONE`
    - **Boolean 변환**: 'O'/'X' → `true`/`false` (`books`, `employment_help` 등)
    - **Numeric 변환**: 금액 필드 콤마 제거
    - **Date 변환**: `YYYYMMDD` → `YYYY-MM-DD`
- [ ] **SQL 생성**
    - `lectures` 테이블 Insert SQL 생성 (`ON CONFLICT DO NOTHING`)
    - → `V7__seed_lectures.sql` 생성

### 2. 하위 테이블 (1:N) 처리
- [ ] **Lecture Steps (전형절차)**
    - 컬럼(`서류심사`, `면접`, `코딩테스트`, `사전학습과제`) 확인
    - 값이 'O'인 경우 해당 Step Type으로 Insert SQL 생성
    - `step_order` 자동 부여 (1부터 순차 증가)
    - → `V8__seed_lecture_steps.sql` 생성
- [ ] **Lecture Quals (지원자격)**
    - `필수`, `우대` 컬럼 파싱
    - 콤마(`,`)로 구분된 문자열을 분리(Split)하여 다중 Row 생성
    - `type` (`REQUIRED`, `PREFERRED`) 지정하여 Insert SQL 생성
    - → `V9__seed_lecture_quals.sql` 생성
- [ ] **Lecture Adds (추가혜택)**
    - `추가혜택` 컬럼 파싱
    - 콤마(`,`)로 구분된 문자열 분리
    - → `V10__seed_lecture_adds.sql` 생성
- [ ] **Lecture Teachers (강사 연결)**
    - `강사명` 컬럼 기준 `teachers` 테이블 ID 룩업
    - 매칭되는 강사가 있는 경우에만 Insert (없으면 Skip + 로그)
    - → `V11__seed_lecture_teachers.sql` 생성

### 3. 관계 데이터 Warning 로그 출력 (해당 강좌는 커리큘럼 없이 진행)
- [ ] **커리큘럼 레벨 파싱**
    - `통합데이터.csv`의 각 커리큘럼 컬럼 값 확인 ('기본', '심화', '없음')
    - 값이 '기본' 또는 '심화'인 경우만 Insert SQL 생성
    - `level` Enum 매핑 (`BASIC`, `ADVANCED`)
    - → `V12__seed_lecture_curriculums.sql` 생성

### 4. 에러 처리 및 로깅
- [ ] **예외 케이스 처리**
    - 필수값(`과정명`, `기관명`, `시작일`) 누락 시 해당 Row Skip
    - Enum 매핑 실패 시 기본값 사용 또는 Skip
    - 모든 Skip 건은 Warning 로그로 기록
- [ ] **처리 결과 요약**
    - 테이블별 Insert 성공/실패 건수 출력
    - 생성된 SQL 파일 목록 출력

## 산출물

### 스크립트
- `scripts/data-migration/src/convert.py` (완성 버전)

### SQL 파일 (Flyway Migration)
| 파일명 | 대상 테이블 | 의존성 |
|--------|------------|--------|
| `V7__seed_lectures.sql` | `lectures` | `organizations` (org_id) |
| `V8__seed_lecture_steps.sql` | `lecture_steps` | `lectures` (lecture_id) |
| `V9__seed_lecture_quals.sql` | `lecture_quals` | `lectures` (lecture_id) |
| `V10__seed_lecture_adds.sql` | `lecture_adds` | `lectures` (lecture_id) |
| `V11__seed_lecture_teachers.sql` | `lecture_teachers` | `lectures`, `teachers` |
| `V12__seed_lecture_curriculums.sql` | `lecture_curriculums` | `lectures`, `curriculums` |
