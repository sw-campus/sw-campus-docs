# Phase 01 Report: 회원 목록 조회/검색

> 완료일: 2025-12-20

## 개요

ADMIN 권한으로 회원 목록을 조회하고 검색할 수 있는 API를 구현했습니다.

---

## 완료 항목

### API 모듈 (sw-campus-api)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `AdminMemberController.java` | `api/admin/` | O | Admin 회원 조회 컨트롤러 |
| `AdminMemberResponse.java` | `api/admin/response/` | O | 회원 응답 DTO |

### Domain 모듈 (sw-campus-domain)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `AdminMemberService.java` | `domain/member/` | O | 회원 검색 서비스 |
| `MemberRepository.java` | `domain/member/` | O (수정) | `searchByKeyword` 메서드 추가 |

### Infra 모듈 (sw-campus-infra/db-postgres)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `MemberJpaRepository.java` | `infra/postgres/member/` | O (수정) | JPQL 검색 쿼리 추가 |
| `MemberEntityRepository.java` | `infra/postgres/member/` | O (수정) | `searchByKeyword` 구현 |

---

## 코드룰 준수 확인

| 항목 | 상태 | 비고 |
|-----|:----:|------|
| 네이밍 컨벤션 | O | `Admin{Domain}Controller`, `{Domain}Response` 패턴 |
| 의존성 방향 | O | `api → domain ← infra` |
| 패키지 구조 | O | admin 패키지 분리 |
| 권한 제어 | O | `@PreAuthorize("hasRole('ADMIN')")` |
| Swagger 문서화 | O | `@Tag`, `@Operation`, `@SecurityRequirement` |

---

## 구현 상세

### API 엔드포인트

```
GET /api/v1/admin/members?keyword={검색어}&page=0&size=10
```

### 검색 로직

- keyword가 비어있으면 전체 조회
- keyword가 있으면 이름, 닉네임, 이메일에서 OR 조건으로 검색 (대소문자 무시)

### 정렬

- 가입일(createdAt) 기준 내림차순 (최신순)

---

## 트러블슈팅

### 1. Parameter Name Reflection 오류

**문제**: `Name for argument of type [java.lang.String] not specified`

**원인**: Java 리플렉션에서 파라미터 이름을 가져오지 못함

**해결**: `@RequestParam(name = "keyword", ...)` 형태로 명시적 이름 지정

### 2. Swagger Sort 파라미터 오류

**문제**: `Sort expression '["string"]: ASC' must only contain property references`

**원인**: Swagger UI가 기본값으로 `["string"]`을 sort 파라미터에 전송

**해결**: `@PageableDefault` 대신 개별 `@RequestParam`으로 page, size를 받고 Controller에서 `PageRequest.of(page, size, Sort.by(...))` 생성

```java
@GetMapping
public ResponseEntity<Page<AdminMemberResponse>> getMembers(
        @RequestParam(name = "keyword", required = false, defaultValue = "") String keyword,
        @RequestParam(name = "page", required = false, defaultValue = "0") int page,
        @RequestParam(name = "size", required = false, defaultValue = "10") int size) {
    Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
    ...
}
```

---

## 테스트 결과

### Swagger UI 테스트

```
GET /api/v1/admin/members?keyword=&page=0&size=10
```

**응답** (200 OK):
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
  "totalElements": 1,
  "totalPages": 1,
  ...
}
```

### 권한 테스트

| 조건 | 결과 |
|------|------|
| ADMIN 계정 로그인 | O 200 OK |
| USER 계정 로그인 | O 403 Forbidden |
| 미인증 | O 401 Unauthorized |

---

## 향후 과제

- [ ] 회원 상세 조회 API
- [ ] 회원 승인/거절 기능
- [ ] 회원 상태 변경 기능
