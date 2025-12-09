# 07. Swagger(OpenAPI) 문서화 규칙

> Springdoc OpenAPI를 사용하여 API 문서를 자동 생성하고 관리합니다.

---

## 📦 의존성 설정

### build.gradle (api 모듈)

```gradle
dependencies {
    // Swagger UI + OpenAPI 3.0
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.13'
}
```

---

## ⚙️ 기본 설정

### application.yml

```yaml
springdoc:
  api-docs:
    enabled: true
    path: /v3/api-docs
  swagger-ui:
    enabled: true
    path: /swagger-ui.html
    operations-sorter: method      # HTTP 메서드별 정렬
    tags-sorter: alpha             # 태그 알파벳 정렬
    try-it-out-enabled: true       # Try it out 버튼 활성화
  packages-to-scan:
    - com.swcampus.api              # 스캔할 패키지
  paths-to-match:
    - /api/**                       # 문서화할 경로
```

### 접속 URL

| 환경 | Swagger UI | OpenAPI JSON |
|------|-----------|--------------|
| Local | http://localhost:8080/swagger-ui.html | http://localhost:8080/v3/api-docs |

---

## 📋 OpenAPI 전역 설정

### OpenApiConfig.java

```java
package com.swcampus.api.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeIn;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Contact;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.annotations.servers.Server;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
    info = @Info(
        title = "SW Campus API",
        version = "1.0.0",
        description = "SW Campus 교육 플랫폼 백엔드 API",
        contact = @Contact(
            name = "SW Campus Team",
            email = "support@swcampus.com"
        )
    ),
    servers = {
        @Server(url = "http://localhost:8080", description = "Local"),
        @Server(url = "https://api.swcampus.com", description = "Production")
    }
)
@SecurityScheme(
    name = "cookieAuth",
    type = SecuritySchemeType.APIKEY,
    in = SecuritySchemeIn.COOKIE,
    paramName = "accessToken",
    description = "JWT Access Token (Cookie)"
)
public class OpenApiConfig {
}
```

---

## 🏷️ Controller 문서화

### 기본 패턴

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Tag(name = "User", description = "사용자 관리 API")
public class UserController {

    private final UserService userService;

    @GetMapping
    @Operation(
        summary = "사용자 목록 조회",
        description = "전체 사용자 목록을 페이징하여 조회합니다."
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 필요",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    public ResponseEntity<List<UserResponse>> getUserList() {
        // ...
    }

    @GetMapping("/{id}")
    @Operation(summary = "사용자 상세 조회")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "404", description = "사용자 없음")
    })
    public ResponseEntity<UserResponse> getUser(
            @Parameter(description = "사용자 ID", example = "1", required = true)
            @PathVariable Long id) {
        // ...
    }

    @PostMapping
    @Operation(summary = "사용자 생성")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "생성 성공"),
        @ApiResponse(responseCode = "400", description = "잘못된 요청"),
        @ApiResponse(responseCode = "409", description = "이메일 중복")
    })
    public ResponseEntity<UserResponse> createUser(
            @Valid @RequestBody CreateUserRequest request) {
        // ...
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "사용자 삭제")
    @SecurityRequirement(name = "cookieAuth")  // 인증 필요 표시
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "삭제 성공"),
        @ApiResponse(responseCode = "403", description = "권한 없음"),
        @ApiResponse(responseCode = "404", description = "사용자 없음")
    })
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        // ...
    }
}
```

---

## 📝 어노테이션 사용 규칙

### Controller 레벨

| 어노테이션 | 용도 | 필수 |
|-----------|------|------|
| `@Tag` | API 그룹 분류 (사이드바) | ✅ |

```java
@Tag(name = "Auth", description = "인증/인가 API")
```

### Method 레벨

| 어노테이션 | 용도 | 필수 |
|-----------|------|------|
| `@Operation` | API 설명 (summary, description) | ✅ |
| `@ApiResponses` | 응답 코드별 설명 | ✅ |
| `@SecurityRequirement` | 인증 필요 여부 | 인증 API만 |

```java
@Operation(
    summary = "로그인",                    // 간단 설명 (목록에 표시)
    description = "이메일과 비밀번호로 로그인합니다."  // 상세 설명
)
@ApiResponses({
    @ApiResponse(responseCode = "200", description = "로그인 성공"),
    @ApiResponse(responseCode = "401", description = "인증 실패")
})
@SecurityRequirement(name = "cookieAuth")  // 인증 필요한 API에만
```

### Parameter 레벨

| 어노테이션 | 용도 | 필수 |
|-----------|------|------|
| `@Parameter` | 파라미터 설명 | 선택 |

```java
@Parameter(description = "사용자 ID", example = "1", required = true)
@PathVariable Long id

