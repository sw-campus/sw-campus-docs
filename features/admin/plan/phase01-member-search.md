# Phase 01: 회원 목록 조회/검색

> Admin 회원 조회 API 구현

## 목표

- ADMIN 권한으로 회원 목록을 조회하고 검색할 수 있는 API 구현
- 이름, 닉네임, 이메일로 OR 조건 검색
- 가입일 기준 최신순 정렬 및 페이지네이션

---

## 1. API 모듈

### 1.1 Controller

#### AdminMemberController.java
```java
package com.swcampus.api.admin;

@RestController
@RequestMapping("/api/v1/admin/members")
@RequiredArgsConstructor
@Tag(name = "Admin Member", description = "관리자 회원 관리 API")
@SecurityRequirement(name = "cookieAuth")
@PreAuthorize("hasRole('ADMIN')")
public class AdminMemberController {

    private final AdminMemberService adminMemberService;

    @GetMapping
    public ResponseEntity<Page<AdminMemberResponse>> getMembers(
            @RequestParam(name = "keyword", required = false, defaultValue = "") String keyword,
            @RequestParam(name = "page", required = false, defaultValue = "0") int page,
            @RequestParam(name = "size", required = false, defaultValue = "10") int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Member> members = adminMemberService.searchMembers(keyword, pageable);
        return ResponseEntity.ok(members.map(AdminMemberResponse::from));
    }
}
```

### 1.2 Response DTO

#### AdminMemberResponse.java
```java
package com.swcampus.api.admin.response;

public record AdminMemberResponse(
        Long id,
        String email,
        String name,
        String nickname,
        String phone
) {
    public static AdminMemberResponse from(Member member) {
        return new AdminMemberResponse(
                member.getId(),
                member.getEmail(),
                member.getName(),
                member.getNickname(),
                member.getPhone()
        );
    }
}
```

---

## 2. Domain 모듈

### 2.1 Service

#### AdminMemberService.java
```java
package com.swcampus.domain.member;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminMemberService {

    private final MemberRepository memberRepository;

    public Page<Member> searchMembers(String keyword, Pageable pageable) {
        return memberRepository.searchByKeyword(keyword, pageable);
    }
}
```

### 2.2 Repository 인터페이스 수정

#### MemberRepository.java
```java
// 기존 메서드에 추가
Page<Member> searchByKeyword(String keyword, Pageable pageable);
```

---

## 3. Infra 모듈 (db-postgres)

### 3.1 JPA Repository 수정

#### MemberJpaRepository.java
```java
@Query("SELECT m FROM MemberEntity m WHERE " +
       ":keyword IS NULL OR :keyword = '' OR " +
       "LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "LOWER(m.nickname) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
       "LOWER(m.email) LIKE LOWER(CONCAT('%', :keyword, '%'))")
Page<MemberEntity> searchByKeyword(@Param("keyword") String keyword, Pageable pageable);
```

### 3.2 Repository 구현체 수정

#### MemberEntityRepository.java
```java
@Override
public Page<Member> searchByKeyword(String keyword, Pageable pageable) {
    return jpaRepository.searchByKeyword(keyword, pageable).map(MemberEntity::toDomain);
}
```

---

## 완료 체크리스트

- [ ] `AdminMemberController.java` 생성
- [ ] `AdminMemberResponse.java` 생성
- [ ] `AdminMemberService.java` 생성
- [ ] `MemberRepository.java`에 `searchByKeyword` 메서드 추가
- [ ] `MemberJpaRepository.java`에 JPQL 쿼리 추가
- [ ] `MemberEntityRepository.java`에 구현체 추가
- [ ] Swagger UI에서 API 테스트
- [ ] ADMIN 권한 접근 제어 확인

---

## 참고 패턴

- `AdminOrganizationController` - Admin API 패턴 참조
- `OrganizationRepository.searchByStatusAndKeyword()` - 페이징 검색 패턴 참조
