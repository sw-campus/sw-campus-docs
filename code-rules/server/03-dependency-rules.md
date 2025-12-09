# 03. 모듈 간 의존성 규칙

> 의존성 역전 원칙(DIP)을 준수하여 유연한 아키텍처를 유지합니다.

---

## 🎯 핵심 원칙

> **"의존성은 항상 domain을 향해야 한다"**

```
┌─────────────────────────────────────────────────────┐
│                      api                             │
│                       │                              │
│                       │ implementation               │
│                       ↓                              │
│                    domain ←────────────────┐         │
│                       ↑                    │         │
│                       │ implementation     │         │
│                       │                    │         │
│                    infra ──────────────────┘         │
└─────────────────────────────────────────────────────┘
```

---

## 📊 의존성 매트릭스

| 모듈 | api | domain | infra | shared |
|------|-----|--------|-------|--------|
| **api** | - | ✅ implementation | ✅ runtimeOnly | ✅ implementation |
| **domain** | ❌ | - | ❌ | ✅ implementation |
| **infra** | ❌ | ✅ implementation | - | ✅ implementation |
| **shared** | ❌ | ❌ | ❌ | - |

### 의존성 방향 규칙

| 규칙 | 설명 |
|------|------|
| ✅ 허용 | 해당 모듈을 의존할 수 있음 |
| ❌ 금지 | 해당 모듈을 의존하면 안 됨 |

---

## 📁 build.gradle 설정

### sw-campus-api/build.gradle

```groovy
dependencies {
    // ✅ domain 직접 의존
    implementation project(':sw-campus-domain')
    
    // ✅ shared 의존
    implementation project(':sw-campus-shared:logging')
    
    // ✅ infra는 runtimeOnly (컴파일 시 직접 참조 불가)
    runtimeOnly project(':sw-campus-infra:db-postgres')
    
    // Spring Boot
    implementation 'org.springframework.boot:spring-boot-starter-web'
}
```

### sw-campus-domain/build.gradle

```groovy
dependencies {
    // ✅ 순수하게 유지 - 다른 모듈 의존 최소화
    // ❌ api 의존 금지
    // ❌ infra 의존 금지
    
    // Spring Context (선택적)
    compileOnly 'org.springframework:spring-context'
    
    // Validation
    implementation 'org.springframework.boot:spring-boot-starter-validation'
}
```

### sw-campus-infra/db-postgres/build.gradle

```groovy
dependencies {
    // ✅ domain 직접 의존 (Repository 인터페이스 구현 위해)
    implementation project(':sw-campus-domain')
    
    // ❌ api 의존 금지!
    // compileOnly project(':sw-campus-api')  // 이렇게 하면 안 됨!
    
    // JPA
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    runtimeOnly 'org.postgresql:postgresql'
}
```

---

## 🚫 금지 사항

### 1. infra → api 의존 금지

```groovy
// ❌ 절대 금지!
// sw-campus-infra/db-postgres/build.gradle
dependencies {
    compileOnly project(':sw-campus-api')  // WRONG!
    implementation project(':sw-campus-api')  // WRONG!
}
```

**이유:**
- 순환 의존성 위험
- api 변경 시 infra 영향
- 계층 분리 원칙 위반

### 2. domain → api/infra 의존 금지

```groovy
// ❌ 절대 금지!
// sw-campus-domain/build.gradle
dependencies {
    implementation project(':sw-campus-api')  // WRONG!
    implementation project(':sw-campus-infra:db-postgres')  // WRONG!
}
```

**이유:**
- domain은 핵심 비즈니스 로직
- 외부 변경에 영향받지 않아야 함
- 테스트 용이성 저하

### 3. api에서 infra 직접 import 금지

```java
// ❌ 금지! (runtimeOnly이므로 컴파일 에러 발생해야 함)
import com.swcampus.infra.postgres.user.UserEntity;
import com.swcampus.infra.postgres.user.UserJpaRepository;

// ✅ 올바른 방법
import com.swcampus.domain.user.User;
import com.swcampus.domain.user.UserService;
```

---

## ✅ 올바른 의존성 흐름

### 1. Controller → Service → Repository (인터페이스)

```java
// api 모듈
@RestController
public class UserController {
    private final UserService userService;  // ✅ domain의 서비스
}

// domain 모듈
@Service
public class UserService {
    private final UserRepository userRepository;  // ✅ domain의 인터페이스
}

// domain 모듈 (인터페이스)
public interface UserRepository {
    User findById(Long id);
}

// infra 모듈 (구현체)
@Repository
public class UserEntityRepository implements UserRepository {
    private final UserJpaRepository jpaRepository;
    
    @Override
    public User findById(Long id) {
        return jpaRepository.findById(id)
            .map(UserMapper::toDomain)
            .orElse(null);
    }
}
```

### 2. Domain 객체와 Entity 분리

```java
// domain 모듈 - 순수 도메인 객체
public class User {
    private Long id;
    private String email;
    private String nickname;
    
    // 비즈니스 로직
    public void changeNickname(String newNickname) {
        this.nickname = newNickname;
    }
}

// infra 모듈 - JPA Entity
@Entity
@Table(name = "users")
public class UserEntity extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String email;
    private String nickname;
}

// infra 모듈 - Mapper
public class UserMapper {
    public static User toDomain(UserEntity entity) {
        return User.of(entity.getId(), entity.getEmail(), entity.getNickname());
    }
    
    public static UserEntity toEntity(User user) {
        return new UserEntity(user.getId(), user.getEmail(), user.getNickname());
    }
}
```

---

## 📈 의존성 방향의 이점

| 이점 | 설명 |
|------|------|
| **테스트 용이성** | domain 모듈 단독 테스트 가능 |
| **유연한 변경** | DB 변경 시 infra만 수정 |
| **명확한 책임** | 각 모듈의 역할이 명확 |
| **병렬 개발** | 모듈별 독립적 개발 가능 |

---

## ✅ 체크리스트

- [ ] api → domain (implementation) 인가?
- [ ] api → infra (runtimeOnly) 인가?
- [ ] infra → domain (implementation) 인가?
- [ ] infra → api 의존이 없는가?
- [ ] domain → api/infra 의존이 없는가?
- [ ] api에서 infra 패키지를 import하지 않았는가?

