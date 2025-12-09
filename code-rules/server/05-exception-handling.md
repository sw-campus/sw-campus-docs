# 05. 예외 처리 규칙

> 일관된 예외 처리로 디버깅과 클라이언트 대응을 용이하게 합니다.

---

## 🏗️ 예외 구조

```
sw-campus-server/
├── sw-campus-api/
│   └── exception/
│       ├── GlobalExceptionHandler.java    # 전역 예외 핸들러
│       └── ErrorResponse.java             # 에러 응답 DTO
│
├── sw-campus-domain/
│   └── {도메인}/
│       └── exception/
│           ├── {Domain}Exception.java     # 도메인 기본 예외
│           └── {Domain}NotFoundException.java
│
└── sw-campus-shared/
    └── exception/
        ├── ErrorCode.java                 # 에러 코드 정의
        └── BusinessException.java         # 비즈니스 예외 기본 클래스
```

---

## 📋 에러 코드 정의

### shared 모듈 - ErrorCode

```java
// sw-campus-shared/.../exception/ErrorCode.java
public enum ErrorCode {
    // Common
    INVALID_INPUT(400, "C001", "잘못된 입력입니다"),
    INTERNAL_SERVER_ERROR(500, "C002", "서버 내부 오류입니다"),

    // User
    USER_NOT_FOUND(404, "U001", "사용자를 찾을 수 없습니다"),
    USER_ALREADY_EXISTS(409, "U002", "이미 존재하는 사용자입니다"),
    USER_PASSWORD_MISMATCH(400, "U003", "비밀번호가 일치하지 않습니다"),

    // Auth
    AUTH_UNAUTHORIZED(401, "A001", "인증이 필요합니다"),
    AUTH_FORBIDDEN(403, "A002", "접근 권한이 없습니다"),
    AUTH_TOKEN_EXPIRED(401, "A003", "토큰이 만료되었습니다");

    private final int status;
    private final String code;
    private final String message;

    ErrorCode(int status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }

    // getters
}
```

### 에러 코드 네이밍 규칙

| 접두사 | 도메인         |
| ------ | -------------- |
| C      | Common (공통)  |
| U      | User (사용자)  |
| A      | Auth (인증)    |
| O      | Order (주문)   |
| P      | Product (상품) |

---

## 🚨 예외 클래스 정의

### shared 모듈 - BusinessException (기본 클래스)

```java
// sw-campus-shared/.../exception/BusinessException.java
public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;

    public BusinessException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public BusinessException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }
}
```

### domain 모듈 - 도메인별 예외

```java
// sw-campus-domain/.../user/exception/UserNotFoundException.java
public class UserNotFoundException extends BusinessException {

    public UserNotFoundException() {
        super(ErrorCode.USER_NOT_FOUND);
    }

    public UserNotFoundException(Long userId) {
        super(ErrorCode.USER_NOT_FOUND,
              String.format("사용자를 찾을 수 없습니다. ID: %d", userId));
    }
}

// sw-campus-domain/.../user/exception/UserAlreadyExistsException.java
public class UserAlreadyExistsException extends BusinessException {

    public UserAlreadyExistsException(String email) {
        super(ErrorCode.USER_ALREADY_EXISTS,
              String.format("이미 존재하는 이메일입니다: %s", email));
    }
}
```

---

## 🎯 전역 예외 핸들러

### api 모듈 - GlobalExceptionHandler

```java
// sw-campus-api/.../exception/GlobalExceptionHandler.java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    // 비즈니스 예외 처리
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(
            BusinessException e) {
        log.warn("Business exception: {}", e.getMessage());

        ErrorCode errorCode = e.getErrorCode();
        return ResponseEntity
                .status(errorCode.getStatus())
                .body(ErrorResponse.of(errorCode, e.getMessage()));
    }

    // 유효성 검증 예외 처리
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(
            MethodArgumentNotValidException e) {
        log.warn("Validation exception: {}", e.getMessage());

        String message = e.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining(", "));

        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(ErrorResponse.of(ErrorCode.INVALID_INPUT, message));
    }

    // 기타 예외 처리 (예상치 못한 에러)
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleException(Exception e) {
        log.error("Unexpected exception: ", e);

        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.of(ErrorCode.INTERNAL_SERVER_ERROR));
    }
}
```

### api 모듈 - ErrorResponse

```java
// sw-campus-api/.../exception/ErrorResponse.java
public record ErrorResponse(
    String code,
    String message,
    LocalDateTime timestamp
) {
    public static ErrorResponse of(ErrorCode errorCode) {
        return new ErrorResponse(
            errorCode.getCode(),
            errorCode.getMessage(),
            LocalDateTime.now()
        );
    }

    public static ErrorResponse of(ErrorCode errorCode, String message) {
        return new ErrorResponse(
            errorCode.getCode(),
            message,
            LocalDateTime.now()
        );
    }
}
```

---

## 📝 예외 사용 예시

### Service에서 예외 던지기

```java
// sw-campus-domain/.../user/UserService.java
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public User getUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new UserNotFoundException(id));
    }

    public User createUser(CreateUserCommand command) {
        // 중복 체크
        if (userRepository.existsByEmail(command.email())) {
            throw new UserAlreadyExistsException(command.email());
        }

        User user = User.create(command.email(), command.password(), command.nickname());
        return userRepository.save(user);
    }
}
```

### API 응답 예시

```json
// 404 Not Found
{
  "code": "U001",
  "message": "사용자를 찾을 수 없습니다. ID: 999",
  "timestamp": "2025-12-01T10:30:00"
}

// 409 Conflict
{
  "code": "U002",
  "message": "이미 존재하는 이메일입니다: user@example.com",
  "timestamp": "2025-12-01T10:30:00"
}

// 400 Bad Request (유효성 검증)
{
  "code": "C001",
  "message": "email: 올바른 이메일 형식이 아닙니다, password: 비밀번호는 8~20자입니다",
  "timestamp": "2025-12-01T10:30:00"
}
```

---

## 🚫 금지 사항

### 1. 무분별한 try-catch 금지

```java
// ❌ 나쁜 예
public User getUser(Long id) {
    try {
        return userRepository.findById(id).orElseThrow();
    } catch (Exception e) {
        return null;  // 예외를 삼킴
    }
}

// ✅ 좋은 예
public User getUser(Long id) {
    return userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
}
```

### 2. 일반 Exception 던지기 금지

```java
// ❌ 나쁜 예
throw new RuntimeException("사용자를 찾을 수 없습니다");
throw new Exception("에러 발생");

// ✅ 좋은 예
throw new UserNotFoundException(userId);
throw new BusinessException(ErrorCode.USER_NOT_FOUND);
```

### 3. 에러 메시지에 민감 정보 포함 금지

```java
// ❌ 나쁜 예 - 비밀번호 노출
throw new BusinessException(ErrorCode.AUTH_FAILED,
    "비밀번호가 틀렸습니다: " + inputPassword);

// ✅ 좋은 예
throw new BusinessException(ErrorCode.AUTH_FAILED,
    "이메일 또는 비밀번호가 올바르지 않습니다");
```

---

## ✅ 체크리스트

- [ ] 도메인별 예외 클래스가 BusinessException을 상속하는가?
- [ ] ErrorCode에 에러 코드가 정의되어 있는가?
- [ ] GlobalExceptionHandler에서 예외를 처리하는가?
- [ ] 일반 Exception 대신 구체적인 예외를 던지는가?
- [ ] 에러 메시지에 민감 정보가 없는가?
- [ ] 예외 발생 시 적절한 로그를 남기는가?
