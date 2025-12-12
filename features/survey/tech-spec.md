# 설문조사 (Survey) - Tech Spec

> Technical Specification

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-12 |
| 상태 | Draft |
| 버전 | 0.1 |
| PRD | [prd.md](./prd.md) |

---

## 1. 개요

### 1.1 목적

PRD에 정의된 설문조사 기능(작성, 조회, 수정)의 기술적 구현 명세를 정의합니다.

### 1.2 기술 스택

| 구분 | 기술 |
|------|------|
| Framework | Spring Boot 3.x |
| Security | Spring Security 6.x |
| Database | PostgreSQL |
| ORM | Spring Data JPA |

---

## 2. 시스템 아키텍처

### 2.1 모듈 구조

```
sw-campus-server/
├── sw-campus-api/                    # Presentation Layer
│   └── survey/
│       ├── SurveyController.java
│       ├── AdminSurveyController.java
│       ├── request/
│       └── response/
│
├── sw-campus-domain/                 # Business Logic Layer
│   └── survey/
│       ├── MemberSurvey.java
│       ├── MemberSurveyRepository.java
│       ├── MemberSurveyService.java
│       └── exception/
│
└── sw-campus-infra/db-postgres/      # Infrastructure Layer
    └── survey/
        ├── MemberSurveyEntity.java
        ├── MemberSurveyJpaRepository.java
        └── MemberSurveyEntityRepository.java
```

### 2.2 컴포넌트 구조

#### sw-campus-api

```
com.swcampus.api/
├── survey/
│   ├── SurveyController.java
│   ├── AdminSurveyController.java
│   ├── request/
│   │   ├── CreateSurveyRequest.java
│   │   └── UpdateSurveyRequest.java
│   └── response/
│       ├── SurveyResponse.java
│       └── SurveyListResponse.java
```

#### sw-campus-domain

```
com.swcampus.domain/
└── survey/
    ├── MemberSurvey.java
    ├── MemberSurveyRepository.java
    ├── MemberSurveyService.java
    └── exception/
        ├── SurveyNotFoundException.java
        └── SurveyAlreadyExistsException.java
```

#### sw-campus-infra/db-postgres

```
com.swcampus.infra.postgres/
└── survey/
    ├── MemberSurveyEntity.java
    ├── MemberSurveyJpaRepository.java
    └── MemberSurveyEntityRepository.java
```

---

## 3. API 설계

### 3.1 사용자 API

#### `POST /api/v1/members/me/survey`

설문조사 작성

**Request**
```
Cookie: accessToken=...
```

```json
{
  "major": "컴퓨터공학",
  "bootcampCompleted": true,
  "wantedJobs": "백엔드 개발자, 데이터 엔지니어",
  "licenses": "정보처리기사, SQLD, AWS SAA",
  "hasGovCard": true,
  "affordableAmount": 500000
}
```

**Response** `201 Created`
```json
{
  "userId": 1,
  "major": "컴퓨터공학",
  "bootcampCompleted": true,
  "wantedJobs": "백엔드 개발자, 데이터 엔지니어",
  "licenses": "정보처리기사, SQLD, AWS SAA",
  "hasGovCard": true,
  "affordableAmount": 500000,
  "createdAt": "2025-12-12T10:00:00",
  "updatedAt": "2025-12-12T10:00:00"
}
```

**Errors**
- `401` COMMON001: 인증이 필요합니다
- `403` COMMON002: 접근 권한이 없습니다 (USER가 아닌 경우)
- `409` SURVEY001: 이미 설문조사를 작성하셨습니다

---

#### `GET /api/v1/members/me/survey`

본인 설문조사 조회

**Request**
```
Cookie: accessToken=...
```

**Response** `200 OK`
```json
{
  "userId": 1,
  "major": "컴퓨터공학",
  "bootcampCompleted": true,
  "wantedJobs": "백엔드 개발자, 데이터 엔지니어",
  "licenses": "정보처리기사, SQLD, AWS SAA",
  "hasGovCard": true,
  "affordableAmount": 500000,
  "createdAt": "2025-12-12T10:00:00",
  "updatedAt": "2025-12-12T10:00:00"
}
```

**Errors**
- `401` COMMON001: 인증이 필요합니다
- `403` COMMON002: 접근 권한이 없습니다 (USER가 아닌 경우)
- `404` SURVEY002: 설문조사를 찾을 수 없습니다

---

#### `PUT /api/v1/members/me/survey`

본인 설문조사 수정

**Request**
```
Cookie: accessToken=...
```

```json
{
  "major": "소프트웨어공학",
  "bootcampCompleted": true,
  "wantedJobs": "풀스택 개발자",
  "licenses": "정보처리기사, SQLD, AWS SAA, CKAD",
  "hasGovCard": true,
  "affordableAmount": 1000000
}
```

**Response** `200 OK`
```json
{
  "userId": 1,
  "major": "소프트웨어공학",
  "bootcampCompleted": true,
  "wantedJobs": "풀스택 개발자",
  "licenses": "정보처리기사, SQLD, AWS SAA, CKAD",
  "hasGovCard": true,
  "affordableAmount": 1000000,
  "createdAt": "2025-12-12T10:00:00",
  "updatedAt": "2025-12-12T11:00:00"
}
```

**Errors**
- `401` COMMON001: 인증이 필요합니다
- `403` COMMON002: 접근 권한이 없습니다 (USER가 아닌 경우)
- `404` SURVEY002: 설문조사를 찾을 수 없습니다

---

### 3.2 관리자 API

#### `GET /api/v1/admin/members/surveys`

