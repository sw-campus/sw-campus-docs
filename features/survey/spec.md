# 설문조사 (Survey) Spec

## 개요

사용자 설문조사 작성, 조회, 수정 기능의 기술 명세입니다.

---

## API

### 사용자 API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/members/me/survey` | 설문조사 작성 | USER |
| GET | `/api/v1/members/me/survey` | 본인 설문조사 조회 | USER |
| PUT | `/api/v1/members/me/survey` | 본인 설문조사 수정 | USER |

### 관리자 API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/admin/members/surveys` | 전체 설문 목록 | ADMIN |
| GET | `/api/v1/admin/members/{userId}/survey` | 특정 사용자 설문 | ADMIN |

**Request/Response 필드**:
| 필드 | 타입 | 설명 |
|------|------|------|
| major | String | 전공 |
| bootcampCompleted | Boolean | 부트캠프 수료 여부 |
| wantedJobs | String | 희망 직무 |
| licenses | String | 보유 자격증 |
| hasGovCard | Boolean | 내일배움카드 보유 여부 |
| affordableAmount | Numeric | 자비 부담 가능 금액 |

---

## DB 스키마

### MEMBER_SURVEYS

```sql
CREATE TABLE MEMBER_SURVEYS (
    USER_ID BIGINT PRIMARY KEY REFERENCES MEMBERS(USER_ID) ON DELETE CASCADE,
    MAJOR VARCHAR(100),
    BOOTCAMP_COMPLETED BOOLEAN,
    WANTED_JOBS VARCHAR(255),
    LICENSES VARCHAR(500),
    HAS_GOV_CARD BOOLEAN,
    AFFORDABLE_AMOUNT NUMERIC(15, 2),
    CREATED_AT TIMESTAMP,
    UPDATED_AT TIMESTAMP
);
```

**관계**: MEMBERS (1) ── (0..1) MEMBER_SURVEYS

---

## 보안

| 역할 | 권한 |
|------|------|
| USER | 본인 설문조사만 CRUD |
| ADMIN | 모든 사용자 설문조사 조회 (수정 불가) |

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| SURVEY001 | 409 | 이미 설문조사를 작성하셨습니다 |
| SURVEY002 | 404 | 설문조사를 찾을 수 없습니다 |

---

## 구현 노트

### 2025-12-12 - 초기 구현

- 설문조사 CRUD
- USER 본인만 작성/수정 가능
- ADMIN 전체 조회
- 회원 탈퇴 시 CASCADE 삭제
