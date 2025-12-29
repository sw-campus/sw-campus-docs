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

## 📤 Multipart 파일 업로드 처리

> ⚠️ **중요**: `@ModelAttribute`와 `MultipartFile`을 함께 사용하면 Swagger UI에서 파일 업로드 필드가 표시되지 않습니다.

### ❌ 잘못된 패턴 (Swagger UI 오류 발생)

```java
// @ModelAttribute + MultipartFile 조합은 Swagger에서 제대로 동작하지 않음
@PostMapping(value = "/signup", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<Response> signup(
        @Valid @ModelAttribute SignupRequest request,  // ❌ 파일 필드가 표시되지 않음
        @RequestParam("image") MultipartFile image) {
    // ...
}

// Request DTO 내부에 MultipartFile 포함해도 동일한 문제
@Getter @Setter
public class SignupRequest {
    private String email;
    private MultipartFile image;  // ❌ Swagger에서 인식 안됨
}
```

### ✅ 올바른 패턴 (@RequestPart 사용)

```java
@PostMapping(value = "/signup/organization", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
@Operation(summary = "기관 회원가입", description = "기관 사용자로 회원가입합니다.")
@ApiResponses({
    @ApiResponse(responseCode = "201", description = "회원가입 성공"),
    @ApiResponse(responseCode = "400", description = "잘못된 요청")
})
public ResponseEntity<SignupResponse> signupOrganization(
        @Parameter(description = "이메일", example = "org@example.com", required = true)
        @RequestPart(name = "email") String email,

        @Parameter(description = "비밀번호 (8자 이상)", example = "Password123!", required = true)
        @RequestPart(name = "password") String password,

        @Parameter(description = "이름", example = "김대표", required = true)
        @RequestPart(name = "name") String name,

        @Parameter(description = "기관명", example = "ABC교육원", required = true)
        @RequestPart(name = "organizationName") String organizationName,

        @Parameter(description = "재직증명서 이미지 (jpg, png)", required = true)
        @RequestPart(name = "certificateImage") MultipartFile certificateImage
) throws IOException {

    // Controller 내부에서 Request DTO 생성
    SignupRequest request = SignupRequest.builder()
            .email(email)
            .password(password)
            .name(name)
            .organizationName(organizationName)
            .certificateImage(certificateImage)
            .build();

    return ResponseEntity.status(HttpStatus.CREATED)
            .body(service.signup(request.toCommand()));
}
```

### 파일만 업로드하는 경우

```java
@PostMapping(value = "/verify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
@Operation(summary = "수료증 인증")
public ResponseEntity<VerifyResponse> verifyCertificate(
        @Parameter(description = "강의 ID", example = "1", required = true)
        @RequestPart(name = "lectureId") String lectureIdStr,

        @Parameter(description = "수료증 이미지", required = true)
        @RequestPart(name = "image") MultipartFile image
) throws IOException {
    Long lectureId = Long.parseLong(lectureIdStr);
    // ...
}
```

---

## 🔷 고급 Multipart 패턴

### JSON 문자열 + 파일 업로드 (복합 데이터)

> 복잡한 객체 구조를 Multipart로 전송해야 할 때, JSON 문자열로 받아서 파싱합니다.

```java
@PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
@Operation(summary = "강의 등록", description = "새로운 강의를 등록합니다.")
@SecurityRequirement(name = "cookieAuth")
@ApiResponses({
    @ApiResponse(responseCode = "201", description = "등록 성공"),
    @ApiResponse(responseCode = "400", description = "잘못된 요청")
})
public ResponseEntity<LectureResponse> createLecture(
        @CurrentMember MemberPrincipal member,

        // ✅ 핵심: schema 속성으로 JSON 구조를 Swagger에서 표시
        @Parameter(
            description = "강의 정보 (JSON string)",
            schema = @io.swagger.v3.oas.annotations.media.Schema(
                implementation = LectureCreateRequest.class
            )
        )
        @RequestPart("lecture") String lectureJson,

        @Parameter(description = "강의 대표 이미지 파일")
        @RequestPart(value = "image", required = false) MultipartFile image,

        @Parameter(description = "강사 이미지 파일 목록")
        @RequestPart(value = "teacherImages", required = false) List<MultipartFile> teacherImages
) throws IOException {

    // JSON 파싱
    LectureCreateRequest request = objectMapper.readValue(lectureJson, LectureCreateRequest.class);

    // 수동 유효성 검증 (@Valid가 @RequestPart String에 동작하지 않으므로)
    Set<ConstraintViolation<LectureCreateRequest>> violations = validator.validate(request);
    if (!violations.isEmpty()) {
        throw new ConstraintViolationException(violations);
    }

    // ...
}
```

