# Admin 회원 관리 Spec

## 설계 결정

### 왜 다중 필드 OR 검색인가?

관리자의 회원 검색 시나리오에 맞춤.

```sql
m.name ILIKE '%keyword%' OR
m.nickname ILIKE '%keyword%' OR
m.email ILIKE '%keyword%'
```

- 관리자가 어떤 정보로 회원을 기억하는지 알 수 없음
- 단일 키워드로 3개 필드 동시 검색
- PostgreSQL `ILIKE`로 대소문자 무시

### 왜 클래스 레벨 @PreAuthorize인가?

Admin 컨트롤러의 모든 메서드가 동일 권한.

```java
@PreAuthorize("hasRole('ADMIN')")  // 클래스 레벨
public class AdminMemberController { ... }
```

- 메서드마다 어노테이션 중복 제거
- 새 메서드 추가 시 권한 누락 방지
- 명시적 의도 표현: "이 컨트롤러 전체가 ADMIN 전용"

### 왜 읽기 전용 트랜잭션인가?

회원 조회/검색은 데이터 수정이 없음.

```java
@Transactional(readOnly = true)
public class AdminMemberService { ... }
```

- Hibernate 플러시 생략으로 성능 향상
- 실수로 save() 호출 시 예외 발생 (안전장치)

### 왜 Role 필터와 Keyword 필터가 독립적인가?

관리자가 역할과 검색어를 조합하여 사용.

```java
// 둘 다 선택적
@RequestParam(required = false) Role role
@RequestParam(defaultValue = "") String keyword
```

- `role=USER` + `keyword=홍` → USER 중 '홍' 포함
- `role=null` + `keyword=홍` → 전체 역할 중 '홍' 포함
- 유연한 필터링 조합 지원

---

## 구현 노트

### 2025-12-20 - 초기 구현 [Server]

- 회원 목록 조회/검색 API
- 역할별 회원 수 통계 API (`/stats`)
- 페이지네이션 지원 (기본 size=10)
- ADMIN 권한 체크 (클래스 레벨)
- 관련: `AdminMemberController.java`, `AdminMemberService.java`