전체 설문조사 목록 조회

**Request**
```
Cookie: accessToken=...
```

**Query Parameters**
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|--------|------|
| page | int | ❌ | 0 | 페이지 번호 |
| size | int | ❌ | 20 | 페이지 크기 |

**Response** `200 OK`
```json
{
  "content": [
    {
      "userId": 1,
      "major": "컴퓨터공학",
      "bootcampCompleted": true,
      "wantedJobs": "백엔드 개발자, 데이터 엔지니어",
      "licenses": "정보처리기사, SQLD",
      "hasGovCard": true,
      "affordableAmount": 500000,
      "createdAt": "2025-12-12T10:00:00",
      "updatedAt": "2025-12-12T10:00:00"
    },
    {
      "userId": 2,
      "major": "전자공학",
      "bootcampCompleted": false,
      "wantedJobs": "프론트엔드 개발자",
      "licenses": null,
      "hasGovCard": false,
      "affordableAmount": null,
      "createdAt": "2025-12-12T11:00:00",
      "updatedAt": "2025-12-12T11:00:00"
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 2,
  "totalPages": 1
}
```

**Errors**
- `401` COMMON001: 인증이 필요합니다
- `403` COMMON002: 접근 권한이 없습니다 (ADMIN이 아닌 경우)

---

#### `GET /api/v1/admin/members/{userId}/survey`

특정 사용자 설문조사 조회

**Request**
```
Cookie: accessToken=...
```

**Path Parameters**
| 파라미터 | 타입 | 설명 |
|---------|------|------|
| userId | Long | 사용자 ID |

**Response** `200 OK`
```json
{
  "userId": 1,
  "major": "컴퓨터공학",
  "bootcampCompleted": true,
  "wantedJobs": "백엔드 개발자, 데이터 엔지니어",
  "licenses": "정보처리기사, SQLD, AWS SAA",
  "hasGovCard": true,
  "affordableAmount": 500000,
  "createdAt": "2025-12-12T10:00:00",
  "updatedAt": "2025-12-12T10:00:00"
}
```

**Errors**
- `401` COMMON001: 인증이 필요합니다
- `403` COMMON002: 접근 권한이 없습니다 (ADMIN이 아닌 경우)
- `404` SURVEY002: 설문조사를 찾을 수 없습니다

---

## 4. 데이터베이스 스키마

### 4.1 MEMBER_SURVEYS 테이블

```sql
CREATE TABLE MEMBER_SURVEYS (
    USER_ID BIGINT PRIMARY KEY REFERENCES MEMBERS(USER_ID) ON DELETE CASCADE,
    MAJOR VARCHAR(100),
    BOOTCAMP_COMPLETED BOOLEAN,
    WANTED_JOBS VARCHAR(255),
    LICENSES VARCHAR(500),
    HAS_GOV_CARD BOOLEAN,
    AFFORDABLE_AMOUNT NUMERIC(15, 2),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE MEMBER_SURVEYS IS '회원 설문조사';
COMMENT ON COLUMN MEMBER_SURVEYS.USER_ID IS '회원 ID (PK, FK)';
COMMENT ON COLUMN MEMBER_SURVEYS.MAJOR IS '전공';
COMMENT ON COLUMN MEMBER_SURVEYS.BOOTCAMP_COMPLETED IS '부트캠프 수료 여부';
COMMENT ON COLUMN MEMBER_SURVEYS.WANTED_JOBS IS '희망 직무';
COMMENT ON COLUMN MEMBER_SURVEYS.LICENSES IS '보유 자격증';
COMMENT ON COLUMN MEMBER_SURVEYS.HAS_GOV_CARD IS '내일배움카드 보유 여부';
COMMENT ON COLUMN MEMBER_SURVEYS.AFFORDABLE_AMOUNT IS '자비 부담 가능 금액';
```

### 4.2 관계 다이어그램

```
MEMBERS (1) ──────── (0..1) MEMBER_SURVEYS
          USER_ID ◄──────── USER_ID (PK, FK)
```

---

## 5. 보안 설계

### 5.1 인증/인가

| API | 인증 | Role |
|-----|:----:|------|
| `POST /api/v1/members/me/survey` | ✅ | USER |
| `GET /api/v1/members/me/survey` | ✅ | USER |
| `PUT /api/v1/members/me/survey` | ✅ | USER |
| `GET /api/v1/admin/members/surveys` | ✅ | ADMIN |
| `GET /api/v1/admin/members/{userId}/survey` | ✅ | ADMIN |

### 5.2 데이터 접근 제어

- USER는 본인의 설문조사만 조회/수정 가능
- ADMIN은 모든 사용자의 설문조사 조회 가능 (수정 불가)
- 설문조사 삭제는 회원 탈퇴 시 CASCADE로 자동 삭제

---

## 6. 에러 코드

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| SURVEY001 | 409 | 이미 설문조사를 작성하셨습니다 |
| SURVEY002 | 404 | 설문조사를 찾을 수 없습니다 |

### 공통 에러 코드 (참조)

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| COMMON001 | 401 | 인증이 필요합니다 |
| COMMON002 | 403 | 접근 권한이 없습니다 |

---

## 7. 시퀀스 다이어그램

- [설문조사 시퀀스 설명](../../sequence/survey/survey_description.md)
- [설문조사 시퀀스 다이어그램](../../sequence/survey/survey_diagram.md)

---

## 8. 관련 문서

- [PRD](./prd.md)
- [Development Plan](./plan.md)
- [Implementation Report](./report.md)

---

## 9. 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 0.1 | 2025-12-12 | 초안 작성 |
