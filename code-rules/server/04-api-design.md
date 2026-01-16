# 04. REST API 설계 규칙

> 일관된 REST API 설계로 클라이언트 개발 효율을 높입니다.

---

## 🌐 URL 설계

### 기본 규칙

| 규칙               | 예시                                           |
| ------------------ | ---------------------------------------------- |
| 소문자 사용        | `/api/users` (~~`/api/Users`~~)                |
| 복수형 명사        | `/api/users` (~~`/api/user`~~)                 |
| 케밥 케이스        | `/api/user-profiles` (~~`/api/userProfiles`~~) |
| 동사 사용 금지     | `/api/users` (~~`/api/getUsers`~~)             |
| 마지막 슬래시 금지 | `/api/users` (~~`/api/users/`~~)               |

### URL 구조

```
/api/{version}/{resource}/{id}/{sub-resource}
```

**예시:**

```
GET    /api/v1/users              # 사용자 목록
GET    /api/v1/users/1            # 사용자 상세
POST   /api/v1/users              # 사용자 생성
PUT    /api/v1/users/1            # 사용자 수정
DELETE /api/v1/users/1            # 사용자 삭제
GET    /api/v1/users/1/orders     # 사용자의 주문 목록
```

---

## 📨 HTTP Method 사용

| Method | 용도      | 멱등성 | 요청 Body | 응답 Body    |
| ------ | --------- | ------ | --------- | ------------ |
| GET    | 조회      | ✅     | ❌        | ✅           |
| POST   | 생성      | ❌     | ✅        | ✅           |
| PUT    | 전체 수정 | ✅     | ✅        | ✅           |
| PATCH  | 부분 수정 | ✅     | ✅        | ✅           |
| DELETE | 삭제      | ✅     | ❌        | ❌ (또는 ✅) |

---

## 📊 HTTP Status Code

### 성공 응답

| 코드           | 상황                  | 예시            |
| -------------- | --------------------- | --------------- |
| 200 OK         | 조회/수정 성공        | GET, PUT, PATCH |
| 201 Created    | 생성 성공             | POST            |
| 204 No Content | 삭제 성공 (본문 없음) | DELETE          |

### 클라이언트 에러

| 코드             | 상황        | 예시             |
| ---------------- | ----------- | ---------------- |
| 400 Bad Request  | 잘못된 요청 | 유효성 검증 실패 |
| 401 Unauthorized | 인증 필요   | 토큰 없음/만료   |
| 403 Forbidden    | 권한 없음   | 접근 권한 부족   |
| 404 Not Found    | 리소스 없음 | 존재하지 않는 ID |
| 409 Conflict     | 충돌        | 중복 데이터      |

### 서버 에러

| 코드                      | 상황           |
| ------------------------- | -------------- |
| 500 Internal Server Error | 서버 내부 오류 |

---

## 📋 요청/응답 형식

### Request Body (POST, PUT, PATCH)

```java
// CreateUserRequest.java
public record CreateUserRequest(
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    String email,

    @NotBlank(message = "비밀번호는 필수입니다")
    @Size(min = 8, max = 20, message = "비밀번호는 8~20자입니다")
    String password,

    @NotBlank(message = "닉네임은 필수입니다")
    @Size(min = 2, max = 10, message = "닉네임은 2~10자입니다")
    String nickname
) {}
```

### Response Body

#### 단건 응답

```json
{
  "id": 1,
  "email": "user@example.com",
  "nickname": "홍길동",
  "createdAt": "2025-12-01T10:30:00"
}
```

#### 목록 응답 (페이징)

```json
{
  "content": [
    {
      "id": 1,
      "email": "user1@example.com",
      "nickname": "사용자1"
    },
    {
      "id": 2,
      "email": "user2@example.com",
      "nickname": "사용자2"
    }
  ],
  "page": 0,
  "size": 10,
  "totalElements": 100,
  "totalPages": 10
}
```

#### 에러 응답

```json
{
  "code": "USER_NOT_FOUND",
  "message": "사용자를 찾을 수 없습니다",
  "timestamp": "2025-12-01T10:30:00"
}
```

---

## 🎮 Controller 작성 규칙

### 기본 구조

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    // GET /api/v1/users
    @GetMapping
    public ResponseEntity<List<UserResponse>> getUserList() {
        List<User> users = userService.getUserList();
        return ResponseEntity.ok(UserResponse.from(users));
    }

    // GET /api/v1/users/{id}
    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUser(@PathVariable("id") Long id) {
        User user = userService.getUser(id);
        return ResponseEntity.ok(UserResponse.from(user));
    }

    // POST /api/v1/users
    @PostMapping
    public ResponseEntity<UserResponse> createUser(
            @Valid @RequestBody CreateUserRequest request) {
        User user = userService.createUser(request.toCommand());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(UserResponse.from(user));
    }

    // PUT /api/v1/users/{id}
    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> updateUser(
            @PathVariable("id") Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        User user = userService.updateUser(id, request.toCommand());
        return ResponseEntity.ok(UserResponse.from(user));
    }

    // DELETE /api/v1/users/{id}
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable("id") Long id) {
        userService.deleteUser(id);
        return ResponseEntity.noContent().build();
    }
}
```

### 규칙

| 규칙                  | 설명                             |
| --------------------- | -------------------------------- |
| `@Valid` 사용         | Request DTO에 유효성 검증        |
| `ResponseEntity` 사용 | 명시적인 상태 코드 반환          |
| DTO 변환              | Controller에서 Domain ↔ DTO 변환 |
| 비즈니스 로직 금지    | Service로 위임                   |
| **명시적 파라미터 이름** | `@PathVariable`, `@RequestParam`에 name 속성 필수 |

### @PathVariable, @RequestParam 명시적 이름 지정 (필수)

멀티모듈 환경에서 `-parameters` 컴파일러 플래그가 일관되게 적용되지 않을 수 있으므로, **name 속성을 명시적으로 지정**합니다.

```java
// ✅ 올바른 예: 명시적 name 지정
@PathVariable("id") Long id
@PathVariable("userId") Long userId
@RequestParam("page") int page
@RequestParam(name = "size", defaultValue = "10") int size

// ❌ 금지: name 생략 (런타임 에러 발생 가능)
@PathVariable Long id
@RequestParam int page
```

**에러 예시** (name 생략 시):
```
Name for argument of type [int] not specified, and parameter name information
not available via reflection. Ensure that the compiler uses the '-parameters' flag.
```

---

## 🔍 쿼리 파라미터

### 페이징

```
GET /api/v1/users?page=0&size=10&sort=createdAt,desc
```

| 파라미터 | 설명                     | 기본값         |
| -------- | ------------------------ | -------------- |
| page     | 페이지 번호 (0부터 시작) | 0              |
| size     | 페이지 크기              | 10             |
| sort     | 정렬 기준                | createdAt,desc |

### 필터링

```
GET /api/v1/users?status=ACTIVE&role=ADMIN
```

### 검색

```
GET /api/v1/users?keyword=홍길동
GET /api/v1/users?email=user@example.com
```

---

## ✅ 체크리스트

- [ ] URL이 소문자, 복수형, 케밥 케이스인가?
- [ ] HTTP Method가 적절한가?
- [ ] Status Code가 적절한가?
- [ ] Request에 `@Valid`가 있는가?
- [ ] ResponseEntity를 사용하는가?
- [ ] Controller에 비즈니스 로직이 없는가?
- [ ] `@PathVariable`, `@RequestParam`에 name 속성이 명시되어 있는가?
