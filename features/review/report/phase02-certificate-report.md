# Phase 02: 수료증 인증 API - 구현 완료 리포트

> 작성일: 2025년 12월 11일

## 개요

OCR 연동을 통한 수료증 확인/인증 API를 구현했습니다.

---

## 구현 결과

### 1. Infra 모듈 (sw-campus-infra/ocr)

| 파일 | 경로 | 설명 |
|------|------|------|
| `OcrClientImpl.java` | `infra/ocr/` | OCR 서버 호출 구현체 |
| `OcrConfig.java` | `infra/ocr/` | RestTemplate Bean 설정 |
| `OcrResponse.java` | `infra/ocr/` | OCR 응답 DTO (text, lines, scores) |

### 2. Domain 모듈 (sw-campus-domain)

| 파일 | 경로 | 설명 |
|------|------|------|
| `OcrClient.java` | `domain/ocr/` | OCR 클라이언트 인터페이스 |
| `CertificateService.java` | `domain/certificate/` | 수료증 확인/인증 서비스 |

### 3. API 모듈 (sw-campus-api)

| 파일 | 경로 | 설명 |
|------|------|------|
| `CertificateController.java` | `api/certificate/` | REST 컨트롤러 |
| `CertificateCheckResponse.java` | `api/certificate/response/` | 인증 여부 확인 응답 DTO |
| `CertificateVerifyResponse.java` | `api/certificate/response/` | 인증 결과 응답 DTO |

### 4. 예외 처리

| 파일 | 변경 사항 |
|------|----------|
| `GlobalExceptionHandler.java` | `CertificateLectureMismatchException` 핸들러 추가 (400 Bad Request) |

---

## API 엔드포인트

### GET /api/v1/certificates/check

수료증 인증 여부 확인

**Request**
```
Cookie: accessToken=...
Query: lectureId=1
```

**Response (인증됨)**
```json
{
  "certified": true,
  "certificateId": 1,
  "imageUrl": "https://s3.../certificate.jpg",
  "approvalStatus": "PENDING",
  "certifiedAt": "2025-12-11T10:30:00"
}
```

**Response (미인증)**
```json
{
  "certified": false,
  "certificateId": null,
  "imageUrl": null,
  "approvalStatus": null,
  "certifiedAt": null
}
```

### POST /api/v1/certificates/verify

수료증 인증 (이미지 업로드 + OCR 검증)

**Request**
```
Cookie: accessToken=...
Content-Type: multipart/form-data

lectureId: 1 (form-data)
image: [파일] (form-data)
```

**Response (성공)**
```json
{
  "certificateId": 1,
  "lectureId": 1,
  "imageUrl": "https://s3.../certificate.jpg",
  "approvalStatus": "PENDING",
  "message": "수료증 인증이 완료되었습니다. 관리자 승인 후 후기 작성이 가능합니다."
}
```

**Response (강의명 불일치 - 400)**
```json
{
  "status": 400,
  "message": "수료증에서 해당 강의명을 찾을 수 없습니다"
}
```

---

## Plan 대비 변경 사항

### 1. RestTemplate Bean 충돌 해결

**문제:** 기존 `OAuthConfig`에 `restTemplate` Bean이 존재하여 충돌 발생

**해결:**
- `OAuthConfig.restTemplate()` → `@Primary` 추가
- `OcrConfig.ocrRestTemplate()` → Bean 이름 변경
- `OcrClientImpl` → `@Qualifier("ocrRestTemplate")` 사용

```java
// OAuthConfig.java
@Primary
@Bean
public RestTemplate restTemplate() { ... }

// OcrConfig.java
@Bean("ocrRestTemplate")
public RestTemplate ocrRestTemplate() { ... }

// OcrClientImpl.java
public OcrClientImpl(@Qualifier("ocrRestTemplate") RestTemplate restTemplate) { ... }
```

### 2. Controller 파라미터 변경 (Swagger 호환성)

**Plan 문서:**
```java
@RequestParam Long lectureId
```

**실제 구현:**
```java
@RequestPart(name = "lectureId") String lectureIdStr
```