**⚠️ 주의사항:**
- `@RequestPart`로 받은 JSON 문자열에는 `@Valid`가 동작하지 않음
- 반드시 `Validator`를 주입받아 수동 검증 필요
- `schema = @Schema(implementation = ...)` 없으면 Swagger에서 JSON 구조 표시 안됨

### 다중 파일 업로드 (List<MultipartFile>)

```java
@PutMapping(value = "/{lectureId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
@Operation(summary = "강의 수정")
public ResponseEntity<LectureResponse> updateLecture(
        @PathVariable Long lectureId,

        @Parameter(description = "강의 정보 (JSON string)",
            schema = @Schema(implementation = LectureUpdateRequest.class))
        @RequestPart("lecture") String lectureJson,

        @Parameter(description = "강의 대표 이미지")
        @RequestPart(value = "image", required = false) MultipartFile image,

        // ✅ 다중 파일: List<MultipartFile>
        @Parameter(description = "강사 이미지 목록 (신규 강사 수와 일치해야 함)")
        @RequestPart(value = "teacherImages", required = false) List<MultipartFile> teacherImages
) throws IOException {
    // ...
}
```

### 다수의 개별 파일 필드 (named files)

> 파일 개수가 고정되어 있고 각각 의미가 다른 경우

```java
@PatchMapping(value = "/organization", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
@Operation(summary = "기관 정보 수정")
public ResponseEntity<Void> updateOrganization(
        @CurrentMember MemberPrincipal member,

        @Parameter(description = "기관명", example = "SW Campus")
        @RequestPart(name = "organizationName") String organizationName,

        @Parameter(description = "기관 설명")
        @RequestPart(name = "description", required = false) String description,

        @Parameter(description = "기관 로고 이미지")
        @RequestPart(name = "logo", required = false) MultipartFile logo,

        // ✅ 개별 명명된 파일 필드들
        @Parameter(description = "시설 이미지 1")
        @RequestPart(name = "facilityImage1", required = false) MultipartFile facilityImage1,

        @Parameter(description = "시설 이미지 2")
        @RequestPart(name = "facilityImage2", required = false) MultipartFile facilityImage2,

        @Parameter(description = "시설 이미지 3")
        @RequestPart(name = "facilityImage3", required = false) MultipartFile facilityImage3,

        @Parameter(description = "시설 이미지 4")
        @RequestPart(name = "facilityImage4", required = false) MultipartFile facilityImage4
) {
    // ...
}
```

### 숫자 타입 파싱 시 예외 처리

> `@RequestPart`로 받은 String을 숫자로 파싱할 때는 반드시 예외 처리 필요

```java
@PostMapping(value = "/signup/organization", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<Response> signupOrganization(
        // ... 다른 필드들

        @Parameter(description = "기관 ID (기존 기관 선택 시)", example = "1")
        @RequestPart(name = "organizationId", required = false) String organizationIdStr
) {
    // ✅ 올바른 파싱 (예외 처리)
    Long organizationId = null;
    if (organizationIdStr != null && !organizationIdStr.isBlank()) {
        try {
            organizationId = Long.parseLong(organizationIdStr);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("유효하지 않은 기관 ID 형식입니다: " + organizationIdStr);
        }
    }

    // ❌ 잘못된 패턴 (예외 처리 없음)
    // Long organizationId = Long.parseLong(organizationIdStr);  // NumberFormatException 발생 가능
}
```

### Multipart 처리 규칙 요약

| 항목 | 규칙 |
|------|------|
| 파일 + 텍스트 필드 | `@RequestPart`로 각 필드 분리 |
| Content-Type | `MediaType.MULTIPART_FORM_DATA_VALUE` 명시 |
| 숫자 타입 | String으로 받아서 파싱 + **try-catch 필수** |
| 파라미터 설명 | 각 필드에 `@Parameter` 추가 |
| Request DTO | Controller 내부에서 Builder로 생성 |
| JSON 문자열 | `schema = @Schema(implementation = ...)` 필수 |
| JSON 유효성 검증 | `Validator` 수동 검증 필수 |
| 다중 파일 | `List<MultipartFile>` 사용 |
| 선택적 파일 | `required = false` 명시 |

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

    @Schema(description = "HTTP 상태 코드", example = "400")
    int status,

    @Schema(description = "에러 메시지", example = "잘못된 요청입니다")
    String message,

    @Schema(description = "발생 시각", example = "2025-12-09T12:00:00")
    LocalDateTime timestamp

) {}
```

---

## ⚠️ 에러 응답 문서화 (중요)

> **필수**: 모든 에러 응답(400, 401, 403, 404, 409 등)에는 반드시 `content`와 `examples`를 추가해야 합니다.
> 이를 통해 Swagger UI에서 실제 에러 응답의 형태와 예시 메시지를 확인할 수 있습니다.

### ❌ 잘못된 패턴 (examples 없음)

```java
@ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공"),
    @ApiResponse(responseCode = "401", description = "인증 필요"),  // ❌ content 없음
    @ApiResponse(responseCode = "403", description = "권한 없음")   // ❌ content 없음
})
```

위 패턴은 Swagger에서 에러 응답의 실제 형태를 보여주지 않아, 클라이언트 개발자가 에러 처리를 어떻게 해야 할지 알기 어렵습니다.

### ✅ 올바른 패턴 (content + examples 포함)

```java
import com.swcampus.api.exception.ErrorResponse;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;

@ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공"),
    @ApiResponse(responseCode = "401", description = "인증 필요",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class),
            examples = @ExampleObject(value = """
                {"status": 401, "message": "인증이 필요합니다", "timestamp": "2025-12-09T12:00:00"}
                """))),
    @ApiResponse(responseCode = "403", description = "권한 없음",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class),
            examples = @ExampleObject(value = """
                {"status": 403, "message": "접근 권한이 없습니다", "timestamp": "2025-12-09T12:00:00"}
                """)))
})
```

### 상황별 에러 메시지 예시

| 응답 코드 | 상황 | 메시지 예시 |
|-----------|------|-------------|
| 400 | 유효성 검증 실패 | `잘못된 요청입니다` |
| 400 | 비밀번호 불일치 | `현재 비밀번호가 일치하지 않습니다` |
| 400 | 데이터 형식 오류 | `강의명이 일치하지 않습니다` |
| 401 | 인증 필요 | `인증이 필요합니다` |
| 403 | 권한 없음 (일반) | `접근 권한이 없습니다` |
| 403 | 관리자 전용 | `관리자 권한이 필요합니다` |
| 403 | 일반 사용자 전용 | `일반 사용자만 접근할 수 있습니다` |
| 403 | 기관 회원 전용 | `기관 회원만 접근할 수 있습니다` |
| 404 | 리소스 없음 (일반) | `리소스를 찾을 수 없습니다` |
| 404 | 특정 리소스 없음 | `강의를 찾을 수 없습니다`, `사용자를 찾을 수 없습니다` |
| 409 | 중복 | `이미 존재합니다`, `이미 장바구니에 존재합니다` |

### 전체 예시 (Controller)

```java
@RestController
@RequestMapping("/api/v1/mypage")
@RequiredArgsConstructor
@Tag(name = "마이페이지", description = "마이페이지 관련 API")
@SecurityRequirement(name = "cookieAuth")
public class MypageController {

    @Operation(summary = "설문조사 조회", description = "강의 추천을 위한 설문조사 정보를 조회합니다.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 필요",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class),
                examples = @ExampleObject(value = """
                    {"status": 401, "message": "인증이 필요합니다", "timestamp": "2025-12-09T12:00:00"}
                    """))),
        @ApiResponse(responseCode = "403", description = "일반 사용자가 아님",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class),
                examples = @ExampleObject(value = """
                    {"status": 403, "message": "일반 사용자만 접근할 수 있습니다", "timestamp": "2025-12-09T12:00:00"}
                    """)))
    })
    @GetMapping("/survey")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<SurveyResponse> getSurvey(@CurrentMember MemberPrincipal member) {
        // ...
    }

    @Operation(summary = "설문조사 저장", description = "설문조사 정보를 저장합니다.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "저장 성공"),
        @ApiResponse(responseCode = "400", description = "잘못된 요청",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class),
                examples = @ExampleObject(value = """
                    {"status": 400, "message": "잘못된 요청입니다", "timestamp": "2025-12-09T12:00:00"}
                    """))),
        @ApiResponse(responseCode = "401", description = "인증 필요",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class),
                examples = @ExampleObject(value = """
                    {"status": 401, "message": "인증이 필요합니다", "timestamp": "2025-12-09T12:00:00"}
                    """))),
        @ApiResponse(responseCode = "403", description = "일반 사용자가 아님",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class),
                examples = @ExampleObject(value = """
                    {"status": 403, "message": "일반 사용자만 접근할 수 있습니다", "timestamp": "2025-12-09T12:00:00"}
                    """)))
    })
    @PutMapping("/survey")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<Void> saveSurvey(...) {
        // ...
    }
}
```

### 필수 Import

```java
import com.swcampus.api.exception.ErrorResponse;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
```

---

## 🔒 인증 API 표시

### Controller 전체가 인증 필요한 경우 (Class-level)

> 마이페이지, 관리자 API 등 모든 엔드포인트가 인증 필요한 경우

```java
@RestController
@RequestMapping("/api/v1/mypage")
@RequiredArgsConstructor
@Tag(name = "마이페이지", description = "마이페이지 관련 API")
@SecurityRequirement(name = "cookieAuth")  // ✅ 클래스 레벨에 선언
public class MypageController {