@Parameter(description = "페이지 번호", example = "0")
@RequestParam(defaultValue = "0") int page
```

---

## 📦 DTO 문서화

### Request DTO

```java
@Schema(description = "회원가입 요청")
public record SignupRequest(

    @Schema(description = "이메일", example = "user@example.com", required = true)
    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    String email,

    @Schema(description = "비밀번호", example = "Password123!", required = true, minLength = 8, maxLength = 20)
    @NotBlank(message = "비밀번호는 필수입니다")
    @Size(min = 8, max = 20)
    String password,

    @Schema(description = "닉네임", example = "홍길동", required = true, minLength = 2, maxLength = 10)
    @NotBlank(message = "닉네임은 필수입니다")
    @Size(min = 2, max = 10)
    String nickname

) {}
```

### Response DTO

```java
@Schema(description = "사용자 응답")
public record UserResponse(

    @Schema(description = "사용자 ID", example = "1")
    Long id,

    @Schema(description = "이메일", example = "user@example.com")
    String email,

    @Schema(description = "닉네임", example = "홍길동")
    String nickname,

    @Schema(description = "권한", example = "USER", allowableValues = {"USER", "ADMIN", "PROVIDER"})
    String role,

    @Schema(description = "생성일시", example = "2025-12-01T10:30:00")
    LocalDateTime createdAt

) {
    public static UserResponse from(User user) {
        return new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getNickname(),
            user.getRole().name(),
            user.getCreatedAt()
        );
    }
}
```

### Error Response

```java
@Schema(description = "에러 응답")
public record ErrorResponse(

    @Schema(description = "에러 코드", example = "USER_NOT_FOUND")
    String code,

    @Schema(description = "에러 메시지", example = "사용자를 찾을 수 없습니다")
    String message,

    @Schema(description = "발생 시각", example = "2025-12-01T10:30:00")
    LocalDateTime timestamp

) {}
```

---

## 🔒 인증 API 표시

### 인증이 필요한 API

```java
@SecurityRequirement(name = "cookieAuth")
@DeleteMapping("/{id}")
public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
    // ...
}
```

### 인증이 필요 없는 API

```java
// @SecurityRequirement 생략
@PostMapping("/login")
public ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
    // ...
}
```

---

## 📁 파일 위치

```
sw-campus-api/
└── src/main/java/com/swcampus/api/
    └── config/
        └── OpenApiConfig.java    # 전역 설정
    └── auth/
        ├── AuthController.java   # @Tag, @Operation 적용
        └── request/
            └── LoginRequest.java # @Schema 적용
        └── response/
            └── LoginResponse.java
```

---

## ✅ 체크리스트

### Controller

- [ ] `@Tag`로 API 그룹 분류했는가?
- [ ] 모든 메서드에 `@Operation(summary = "...")` 있는가?
- [ ] 주요 응답 코드에 `@ApiResponse` 있는가?
- [ ] 인증 필요 API에 `@SecurityRequirement` 있는가?

### DTO

- [ ] 클래스에 `@Schema(description = "...")` 있는가?
- [ ] 필드에 `@Schema(description, example)` 있는가?
- [ ] 필수 필드에 `required = true` 표시했는가?

### 일반

- [ ] Swagger UI에서 API 테스트가 가능한가?
- [ ] 설명이 한글로 명확하게 작성되었는가?

---

## 📌 네이밍 컨벤션 (Tag 이름)

| 도메인 | Tag name | description |
|--------|----------|-------------|
| 인증 | Auth | 인증/인가 API |
| 사용자 | User | 사용자 관리 API |
| 기관 | Organization | 기관 관리 API |
| 강의 | Lecture | 강의 관리 API |
| 리뷰 | Review | 리뷰 관리 API |
| 찜 | Wishlist | 찜 목록 API |
| 비교 | Compare | 강의 비교 API |

---

## 🚫 하지 말 것

| 금지 사항 | 이유 |
|----------|------|
| 모든 필드에 어노테이션 | 핵심 필드만 문서화 |
| 영어 설명 | 한글로 명확하게 |
| description 없는 @Operation | 무의미한 문서 |
| 중복 설명 | DRY 원칙 위반 |

---

## 💡 Best Practice

1. **summary는 짧게**: 10자 이내로 동작을 설명
2. **description은 상세하게**: 필요시 사용법, 주의사항 포함
3. **example은 실제 값처럼**: 의미 있는 예시 사용
4. **에러 응답도 문서화**: 클라이언트가 에러 처리 가능하도록
5. **인증 여부 명시**: 프론트엔드 개발 편의성
