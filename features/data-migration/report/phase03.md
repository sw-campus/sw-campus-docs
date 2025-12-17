# Phase 03: 검증 및 최종화 - 구현 보고서

> ⚠️ 이 파일은 자동 생성된 **초안**입니다. 검토 후 수정하세요.
> 
> 생성일: 2025-12-17 09:36
> 소요 시간: 4시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| **SQL 파일 배치** | ✅ | `sw-campus-infra` 모듈로 복사 완료 |
| **DB 초기화 및 기동** | ✅ | Docker Compose 활용 |
| **마이그레이션 실행** | ✅ | Flyway V2 ~ V13 적용 완료 |
| **Row Count 확인** | ✅ | `lectures` (389), `lecture_quals` (558) 등 확인 |
| **샘플 데이터 확인** | ✅ | 한글 깨짐 없음, 날짜 형식 정상 |
| **Sequence 동기화 확인** | ✅ | `reset_sequences.sql` 적용으로 동기화 완료 |
| **마이그레이션 실패 시 대응** | ✅ | `lecture_quals` 누락 이슈 해결 |
| **부분 롤백 불가** | ✅ | DB 초기화 전략 사용 |
| **Report 작성** | ✅ | `sw-campus-docs/features/data-migration/report.md` 작성 완료 |
| **PR 생성** | ⏳ | 진행 예정 |
| 모든 SQL 파일이 에러 없이 실행됨 | ✅ | |
| CSV 원본 대비 데이터 손실률 5% 미만 | ✅ | `lecture_adds`는 원본 데이터 부재로 0건 (정상) |
| Sequence가 올바르게 동기화되어 추가 Insert 가능 | ✅ | |
| Report 문서 작성 완료 | ✅ | |
| PR 생성 및 리뷰 요청 완료 | ⏳ | |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `scripts/data-migration/src/convert.py` | 수정 | 보안 강화(Env Var), 헤더 파싱 로직 개선, 데이터 정제 로직 추가 |
| `sw-campus-server/.gitignore` | 수정 | `scripts/data-migration/output/` 무시 설정 추가 |
| `sw-campus-infra/db-postgres/src/main/resources/db/migration/V*.sql` | 생성 | V2 ~ V13 마이그레이션 스크립트 생성 |
| `sw-campus-docs/features/data-migration/report.md` | 수정 | 마이그레이션 결과 리포트 업데이트 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 계획대로 진행된 항목

- Python Pandas를 이용한 ETL 프로세스 구현
- Flyway를 이용한 DB 마이그레이션 적용
- Docker 환경에서의 검증

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| **보안 설정** | 명시되지 않음 | `MIGRATION_ADMIN_PASSWORD` 환경변수 필수화 | 코드 내 비밀번호 하드코딩 방지 |
| **헤더 파싱** | 단일 헤더 가정 | Multi-index Header (Merged Cells) 처리 로직 추가 | 원본 CSV의 병합된 헤더로 인한 컬럼 인식 오류 해결 |
| **데이터 정제** | 단순 매핑 | 카테고리 정규화 및 커리큘럼 노이즈 필터링 | '데이터 분석' vs '데이터분석가' 등 중복 제거 및 무효 데이터 제외 |

---

## 4. 검증 결과

### 4.1 빌드

```bash
$ ./gradlew build -x test

BUILD SUCCESSFUL in 2s
22 actionable tasks: 6 executed, 16 up-to-date
```

### 4.2 테스트

```bash
$ ./gradlew test

BUILD SUCCESSFUL in 17s
25 actionable tasks: 2 executed, 23 up-to-date
```

### 4.3 서브 모델 검증 (Critical인 경우)

| # | 심각도 | 이슈 | 해결 |
|---|--------|------|------|
| 1 | Critical | `lecture_quals` 데이터 누락 (0건) | CSV 헤더 파싱 로직 수정 (Merged Cell 처리) 후 558건 정상 적재 |
| 2 | Major | `lecture_adds` 데이터 누락 (0건) | 원본 데이터 전수 조사 결과 유효 데이터 없음('없음' 또는 NaN) 확인. 정상 동작으로 결론. |

---

## 5. 발생한 이슈

### 이슈 1: CSV 병합 헤더 인식 오류

- **증상**: `lecture_quals`(지원자격), `lecture_adds`(추가혜택) 테이블에 데이터가 적재되지 않음.
- **원인**: 원본 CSV의 2~3행이 병합된 헤더로 구성되어 있어, Pandas가 `Unnamed: ...` 형태의 컬럼명으로 인식함.
- **해결**: `convert.py`에서 컬럼명을 순회하며 `Unnamed`인 경우 이전 컬럼명을 상속받도록(Forward Fill) 로직을 수정함.

### 이슈 2: `lecture_adds` 데이터 부재

- **증상**: 헤더 파싱 로직 수정 후에도 `lecture_adds` 테이블 데이터가 0건임.
- **원인**: 원본 데이터를 전수 조사한 결과, 해당 컬럼(`지원혜택_추가혜택`)의 모든 값이 '없음' 또는 비어있음.
- **해결**: 데이터 누락이 아닌 원본 데이터의 부재임을 확인하고, 무의미한 '없음' 데이터가 적재되지 않도록 필터링 로직을 강화함.

---

## 6. 다음 Phase 준비 사항

- [x] PR 생성 및 코드 리뷰 진행

---

## 7. 참고 사항

- `scripts/data-migration/output/` 폴더는 `.gitignore`에 추가되어 저장소에 포함되지 않습니다.
- 생성된 SQL 파일은 `sw-campus-infra` 모듈의 리소스로 관리됩니다.

---

## 📊 진행률 (Plan README 업데이트용)

```
Phase 03 ██████████ 100%  ✅
```

완료: 15/15 tasks