**변경 사유:** 
- Swagger UI에서 `multipart/form-data` 전송 시 `@RequestParam`이 제대로 인식되지 않음
- `@RequestPart`로 변경하여 form-data 방식으로 수신
- `Long` → `String`으로 받아서 내부에서 파싱 (form-data 호환성)

### 3. 예외 클래스 패턴

**Plan 문서:**
```java
public class CertificateLectureMismatchException extends BusinessException {
    public CertificateLectureMismatchException() {
        super(ErrorCode.CERTIFICATE_LECTURE_MISMATCH);
    }
}
```

**실제 구현:**
```java
public class CertificateLectureMismatchException extends RuntimeException {
    public CertificateLectureMismatchException() {
        super("수료증에서 해당 강의명을 찾을 수 없습니다");
    }
}
```

**변경 사유:** Phase 01과 동일하게 기존 프로젝트의 예외 패턴을 따름

### 4. GlobalExceptionHandler 추가

**Plan에 없었던 항목:**
```java
@ExceptionHandler(CertificateLectureMismatchException.class)
public ResponseEntity<ErrorResponse> handleCertificateLectureMismatchException(
        CertificateLectureMismatchException e) {
    log.warn("수료증 검증 실패 - 강의명 불일치: {}", e.getMessage());
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(ErrorResponse.of(HttpStatus.BAD_REQUEST.value(), e.getMessage()));
}
```

### 5. CertificateAlreadyVerifiedException 미구현

**Plan 문서:** 중복 인증 시 예외 발생
**실제 구현:** 해당 예외 클래스가 존재하지 않아 미구현 (Phase 01에서 `CertificateAlreadyExistsException`으로 대체 가능)

---

## 테스트 결과

### 테스트 환경
- Spring Boot 서버: `http://localhost:8080`
- OCR 서버 (sw-campus-ai): `http://localhost:8000`
- 테스트 계정: `zion.geek.py@gmail.com`

### 테스트 시나리오

| 시나리오 | 결과 | 비고 |
|----------|------|------|
| 수료증 확인 (미인증 상태) | ✅ | `certified: false` 반환 |
| 수료증 인증 (OCR 매칭 성공) | ✅ | S3 업로드 + DB 저장 완료 |
| 수료증 확인 (인증 완료 상태) | ✅ | `certified: true` + 상세 정보 반환 |
| 수료증 인증 (OCR 매칭 실패) | ✅ | 400 + "수료증에서 해당 강의명을 찾을 수 없습니다" |

### curl 테스트 명령어

```bash
# 수료증 확인
curl -X GET "http://localhost:8080/api/v1/certificates/check?lectureId=1" \
  -H "Cookie: accessToken=..." -v

# 수료증 인증
curl -X POST "http://localhost:8080/api/v1/certificates/verify" \
  -H "Cookie: accessToken=..." \
  -F "lectureId=1" \
  -F "image=@/path/to/certificate.jpg"
```

---

## 빌드 결과

```bash
./gradlew build -x test

BUILD SUCCESSFUL in 3s
20 actionable tasks: 4 executed, 16 up-to-date
```

---

## 파일 목록

### Domain 모듈 (2개)

```
sw-campus-domain/src/main/java/com/swcampus/domain/
├── certificate/
│   └── CertificateService.java
└── ocr/
    └── OcrClient.java
```

### Infra 모듈 (3개)

```
sw-campus-infra/ocr/src/main/java/com/swcampus/infra/ocr/
├── OcrClientImpl.java
├── OcrConfig.java
└── OcrResponse.java
```

### API 모듈 (3개)

```
sw-campus-api/src/main/java/com/swcampus/api/
├── certificate/
│   ├── CertificateController.java
│   └── response/
│       ├── CertificateCheckResponse.java
│       └── CertificateVerifyResponse.java
└── exception/
    └── GlobalExceptionHandler.java (수정)
```

### 설정 파일

```
sw-campus-api/src/main/resources/config/application-local.yml
  → ocr.server.url: http://localhost:8000 추가
```

---

## 다음 Phase 준비 사항

- [ ] Phase 03: 후기 CRUD API 구현
  - ReviewService 구현
  - ReviewController 구현
  - Request/Response DTO 생성
