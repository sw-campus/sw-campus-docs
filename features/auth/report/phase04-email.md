# Phase 04: 이메일 인증 - 구현 보고서

> 작성일: 2025-12-07
> 소요 시간: 약 2시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| MailSender 인터페이스 구현 | ✅ | domain 레이어 |
| SmtpMailSender 구현체 | ✅ | api 레이어 (Spring Mail) |
| EmailService 구현 | ✅ | 인증 발송/검증/상태 확인 |
| AuthController 이메일 API 추가 | ✅ | 3개 엔드포인트 |
| 요청/응답 DTO 구현 | ✅ | EmailSendRequest, EmailStatusResponse |
| 예외 클래스 추가 | ✅ | EmailVerificationExpiredException, MailSendException |
| EmailServiceTest 작성 | ✅ | 6개 테스트 케이스 |
| AuthControllerEmailTest 작성 | ✅ | 5개 테스트 케이스 |
| Gmail SMTP 연동 | ✅ | 앱 비밀번호 사용 |
| 실제 이메일 발송/인증 테스트 | ✅ | Postman 검증 완료 |

---

## 2. 생성/변경 파일 목록

### 2.1 생성된 파일

| 파일 | 위치 | 설명 |
|------|------|------|
| `MailSender.java` | domain/auth | 메일 발송 인터페이스 |
| `EmailService.java` | domain/auth | 이메일 인증 비즈니스 로직 |
| `EmailVerificationExpiredException.java` | domain/auth/exception | 인증 만료 예외 |
| `MailSendException.java` | domain/auth/exception | 메일 발송 실패 예외 |
| `EmailServiceTest.java` | domain/test/auth | EmailService 단위 테스트 |
| `SmtpMailSender.java` | api/mail | SMTP 메일 발송 구현체 |
| `AuthController.java` | api/auth | 인증 컨트롤러 (이메일 API) |
| `EmailSendRequest.java` | api/auth/request | 이메일 발송 요청 DTO |
| `EmailStatusResponse.java` | api/auth/response | 이메일 상태 응답 DTO |
| `MessageResponse.java` | api/auth/response | 공통 메시지 응답 DTO |
| `AuthControllerEmailTest.java` | api/test/auth | 컨트롤러 테스트 |

### 2.2 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `sw-campus-api/build.gradle` | Spring Boot Mail 의존성 추가 |
| `application.yml` | SMTP 설정 추가 (Gmail) |
| `application-test.yml` | 테스트용 설정 추가 |
| `SecurityConfig.java` | `/api/v1/auth/**` permitAll 유지 |
| `GlobalExceptionHandler.java` | 이메일 관련 예외 핸들러 추가 |
| `EmailVerificationRepository.java` | `findByToken()`, `findByEmailAndVerified()` 메서드 추가 |
| `EmailVerificationRepositoryImpl.java` | 추가된 메서드 구현 |
| `EmailVerificationJpaRepository.java` | JPA 쿼리 메서드 추가 |

---

## 3. API 명세

### 3.1 이메일 인증 발송
```
POST /api/v1/auth/email/send
Content-Type: application/json

Request:
{
  "email": "user@example.com"
}

Response (200 OK):
{
  "message": "인증 메일이 발송되었습니다"
}
```

### 3.2 이메일 인증 처리
```
GET /api/v1/auth/email/verify?token={uuid}

Response (302 Found):
- 성공: Location: {frontendUrl}/signup?verified=true
- 실패: Location: {frontendUrl}/signup?error=invalid_token
```

### 3.3 이메일 인증 상태 확인
```
GET /api/v1/auth/email/status?email={email}

Response (200 OK):
{
  "email": "user@example.com",
  "verified": true
}
```

---

## 4. Plan 대비 변경 사항

### 4.1 SmtpMailSender 위치
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| `infra/mail` 모듈 | `api/mail` 패키지 | 별도 모듈 생성 대신 api 모듈에 배치 (YAGNI) |