    // 모든 메서드에 자동 적용됨
    @GetMapping("/profile")
    @Operation(summary = "내 정보 조회")
    public ResponseEntity<ProfileResponse> getProfile(...) { }

    @PatchMapping("/profile")
    @Operation(summary = "내 정보 수정")
    public ResponseEntity<Void> updateProfile(...) { }
}
```

```java
// 관리자 API 예시
@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@Tag(name = "Admin", description = "관리자 API")
@SecurityRequirement(name = "cookieAuth")  // ✅ 관리자 API는 반드시 인증 필요
public class AdminController {
    // ...
}
```

### 일부 메서드만 인증 필요한 경우 (Method-level)

```java
@RestController
@RequestMapping("/api/v1/reviews")
@Tag(name = "Review", description = "리뷰 API")
public class ReviewController {

    // 인증 불필요
    @GetMapping("/{lectureId}")
    @Operation(summary = "강의 리뷰 목록 조회")
    public ResponseEntity<List<ReviewResponse>> getReviews(...) { }

    // ✅ 인증 필요 (메서드 레벨)
    @PostMapping
    @Operation(summary = "리뷰 작성")
    @SecurityRequirement(name = "cookieAuth")
    public ResponseEntity<ReviewResponse> createReview(...) { }
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

### @SecurityRequirement 사용 규칙

| 상황 | 적용 위치 | 예시 |
|------|----------|------|
| 모든 메서드 인증 필요 | Class-level | 마이페이지, 관리자 API |
| 일부 메서드만 인증 필요 | Method-level | 리뷰 API (조회는 공개, 작성은 인증) |
| 인증 불필요 | 생략 | 로그인, 회원가입, 공개 조회 |

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

### Controller (필수)

- [ ] `@Tag`로 API 그룹 분류했는가?
- [ ] 모든 메서드에 `@Operation(summary = "...")` 있는가?
- [ ] 주요 응답 코드에 `@ApiResponse` 있는가?
- [ ] 인증 필요 API에 `@SecurityRequirement` 있는가? (Class 또는 Method 레벨)

### Multipart API (필수)

- [ ] `@RequestPart`로 각 필드를 분리했는가? (`@ModelAttribute` 금지)
- [ ] 모든 파라미터에 `@Parameter(description = "...")` 있는가?
- [ ] 선택적 파일에 `required = false` 명시했는가?
- [ ] JSON 문자열에 `schema = @Schema(implementation = ...)` 있는가?
- [ ] JSON 파싱 후 `Validator`로 수동 검증하는가?
- [ ] 숫자 파싱 시 `try-catch`로 예외 처리하는가?

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
| `@ModelAttribute` + `MultipartFile` | Swagger UI에서 파일 필드 표시 안됨 |
| JSON 문자열에 `schema` 속성 누락 | Swagger에서 JSON 구조 표시 안됨 |
| `@RequestPart` String 숫자 파싱 시 예외처리 누락 | NumberFormatException 발생 |
| `@Valid` on `@RequestPart` String | 동작하지 않음, `Validator` 수동 검증 필요 |
| 인증 API에 `@SecurityRequirement` 누락 | 프론트엔드가 인증 필요 여부 알 수 없음 |
| description 없는 `@Operation` | 무의미한 문서 |
| 영어 설명 | 한글로 명확하게 |
| `required = false` 누락 (선택적 파일) | Swagger에서 필수로 표시됨 |

---

## 💡 Best Practice

1. **summary는 짧게**: 10자 이내로 동작을 설명
2. **description은 상세하게**: 필요시 사용법, 주의사항 포함
3. **example은 실제 값처럼**: 의미 있는 예시 사용
4. **에러 응답도 문서화**: 클라이언트가 에러 처리 가능하도록
5. **인증 여부 명시**: Class-level 또는 Method-level `@SecurityRequirement`
6. **Multipart JSON은 schema 필수**: `@Parameter(schema = @Schema(implementation = ...))`
7. **수동 검증 습관화**: `@RequestPart` String으로 받은 JSON은 `Validator` 사용
8. **숫자 파싱은 안전하게**: try-catch + 의미 있는 에러 메시지
