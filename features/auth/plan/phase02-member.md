# Phase 02: Member 도메인

> 예상 시간: 2시간

## 1. 목표

Member(회원) 도메인 객체와 Repository를 구현합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] Member 도메인 객체 구현
- [ ] MemberRepository 인터페이스 정의 (domain)
- [ ] MemberEntity 및 JPA Repository 구현 (infra)
- [ ] Role enum 정의
- [ ] 단위 테스트 통과
- [ ] 테스트 커버리지 95% 이상

---

## 3. 관련 User Stories

- 모든 US의 기반이 되는 도메인

---

## 4. 파일 구조

```
sw-campus-domain/
└── src/main/java/com/swcampus/domain/
    └── member/
        ├── Member.java
        ├── MemberRepository.java
        └── Role.java

sw-campus-infra/db-postgres/
└── src/main/java/com/swcampus/infra/postgres/
    └── member/
        ├── MemberEntity.java
        ├── MemberJpaRepository.java
        └── MemberRepositoryImpl.java
```

---

## 5. TDD Tasks

### 5.1 Red: 테스트 작성

**MemberTest.java**
```java
@DisplayName("Member 도메인 테스트")
class MemberTest {

    @Test
    @DisplayName("일반 회원을 생성할 수 있다")
    void createUser() {
        // given
        String email = "user@example.com";
        String password = "encodedPassword";
        String name = "홍길동";
        String nickname = "길동이";
        String phone = "010-1234-5678";
        String location = "서울시 강남구";

        // when
        Member member = Member.createUser(email, password, name, nickname, phone, location);

        // then
        assertThat(member.getEmail()).isEqualTo(email);
        assertThat(member.getRole()).isEqualTo(Role.USER);
        assertThat(member.getOrgAuth()).isNull();
    }

    @Test
    @DisplayName("교육제공자를 생성할 수 있다")
    void createProvider() {
        // given & when
        Member member = Member.createProvider(
            "provider@example.com", "encodedPassword", 
            "김제공", "제공자", "010-9876-5432", "서울시 서초구"
        );

        // then
        assertThat(member.getRole()).isEqualTo(Role.PROVIDER);
        assertThat(member.getOrgAuth()).isEqualTo(0); // 미승인
    }

    @Test
    @DisplayName("비밀번호를 변경할 수 있다")
    void changePassword() {
        // given
        Member member = Member.createUser(...);
        String newPassword = "newEncodedPassword";

        // when
        member.changePassword(newPassword);

        // then
        assertThat(member.getPassword()).isEqualTo(newPassword);
    }
}
```

**MemberRepositoryTest.java**
```java
@DataJpaTest
@DisplayName("MemberRepository 테스트")
class MemberRepositoryTest {

    @Autowired
    private MemberJpaRepository memberJpaRepository;

    private MemberRepositoryImpl memberRepository;

    @BeforeEach
    void setUp() {
        memberRepository = new MemberRepositoryImpl(memberJpaRepository);
    }

    @Test
    @DisplayName("이메일로 회원을 조회할 수 있다")
    void findByEmail() {
        // given
        Member member = Member.createUser(...);
        memberRepository.save(member);

        // when
        Optional<Member> found = memberRepository.findByEmail("user@example.com");

        // then
        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("user@example.com");
    }

    @Test
    @DisplayName("이메일 존재 여부를 확인할 수 있다")
    void existsByEmail() {
        // given
        Member member = Member.createUser(...);
        memberRepository.save(member);

        // when & then
        assertThat(memberRepository.existsByEmail("user@example.com")).isTrue();
        assertThat(memberRepository.existsByEmail("unknown@example.com")).isFalse();
    }
}
```

### 5.2 Green: 구현

**Role.java**
```java
public enum Role {
    USER,
    PROVIDER,
    ADMIN
}
```

