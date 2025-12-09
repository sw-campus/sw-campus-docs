# Phase 09: 비밀번호 관리 - 구현 보고서

> 작성일: 2025-12-09
> 소요 시간: 약 1시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| PasswordService 구현 | ✅ | 비밀번호 변경 + 임시 비밀번호 발급 |
| PasswordController 구현 | ✅ | 2개 엔드포인트 |
| PasswordChangeRequest 구현 | ✅ | @Valid 검증 포함 |
| TemporaryPasswordRequest 구현 | ✅ | @Valid 검증 포함 |
| PasswordServiceTest 작성 | ✅ | 6개 테스트 케이스 |
| PasswordControllerTest 작성 | ✅ | 4개 테스트 케이스 |
| OAuth 사용자 처리 | ✅ | 비밀번호 null 체크 |
| 보안 처리 | ✅ | 이메일 미존재 시 동일 응답 |
| 전체 테스트 통과 | ✅ | ./gradlew clean test |

---

## 2. 생성/변경 파일 목록

### 2.1 생성된 파일

| 파일 | 위치 | 설명 |
|------|------|------|
| `PasswordService.java` | domain/auth | 비밀번호 관리 서비스 |
| `PasswordController.java` | api/auth | 비밀번호 API 컨트롤러 |
| `PasswordChangeRequest.java` | api/auth/request | 비밀번호 변경 요청 DTO |
| `TemporaryPasswordRequest.java` | api/auth/request | 임시 비밀번호 요청 DTO |
| `PasswordServiceTest.java` | domain/test/auth | 서비스 단위 테스트 |
| `PasswordControllerTest.java` | api/test/auth | 컨트롤러 통합 테스트 |

---

## 3. API 명세

### 3.1 비밀번호 변경

```
PATCH /api/v1/auth/password

Request:
- Cookie: accessToken (필수)
- Body:
  {
    "currentPassword": "OldPassword1!",
    "newPassword": "NewPassword1!"
  }

Response:
- 200 OK
- 400 Bad Request (현재 비밀번호 불일치, 정책 위반, OAuth 사용자)
- 401 Unauthorized (미로그인)
```

### 3.2 임시 비밀번호 발급

```
POST /api/v1/auth/password/temporary

Request:
- Body:
  {
    "email": "user@example.com"
  }

Response:
- 200 OK
  {
    "message": "임시 비밀번호가 이메일로 발송되었습니다"
  }

Note: 보안을 위해 이메일 존재 여부와 관계없이 동일 응답 반환
```

---

## 4. 비즈니스 로직 흐름

### 4.1 비밀번호 변경

```
1. Access Token에서 userId 추출
2. 사용자 조회
3. OAuth 사용자 체크 (password == null → 예외)
4. 현재 비밀번호 검증 (BCrypt.matches)
5. 새 비밀번호 정책 검증 (8자 이상, 특수문자)
6. 새 비밀번호 암호화 (BCrypt)
7. DB 저장
```

### 4.2 임시 비밀번호 발급

```
1. 이메일로 사용자 조회
2. 사용자 없음 또는 OAuth 사용자 → 조용히 종료 (보안)
3. 임시 비밀번호 생성 (12자리 랜덤)
4. 비밀번호 암호화 (BCrypt)
5. DB 저장
6. 이메일 발송
```

---

## 5. 적용 대상

| 사용자 유형 | 비밀번호 변경 | 임시 비밀번호 발급 |
|------------|-------------|------------------|
| 일반 가입자 (이메일) | ✅ | ✅ |
| OAuth 가입자 (Google, GitHub) | ❌ | ❌ |

---

## 6. 테스트 결과

```bash
$ ./gradlew clean test

BUILD SUCCESSFUL in 16s
29 actionable tasks: 29 executed
```

### 테스트 케이스

**PasswordServiceTest (6개)**
- 비밀번호를 변경할 수 있다
- 현재 비밀번호가 틀리면 변경 실패
- OAuth 사용자는 비밀번호 변경 불가
- 임시 비밀번호를 발급할 수 있다
- 존재하지 않는 이메일에도 동일 응답 (보안)
- OAuth 사용자에게는 임시 비밀번호 미발급 (보안)

**PasswordControllerTest (4개)**
- PATCH /api/v1/auth/password - 비밀번호 변경 성공
- POST /api/v1/auth/password/temporary - 임시 비밀번호 발급
- 임시 비밀번호 발급 - 이메일 형식 오류
- 임시 비밀번호 발급 - 이메일 누락

---

## 7. 보안 고려사항

| 항목 | 적용 |
|------|------|
| 이메일 미존재 시 동일 응답 | ✅ 가입 여부 노출 방지 |
| OAuth 사용자 동일 응답 | ✅ 가입 유형 노출 방지 |
| 임시 비밀번호 SecureRandom 사용 | ✅ 예측 불가능 |
| 비밀번호 정책 검증 | ✅ 8자 이상, 특수문자 |

---

## 8. 임시 비밀번호 생성 규칙

| 항목 | 값 |
|------|-----|
| 길이 | 12자 |
| 문자셋 | `ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%` |
| 제외 문자 | I, l, O, 0, 1 (혼동 방지) |

---

## 9. 이메일 템플릿

```html
<html>
<body>
    <h2>SW Campus 임시 비밀번호 안내</h2>
    <p>안녕하세요, SW Campus입니다.</p>
    <p>요청하신 임시 비밀번호를 안내해드립니다.</p>
    <div style="background:#f5f5f5;padding:20px;margin:20px 0;font-size:18px;font-weight:bold;">
        임시 비밀번호: {temporaryPassword}
    </div>
    <p style="color:#dc3545;">보안을 위해 로그인 후 반드시 비밀번호를 변경해주세요.</p>
    <p>본인이 요청하지 않은 경우 이 메일을 무시해주세요.</p>
    <br/>
    <p>감사합니다.</p>
    <p>SW Campus 팀</p>
</body>
</html>
```

---

## 10. 코드 품질 체크

| 항목 | 결과 |
|------|------|
| 네이밍 컨벤션 준수 | ✅ |
| 의존성 방향 준수 (api → domain) | ✅ |
| Controller에 비즈니스 로직 없음 | ✅ |
| @Valid 사용 | ✅ |
| 테스트 커버리지 | ✅ |

---

## 11. 다음 단계

Phase 09 완료. 인증 관련 모든 Phase가 완료되었습니다.

| Phase | 상태 |
|-------|------|
| Phase 01: 프로젝트 설정 | ✅ |
| Phase 02: Auth Entity | ✅ |
| Phase 03: Security 설정 | ✅ |
| Phase 04: 이메일 인증 | ✅ |
| Phase 05: 회원가입 (일반) | ✅ |
| Phase 06: 회원가입 (기관) | ✅ |
| Phase 07: 로그인 | ✅ |
| Phase 08: 토큰 관리 | ✅ |
| Phase 09: 비밀번호 관리 | ✅ |
| Phase 10: OAuth | ✅ |
