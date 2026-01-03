# 초기 데이터 마이그레이션 Spec

## 설계 결정

### 왜 Python + Pandas인가?

복잡한 CSV 정제와 SQL 생성 자동화.

| 선택지 | 장점 | 단점 |
|--------|------|------|
| Bash/SQL | 단순 | CSV 파싱 복잡, 데이터 검증 어려움 |
| Python + Pandas | DataFrame API, 자동 정제 | 추가 의존성 |

- 공백 제거, 금액 변환, 날짜 형식 변환 등 정제 로직
- 기관명/강사명 중복 제거 및 정렬
- bcrypt 비밀번호 해싱

### 왜 마스터 데이터를 먼저 처리하는가?

FK 의존성 순서 준수.

```
Step 0: Admin User
Step 1: Categories (대분류→중분류→소분류)
Step 2: Organizations (기관)
Step 3: Teachers (강사)
Step 4: Curriculums (커리큘럼)
Step 5: Lectures + 관계 테이블
```

- 강의(Step 5)는 기관/강사/커리큘럼 ID 참조
- 상위 데이터가 없으면 FK 제약 위반
- 정렬된 순서로 생성하여 같은 CSV → 같은 ID 보장

### 왜 ON CONFLICT DO NOTHING인가?

멱등성(Idempotency) 보장.

```sql
INSERT INTO ... VALUES (...) ON CONFLICT DO NOTHING;
```

- 스크립트 재실행 시 중복 오류 없음
- 부분 실행 후 재개 가능
- Flyway 마이그레이션 안전성

### 왜 Sequence를 리셋하는가?

다음 INSERT 시 ID 충돌 방지.

```sql
SELECT setval('table_id_seq', (SELECT COALESCE(MAX(id), 1) FROM table));
```

- 시드 데이터가 명시적 ID로 삽입됨
- 리셋 없으면 다음 `nextval()`이 1부터 시작
- MAX(id) + 1부터 시작하도록 동기화

### 왜 인코딩 폴백 처리를 하는가?

다양한 CSV 소스 호환.

```python
try:
    df = pd.read_csv(path, encoding='utf-8-sig')
except UnicodeDecodeError:
    df = pd.read_csv(path, encoding='cp949')  # Windows 한글
```

- 원본 CSV가 여러 소스에서 수집됨
- UTF-8 BOM, Windows cp949 등 혼재
- 자동 감지로 수동 변환 불필요

---

## 구현 노트

### 2025-12-16 - 초기 구현 [Server]

- Python 스크립트로 CSV → SQL 변환
- 12개 Flyway 마이그레이션 파일 생성 (V2~V13)
- 데이터: 153개 기관, 389개 강좌, 25개 카테고리, 50개 커리큘럼
- 관련: `scripts/data-migration/src/convert.py`
