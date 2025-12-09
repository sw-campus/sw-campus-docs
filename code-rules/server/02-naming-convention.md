# 02. 네이밍 컨벤션

> 일관된 네이밍으로 코드 가독성을 높입니다.

---

## 📁 패키지 네이밍

| 규칙           | 예시                       |
| -------------- | -------------------------- |
| 모두 소문자    | `com.swcampus.domain.user` |
| 단수형 사용    | `user` (~~users~~)         |
| 의미 있는 이름 | `exception` (~~ex~~)       |

---

## 📄 클래스 네이밍

### 공통 규칙

- **PascalCase** 사용
- 명확하고 의미 있는 이름
- 약어 사용 자제 (예외: DTO, API, ID 등 관용적 약어)

### 모듈별 클래스 네이밍

#### API 모듈

| 유형          | 패턴                      | 예시                |
| ------------- | ------------------------- | ------------------- |
| Controller    | `{Domain}Controller`      | `UserController`    |
| Request DTO   | `{Action}{Domain}Request` | `CreateUserRequest` |
| Response DTO  | `{Domain}Response`        | `UserResponse`      |
| 목록 Response | `{Domain}ListResponse`    | `UserListResponse`  |

#### Domain 모듈

| 유형                  | 패턴                        | 예시                    |
| --------------------- | --------------------------- | ----------------------- |
| 도메인 객체           | `{Domain}`                  | `User`                  |
| 서비스                | `{Domain}Service`           | `UserService`           |
| Repository 인터페이스 | `{Domain}Repository`        | `UserRepository`        |
| 예외                  | `{Domain}{Reason}Exception` | `UserNotFoundException` |

#### Infra 모듈

| 유형              | 패턴                       | 예시                   |
| ----------------- | -------------------------- | ---------------------- |
| JPA Entity        | `{Domain}Entity`           | `UserEntity`           |
| JPA Repository    | `{Domain}JpaRepository`    | `UserJpaRepository`    |
| Repository 구현체 | `{Domain}EntityRepository` | `UserEntityRepository` |
| Mapper            | `{Domain}Mapper`           | `UserMapper`           |

---

## 🔤 메서드 네이밍

### 공통 규칙

- **camelCase** 사용
- 동사로 시작
- 명확한 의도 표현

### Controller 메서드

| HTTP Method | 패턴                    | 예시                   |
| ----------- | ----------------------- | ---------------------- |
| GET (단건)  | `get{Domain}`           | `getUser()`            |
| GET (목록)  | `get{Domain}List`       | `getUserList()`        |
| POST        | `create{Domain}`        | `createUser()`         |
| PUT         | `update{Domain}`        | `updateUser()`         |
| PATCH       | `update{Domain}{Field}` | `updateUserPassword()` |
| DELETE      | `delete{Domain}`        | `deleteUser()`         |

### Service 메서드

| 유형        | 패턴                                    | 예시                             |
| ----------- | --------------------------------------- | -------------------------------- |
| 조회 (단건) | `get{Domain}` / `find{Domain}By{Field}` | `getUser()`, `findUserByEmail()` |
| 조회 (목록) | `get{Domain}List` / `findAll{Domain}s`  | `getUserList()`                  |
| 생성        | `create{Domain}`                        | `createUser()`                   |
| 수정        | `update{Domain}`                        | `updateUser()`                   |
| 삭제        | `delete{Domain}`                        | `deleteUser()`                   |
| 존재 확인   | `exists{Domain}By{Field}`               | `existsUserByEmail()`            |
| 검증        | `validate{Something}`                   | `validatePassword()`             |

### Repository 메서드

| 유형      | 패턴                         | 예시              |
| --------- | ---------------------------- | ----------------- |
| 조회      | `findBy{Field}`              | `findByEmail()`   |
| 존재 확인 | `existsBy{Field}`            | `existsByEmail()` |
| 저장      | `save`                       | `save()`          |
| 삭제      | `delete` / `deleteBy{Field}` | `deleteById()`    |

---

## 📝 변수 네이밍

### 공통 규칙

- **camelCase** 사용
- 의미 있는 이름 (한 글자 변수 금지, 루프 제외)
- Boolean은 `is`, `has`, `can` 접두사

### 예시

```java
// ✅ 좋은 예
String userName;
int orderCount;
boolean isActive;
boolean hasPermission;
List<User> users;

// ❌ 나쁜 예
String s;
int cnt;
boolean flag;
List<User> list;
```

### 상수 네이밍

```java
// SCREAMING_SNAKE_CASE 사용
public static final int MAX_RETRY_COUNT = 3;
public static final String DEFAULT_ROLE = "USER";
```

---

## 🗃️ DTO 필드 네이밍

### Request DTO

```java
public record CreateUserRequest(
    String email,           // 필드명은 camelCase
    String password,
    String nickname
) {}
```

### Response DTO

```java
public record UserResponse(
    Long id,
    String email,
    String nickname,
    LocalDateTime createdAt  // 날짜는 ~At 접미사
) {}
```

---

## ✅ 체크리스트

- [ ] 클래스명이 PascalCase인가?
- [ ] 메서드/변수명이 camelCase인가?
- [ ] 상수가 SCREAMING_SNAKE_CASE인가?
- [ ] 모듈별 클래스 네이밍 패턴을 따르는가?
- [ ] 메서드명이 동사로 시작하는가?
- [ ] 의미 없는 이름(s, temp, flag)을 사용하지 않았는가?
