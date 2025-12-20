# spec.md 템플릿

## 기본 구조

```markdown
# {Feature Title} Spec

## 개요

{기능에 대한 간단한 설명}

---

## API

### {API 그룹 1}

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/...` | ... | O/X |
| POST | `/api/v1/...` | ... | O/X |

**Request**:
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| field1 | String | O | ... |

**Response**:
```json
{
  "id": 1,
  "name": "..."
}
```

### {API 그룹 2}

...

---

## DB 스키마

### {TABLE_NAME}

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGSERIAL PK | ID |
| name | VARCHAR(255) | 이름 |
| created_at | TIMESTAMPTZ | 생성일시 |

**관계**:
- `{TABLE1}` (1) ── (N) `{TABLE2}`

**인덱스**:
- `idx_{table}_{column}` ON {column}

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| {DOMAIN}001 | 400 | ... |
| {DOMAIN}002 | 404 | ... |
| {DOMAIN}003 | 409 | ... |

---

## 보안

| API | 인증 | 권한 |
|-----|:----:|------|
| `GET /api/v1/...` | O | USER |
| `POST /api/v1/...` | O | ADMIN |

---

## 구현 노트

### {DATE} - 초기 구현

- PR: #{PR_NUMBER}
- 주요 변경: ...
- 특이사항: ...
```

## 섹션별 가이드

### API 섹션
- 기능별로 그룹화
- Request/Response 예시 포함
- Query Parameters, Path Parameters 구분

### DB 스키마 섹션
- 신규 테이블만 상세 작성
- 기존 테이블 수정은 ALTER 문으로
- 관계와 인덱스 명시

### 에러 코드 섹션
- 도메인 prefix 사용 (LECTURE, REVIEW 등)
- 기존 에러 코드와 충돌 방지

### 구현 노트 섹션
- 구현 완료 후 추가
- PR 링크, 변경사항, 특이사항 기록
- 날짜별로 누적
