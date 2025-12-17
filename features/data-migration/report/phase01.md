# Phase 01: 환경 구성 및 마스터 데이터 구축 - 구현 보고서

> ⚠️ 이 파일은 자동 생성된 **초안**입니다. 검토 후 수정하세요.
> 
> 생성일: 2025-12-16 19:58
> 소요 시간: 2시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| **디렉토리 구조 생성** | ✅ | `scripts/data-migration/{src,data,output}` |
| **CSV 파일 배치** | ⏳ | 사용자 수행 필요 (데이터 보안) |
| **의존성 관리** | ✅ | `requirements.txt` 작성 |
| **CSV Loader 구현** | ✅ | `utils.py` : `load_csv` |
| **Data Cleaner 구현** | ✅ | `utils.py` : `clean_str`, `clean_int` |
| **SQL Writer 구현** | ✅ | `sql_gen.py` : `write_sql`, `generate_insert_sql` |
| **에러 처리 및 로깅** | ✅ | 예외 처리 및 진행 상황 출력 추가 |
| **Step 0: Admin User 처리** | ✅ | `convert.py` : `process_admin_user` |
| **Step 1: Categories 처리** | ✅ | `convert.py` : `process_categories` |
| **Step 2: Organizations 처리** | ✅ | `convert.py` : `process_organizations` |
| **Step 3: Teachers 처리** | ✅ | `convert.py` : `process_teachers` |
| **Step 4: Curriculums 처리** | ✅ | `convert.py` : `process_curriculums` |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `scripts/data-migration/src/convert.py` | 생성 | 마이그레이션 메인 로직 (Step 0~4) |
| `scripts/data-migration/src/sql_gen.py` | 생성 | SQL 생성 및 파일 쓰기 유틸리티 |
| `scripts/data-migration/src/utils.py` | 생성 | CSV 로드 및 데이터 정제 유틸리티 |
| `scripts/data-migration/requirements.txt` | 생성 | Python 의존성 목록 (pandas) |

---

## 3. Tech Spec 대비 변경 사항

- **마이그레이션 단계**: Admin -> Category -> Org -> Teacher -> Curriculum 순서 준수.
- **SQL 생성 방식**: `INSERT IGNORE` 대신 PostgreSQL 호환 `ON CONFLICT DO NOTHING` 적용.
- **시퀀스 동기화**: 각 테이블 데이터 삽입 후 `setval`로 시퀀스 리셋 로직 구현.

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| **Admin 비밀번호** | 하드코딩/더미값 | 환경변수 `MIGRATION_ADMIN_PASSWORD` 지원 | 보안 강화 및 운영 환경 대응 유연성 확보 |
| **SQL 날짜 처리** | 문자열 리터럴 | `NOW()` 함수 직접 사용 | SQL 실행 시점의 정확한 시간 반영 |
| **플랫폼 호환성** | `os.popen('date')` | `datetime` 모듈 사용 | Windows/Linux 등 OS 간 호환성 확보 |

---

## 4. 검증 결과

### 4.1 코드 리뷰 검증 (Static Analysis)

- **검토자**: 10년차 시니어 개발자 페르소나 (AI)
- **결과**: Critical 2건, Major 1건, Minor 2건 발견 및 **전수 수정 완료**.
- **주요 수정**:
    - `convert.py`: `pandas` import 누락 수정.
    - `sql_gen.py`: `NOW()` 리터럴 처리 로직 개선.
    - `utils.py`: 불필요한 `numpy` 의존성 제거.

### 4.2 실행 검증 (Runtime)

- **상태**: ⏳ 대기 중 (데이터 파일 배치 필요)
- **예정 절차**:
    1. `data/` 폴더에 원본 CSV 배치.
    2. `python src/convert.py` 실행.
    3. `output/*.sql` 파일 생성 확인.

### 4.3 서브 모델 검증 (Critical인 경우)

| # | 심각도 | 이슈 | 해결 |
|---|--------|------|------|
| - | - | 해당 사항 없음 | - |

---

## 5. 발생한 이슈

### 이슈 1: SQL 날짜 함수 리터럴 처리 문제

- **증상**: `NOW()`가 SQL 파일에 `'NOW()'` 문자열로 기록되어, DB 입력 시 날짜 형식이 아닌 문자열로 인식될 위험.
- **원인**: `generate_insert_sql` 함수에서 모든 문자열을 일괄적으로 싱글 쿼트로 감싸도록 구현됨.
- **해결**: 값 자체가 `'NOW()'`인 경우 예외적으로 쿼트를 씌우지 않고 그대로 SQL 함수로 출력되도록 분기 처리 추가.

### 이슈 2: 플랫폼 종속적인 날짜 명령어 사용

- **증상**: `os.popen('date')` 사용 시 Windows 환경 등에서 날짜 포맷이 다르거나 명령어가 없을 수 있음.
- **원인**: 쉘 명령어에 의존하여 현재 시간을 가져옴.
- **해결**: Python 내장 `datetime` 모듈을 사용하여 플랫폼 독립적으로 현재 시간을 포맷팅하도록 수정.

---

## 6. 다음 Phase 준비 사항

- [ ] **데이터 파일 준비**: `scripts/data-migration/data/` 디렉토리에 원본 CSV 파일 업로드.
- [ ] **환경 설정**: `pip install -r requirements.txt` 로 의존성 설치.
- [ ] **스크립트 실행**: `python src/convert.py` 실행하여 SQL 파일 생성.
- [ ] **결과 검증**: 생성된 SQL 파일을 DB에 적용하여 데이터 무결성 확인 (Phase 02).

---

## 7. 참고 사항

- 데이터 파일은 보안상 저장소에 포함되지 않으므로, 로컬 실행 시 별도 준비가 필요합니다.

---

## 📊 진행률 (Plan README 업데이트용)

```
Phase 01 ▓▓▓▓▓▓▓▓▓░ 92% 🔄
```

완료: 11/12 tasks (CSV 파일 배치 대기 중)