### 4.2 인증 토큰 방식
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| 토큰 링크 방식 | 토큰 링크 방식 | 동일 (UUID 기반) |

### 4.3 리다이렉트 경로
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| `/signup?verified=true` | `/signup?verified=true` | 동일 |
| `/signup?error=invalid_token` | `/signup?error=invalid_token` | 동일 |

### 4.4 추가 구현 사항
| 항목 | 설명 |
|------|------|
| 만료 검증 | `verifyEmail()` 에서 `isExpired()` 체크 추가 |
| 이메일 템플릿 | HTML 스타일링 개선 |
| MessageResponse | 공통 응답 DTO 추가 |

---

## 5. 테스트 결과

### 5.1 EmailServiceTest (6개 테스트)

```
✅ 인증 메일 발송
  - 인증 메일을 발송할 수 있다
  - 이미 가입된 이메일은 인증 발송 실패

✅ 이메일 인증
  - 이메일 인증을 완료할 수 있다
  - 잘못된 토큰은 인증 실패
  - 만료된 토큰은 인증 실패

✅ 인증 상태 확인
  - 인증 상태를 확인할 수 있다
```

### 5.2 AuthControllerEmailTest (5개 테스트)

```
✅ 이메일 발송 API
  - POST /api/v1/auth/email/send - 인증 메일 발송 성공
  - POST /api/v1/auth/email/send - 유효하지 않은 이메일 형식

✅ 이메일 인증 API
  - GET /api/v1/auth/email/verify - 토큰 인증 성공 (302 리다이렉트)
  - GET /api/v1/auth/email/verify - 잘못된 토큰 (302 에러 리다이렉트)

✅ 인증 상태 API
  - GET /api/v1/auth/email/status - 인증 상태 확인
```

### 5.3 실제 테스트 결과

```bash
# Gmail로 실제 이메일 발송 테스트
curl -X POST http://localhost:8080/api/v1/auth/email/send \
  -H "Content-Type: application/json" \
  -d '{"email": "zion.geek.py@gmail.com"}'
# → 이메일 수신 확인 ✅

# 이메일 인증 테스트
curl "http://localhost:8080/api/v1/auth/email/verify?token={token}"
# → 302 Redirect to /signup?verified=true ✅

# 인증 상태 확인
curl "http://localhost:8080/api/v1/auth/email/status?email=zion.geek.py@gmail.com"
# → {"email":"zion.geek.py@gmail.com","verified":true} ✅
```

---

## 6. 설정 파일

### 6.1 application.yml (SMTP 설정)
```yaml
spring:
  mail:
    host: smtp.gmail.com
    port: 587
    username: ${MAIL_USERNAME}
    password: ${MAIL_PASSWORD}
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: true

app:
  frontend-url: http://localhost:3000
```

---

## 7. 비즈니스 로직 정리

### 7.1 이메일 발송 플로우
```
1. 이미 가입된 이메일인지 확인 (members 테이블)
2. 기존 인증 정보 삭제 (재발송 대응)
3. 새 EmailVerification 생성 (UUID 토큰, 24시간 만료)
4. DB 저장
5. 인증 링크 포함 이메일 발송
```

### 7.2 이메일 인증 플로우
```
1. 토큰으로 EmailVerification 조회
2. 만료 여부 확인
3. verified = true로 변경
4. 프론트엔드로 302 리다이렉트
```

### 7.3 재발송 동작
- 이메일 재발송 시 기존 인증 기록 삭제 후 새로 생성
- 이전 토큰은 무효화됨
- 회원가입 완료 전까지 재발송 가능

---

## 8. 다음 Phase

→ [Phase 05: 회원가입 - 일반](../plan/phase05-signup.md)

---

## 9. 참고 사항

- Gmail SMTP 사용 시 **앱 비밀번호** 필요 (2단계 인증 활성화 후 생성)
- 프론트엔드 미구현으로 인증 링크 클릭 시 ECONNREFUSED 발생 (정상)
- 이메일 인증 상태 API는 인증 없이 접근 가능 (공개 API)