**Member.java (Domain)**
```java
@Getter
public class Member {
    private Long id;
    private String email;
    private String password;
    private String name;
    private String nickname;
    private String phone;
    private Role role;
    private Integer orgAuth;  // null: 일반회원, 0: 미승인, 1: 승인
    private Long orgId;
    private String location;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // 정적 팩토리 메서드
    public static Member createUser(String email, String password, 
            String name, String nickname, String phone, String location) {
        Member member = new Member();
        member.email = email;
        member.password = password;
        member.name = name;
        member.nickname = nickname;
        member.phone = phone;
        member.location = location;
        member.role = Role.USER;
        member.orgAuth = null;
        member.createdAt = LocalDateTime.now();
        member.updatedAt = LocalDateTime.now();
        return member;
    }

    public static Member createProvider(String email, String password,
            String name, String nickname, String phone, String location) {
        Member member = createUser(email, password, name, nickname, phone, location);
        member.role = Role.PROVIDER;
        member.orgAuth = 0;  // 미승인
        return member;
    }

    public void changePassword(String newPassword) {
        this.password = newPassword;
        this.updatedAt = LocalDateTime.now();
    }

    public void approveProvider() {
        if (this.role != Role.PROVIDER) {
            throw new IllegalStateException("교육제공자만 승인할 수 있습니다");
        }
        this.orgAuth = 1;
        this.updatedAt = LocalDateTime.now();
    }
}
```

**MemberRepository.java (Domain Interface)**
```java
public interface MemberRepository {
    Member save(Member member);
    Optional<Member> findById(Long id);
    Optional<Member> findByEmail(String email);
    boolean existsByEmail(String email);
}
```

**MemberEntity.java (Infra)**
```java
@Entity
@Table(name = "members")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MemberEntity {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    private String password;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String nickname;

    @Column(nullable = false)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    @Column(name = "org_auth")
    private Integer orgAuth;

    @Column(name = "org_id")
    private Long orgId;

    private String location;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Domain ↔ Entity 변환 메서드
    public static MemberEntity from(Member member) { ... }
    public Member toDomain() { ... }
}
```

**MemberJpaRepository.java**
```java
public interface MemberJpaRepository extends JpaRepository<MemberEntity, Long> {
    Optional<MemberEntity> findByEmail(String email);
    boolean existsByEmail(String email);
}
```

**MemberRepositoryImpl.java**
```java
@Repository
@RequiredArgsConstructor
public class MemberRepositoryImpl implements MemberRepository {
    
    private final MemberJpaRepository jpaRepository;

    @Override
    public Member save(Member member) {
        MemberEntity entity = MemberEntity.from(member);
        MemberEntity saved = jpaRepository.save(entity);
        return saved.toDomain();
    }

    @Override
    public Optional<Member> findById(Long id) {
        return jpaRepository.findById(id).map(MemberEntity::toDomain);
    }

    @Override
    public Optional<Member> findByEmail(String email) {
        return jpaRepository.findByEmail(email).map(MemberEntity::toDomain);
    }

    @Override
    public boolean existsByEmail(String email) {
        return jpaRepository.existsByEmail(email);
    }
}
```

---

## 6. 검증

```bash
# 테스트 실행
./gradlew :sw-campus-domain:test --tests "*MemberTest*"
./gradlew :sw-campus-infra:db-postgres:test --tests "*MemberRepositoryTest*"

# 커버리지 확인
./gradlew :sw-campus-domain:jacocoTestReport
```

---

## 7. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `Role.java` | domain | 역할 enum |
| `Member.java` | domain | 회원 도메인 객체 |
| `MemberRepository.java` | domain | Repository 인터페이스 |
| `MemberEntity.java` | infra | JPA Entity |
| `MemberJpaRepository.java` | infra | JPA Repository |
| `MemberRepositoryImpl.java` | infra | Repository 구현체 |
| `MemberTest.java` | domain/test | 도메인 테스트 |
| `MemberRepositoryTest.java` | infra/test | Repository 테스트 |

---

## 8. 다음 Phase

→ [Phase 03: Security + JWT](./phase03-security.md)
