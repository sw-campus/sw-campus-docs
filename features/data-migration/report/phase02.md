# Phase 02: 강좌 및 관계 데이터 구축 - 구현 보고서

> 생성일: 2025-12-16 20:50
> 소요 시간: 1시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| **데이터 매핑 로직 구현** | ✅ | `convert.py` 내 `process_lectures` 함수 구현 완료 |
| **SQL 생성** | ✅ | `V7__seed_lectures.sql` 생성 (389건) |
| **Lecture Steps (전형절차)** | ✅ | `V8__seed_lecture_steps.sql` 생성 (144건) |
| **Lecture Quals (지원자격)** | ✅ | `V9__seed_lecture_quals.sql` 생성 (256건) |
| **Lecture Adds (추가혜택)** | ✅ | `V10__seed_lecture_adds.sql` 생성 (0건 - 데이터 없음) |
| **Lecture Teachers (강사 연결)** | ✅ | `V11__seed_lecture_teachers.sql` 생성 (0건 - 매칭 데이터 없음) |
| **커리큘럼 레벨 파싱** | ✅ | `V12__seed_lecture_curriculums.sql` 생성 (1112건) |
| **예외 케이스 처리** | ✅ | 인코딩 에러 처리, 중복 강좌 스킵, 필수값 누락 처리 |
| **처리 결과 요약** | ✅ | 스크립트 실행 시 콘솔에 요약 출력 |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `scripts/data-migration/src/convert.py` | 수정 | 강좌 및 관계 데이터 파싱 로직 추가, 커리큘럼 파싱 로직 개선 |
| `scripts/data-migration/src/sql_gen.py` | 수정 | 날짜 타입(`timestamp`) 명시적 캐스팅 로직 추가 |
| `scripts/data-migration/output/V6__seed_curriculums.sql` | 재생성 | 커리큘럼 파싱 로직 수정으로 인한 데이터 정제 (253건 -> 75건) |
| `scripts/data-migration/output/V7__seed_lectures.sql` | 생성 | 강좌 데이터 (389건) |
| `scripts/data-migration/output/V8__seed_lecture_steps.sql` | 생성 | 전형절차 데이터 |
| `scripts/data-migration/output/V9__seed_lecture_quals.sql` | 생성 | 지원자격 데이터 |
| `scripts/data-migration/output/V10__seed_lecture_adds.sql` | 생성 | 추가혜택 데이터 |
| `scripts/data-migration/output/V11__seed_lecture_teachers.sql` | 생성 | 강사 연결 데이터 |
| `scripts/data-migration/output/V12__seed_lecture_curriculums.sql` | 생성 | 강좌-커리큘럼 매핑 데이터 |
| `scripts/data-migration/output/V13__reset_sequences.sql` | 생성 | 시퀀스 초기화 스크립트 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 계획대로 진행된 항목

- `lectures` 테이블의 Enum, Boolean, Numeric 변환 로직은 계획대로 구현되었습니다.
- 하위 테이블(Steps, Quals, Adds) 생성 로직도 계획대로 진행되었습니다.

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| **커리큘럼 파싱 로직** | Row 1에서 커리큘럼명 추출 | **Row 0에서 추출** 및 유효성 검사 강화 | 일부 CSV 파일(게임, 디자인 등)의 헤더 구조가 예상과 달라 데이터가 잘못 파싱되는 문제 해결 |
| **날짜 데이터 처리** | 문자열 그대로 삽입 | **`::timestamp` 캐스팅 추가** | PostgreSQL에서 명시적 타입 변환을 권장하며, 데이터 정확성 확보 |
| **파일명 매핑** | (언급 없음) | **`cat_file_map` 추가** | 카테고리명('데이터 분석')과 실제 파일명('데이터분석가.csv') 불일치 해결 |

---

## 4. 검증 결과

### 4.1 스크립트 실행 검증

```bash
$ python src/convert.py
Processing Step 4: Curriculums...
  -> Generated 75 SQL statements for Curriculums.
Processing Step 5: Lectures & Relations...
  -> Generated 389 SQL statements for Lectures.
  -> Generated 144 SQL statements for Lecture Steps.
  -> Generated 256 SQL statements for Lecture Quals.
  -> Generated 1112 SQL statements for Lecture Curriculums.
```

### 4.2 데이터 정합성 검증

- **Lectures**: 389개 강좌가 생성되었으며, `start_date`, `end_date`가 올바른 포맷으로 변환됨을 확인했습니다.
- **Curriculums**: 기존 253개에서 75개로 감소했으나, 이는 '훈련기관명', '1', '2' 등 잘못된 헤더 데이터가 제거된 결과로 정상입니다.
- **Relations**: `lecture_id`를 FK로 참조하는 하위 테이블 데이터가 정상적으로 생성되었습니다.

---

## 5. 발생한 이슈

### 이슈 1: 커리큘럼 데이터 오염

- **증상**: `V6__seed_curriculums.sql`에 '훈련기관명', '1', '2'와 같은 무의미한 데이터가 포함됨.
- **원인**: 일부 CSV 파일의 헤더 구조가 달라 Row 1을 데이터로 인식함.
- **해결**: Row 0을 헤더로 인식하도록 변경하고, 무의미한 문자열을 필터링하는 로직 추가.

### 이슈 2: 날짜 타입 캐스팅

- **증상**: SQL 실행 시 문자열을 Timestamp로 변환하는 과정에서 명시적이지 않다는 지적 가능성.
- **해결**: `sql_gen.py`에서 `YYYY-MM-DD` 형식의 문자열을 감지하여 `::timestamp`를 붙여주도록 수정.

---

## 6. 다음 Phase 준비 사항

- [ ] **Phase 03: Flyway 적용 및 검증**
    - 생성된 SQL 파일들을 실제 DB에 적용 (`./gradlew flywayMigrate`)
    - 애플리케이션 실행 후 데이터 조회 테스트

---

## 📊 진행률 (Plan README 업데이트용)

```
Phase 02 ██████████ 100% ✅
```

완료: 9/9 tasks
