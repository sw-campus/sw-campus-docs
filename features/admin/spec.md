# Admin 회원 관리 Spec

## 개요

관리자용 회원 조회 및 검색 기능의 기술 명세입니다.

---

## API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/admin/members` | 회원 목록 조회/검색 | ADMIN |

**Query Parameters**:
| 파라미터 | 타입 | 필수 | 기본값 | 설명 |
|---------|------|------|--------|------|
| keyword | String | X | "" | 검색어 (이름, 닉네임, 이메일) |
| page | int | X | 0 | 페이지 번호 |
| size | int | X | 10 | 페이지 크기 |

**Response**:
```json
{
  "content": [{ "id": 1, "email": "...", "name": "...", "nickname": "...", "phone": "..." }],
  "totalElements": 100,
  "totalPages": 10
}
```

---

## 검색 로직

| 필드 | 검색 방식 |
|------|----------|
| name | LIKE '%keyword%' (대소문자 무시) |
| nickname | LIKE '%keyword%' (대소문자 무시) |
| email | LIKE '%keyword%' (대소문자 무시) |

**JPQL**:
```java
@Query("SELECT m FROM MemberEntity m WHERE " +
       ":keyword IS NULL OR :keyword = '' OR " +
       "LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "LOWER(m.nickname) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "LOWER(m.email) LIKE LOWER(CONCAT('%', :keyword, '%'))")
```

- 기본 정렬: 가입일(createdAt) 내림차순

---

## 보안

- `@PreAuthorize("hasRole('ADMIN')")`
- `@SecurityRequirement(name = "cookieAuth")`

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| COMMON001 | 401 | 인증이 필요합니다 |
| COMMON002 | 403 | 접근 권한이 없습니다 |

---

## 구현 노트

### 2025-12-20 - 초기 구현

- 회원 목록 조회 및 키워드 검색 기능
- 페이지네이션 지원
- ADMIN 권한 체크
