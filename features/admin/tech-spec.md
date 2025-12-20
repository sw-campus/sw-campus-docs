# Admin 회원 관리 - Tech Spec

> Technical Specification

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-20 |
| 상태 | Completed |
| 버전 | 1.0 |
| PRD | [prd.md](./prd.md) |

---

## 1. 개요

### 1.1 목적

PRD에 정의된 Admin 회원 조회 기능(목록 조회, 검색)의 기술적 구현 명세를 정의합니다.

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
│   └── admin/
│       ├── AdminMemberController.java
│       └── response/
│           └── AdminMemberResponse.java
│
├── sw-campus-domain/                 # Business Logic Layer
│   └── member/
│       ├── AdminMemberService.java
│       └── MemberRepository.java (수정)
│
└── sw-campus-infra/db-postgres/      # Infrastructure Layer
    └── member/
        ├── MemberJpaRepository.java (수정)
        └── MemberEntityRepository.java (수정)
```

### 2.2 컴포넌트 구조

#### sw-campus-api

```
com.swcampus.api/
└── admin/
    ├── AdminMemberController.java
    └── response/
        └── AdminMemberResponse.java
```

#### sw-campus-domain

```
com.swcampus.domain/
└── member/
    ├── AdminMemberService.java (신규)
    └── MemberRepository.java (수정)
```

#### sw-campus-infra/db-postgres

```
com.swcampus.infra.postgres/
└── member/
    ├── MemberJpaRepository.java (수정)
    └── MemberEntityRepository.java (수정)
```

---

## 3. API 설계

### 3.1 회원 목록 조회/검색

#### `GET /api/v1/admin/members`

회원 목록 조회 및 검색

**Request**
```
Cookie: accessToken=...
```

**Query Parameters**
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|:----:|--------|------|
| keyword | String | X | "" | 검색어 (이름, 닉네임, 이메일) |
| page | int | X | 0 | 페이지 번호 (0부터 시작) |
| size | int | X | 10 | 페이지 크기 |

**Response** `200 OK`
```json
{
  "content": [
    {
      "id": 1,
      "email": "user@example.com",
      "name": "홍길동",
      "nickname": "길동이",
      "phone": "010-1234-5678"
    }
  ],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 10,
    "sort": {
      "sorted": true,
      "direction": "DESC",
      "property": "createdAt"
    }
  },
  "totalElements": 100,
  "totalPages": 10
}
```

**Errors**
- `401` COMMON001: 인증이 필요합니다
- `403` COMMON002: 접근 권한이 없습니다 (ADMIN이 아닌 경우)

---

## 4. 검색 로직

### 4.1 검색 조건

검색어(keyword)가 입력되면 다음 필드에서 OR 조건으로 검색합니다:

| 필드 | 검색 방식 |
|------|----------|
| name | LIKE '%keyword%' (대소문자 무시) |
| nickname | LIKE '%keyword%' (대소문자 무시) |
| email | LIKE '%keyword%' (대소문자 무시) |

### 4.2 JPQL 쿼리

```java
@Query("SELECT m FROM MemberEntity m WHERE " +
       ":keyword IS NULL OR :keyword = '' OR " +
       "LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "LOWER(m.nickname) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "LOWER(m.email) LIKE LOWER(CONCAT('%', :keyword, '%'))")
Page<MemberEntity> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);
```

### 4.3 정렬

- 기본 정렬: 가입일(createdAt) 내림차순 (최신순)
- Controller에서 Pageable 생성 시 Sort 지정

---

## 5. 보안 설계

### 5.1 인증/인가

| API | 인증 | Role |
|-----|:----:|------|
| `GET /api/v1/admin/members` | O | ADMIN |

### 5.2 Spring Security 설정

```java
@PreAuthorize("hasRole('ADMIN')")
public class AdminMemberController {
    ...
}
```

### 5.3 Swagger 보안 설정

```java
@SecurityRequirement(name = "cookieAuth")
```

---

## 6. 에러 코드

### 공통 에러 코드 (참조)

| 코드 | HTTP Status | 설명 |
|------|-------------|------|
| COMMON001 | 401 | 인증이 필요합니다 |
| COMMON002 | 403 | 접근 권한이 없습니다 |

---

## 7. 관련 문서

- [PRD](./prd.md)
- [Implementation Plan](./plan/phase01-member-search.md)
- [Implementation Report](./report/phase01-member-search.md)

---

## 8. 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2025-12-20 | 초안 작성 및 구현 완료 |
