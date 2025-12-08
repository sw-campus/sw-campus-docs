# Phase 06 구현 보고서: 기관 회원가입

> 작성일: 2025-12-08
> 브랜치: `28-sign-up-for-organization`

---

## 1. 구현 요약

### 1.1 목표
기관(ORGANIZATION) 회원가입 기능과 S3 파일 업로드를 구현합니다.

### 1.2 주요 변경사항
- 승인 상태(`approvalStatus`)와 재직증명서 URL(`certificateUrl`)을 **Organization 테이블**에서 관리
- Member의 `orgAuth` 필드 제거 → Organization의 `approvalStatus`로 이동
- AWS S3 파일 업로드 인프라 모듈 추가

---

## 2. 완료 항목

| 항목 | 상태 |
|------|------|
| 기관 회원가입 API 구현 (multipart/form-data) | ✅ |
| S3 파일 업로드 서비스 구현 | ✅ |
| 재직증명서 이미지 저장 (Organization.certificateUrl) | ✅ |
| Organization 생성 및 approvalStatus=PENDING 설정 | ✅ |
| ApprovalStatus Enum 구현 | ✅ |
| Member의 orgId에 Organization FK 연결 | ✅ |
| 예외 처리 (CertificateRequiredException, MissingServletRequestPartException) | ✅ |
| BaseEntity createdAt updatable=false 수정 | ✅ |
| 단위 테스트 통과 | ✅ |

---

## 3. 생성된 파일

### 3.1 Domain Layer (sw-campus-domain)

| 파일 | 경로 | 설명 |
|------|------|------|
| `ApprovalStatus.java` | `domain/organization/` | 기관 승인 상태 Enum (PENDING, APPROVED, REJECTED) |
| `FileStorageService.java` | `domain/storage/` | 파일 저장소 인터페이스 |
| `OrganizationSignupCommand.java` | `domain/auth/` | 기관 회원가입 명령 객체 |
| `OrganizationSignupResult.java` | `domain/auth/` | 기관 회원가입 결과 객체 |
| `CertificateRequiredException.java` | `domain/auth/exception/` | 재직증명서 필수 예외 |

### 3.2 Infrastructure Layer (sw-campus-infra)

| 파일 | 경로 | 설명 |
|------|------|------|
| `build.gradle` | `infra/s3/` | S3 모듈 빌드 설정 |
| `S3Config.java` | `infra/s3/` | AWS S3 Client 설정 |
| `S3FileStorageService.java` | `infra/s3/` | FileStorageService 구현체 |

### 3.3 API Layer (sw-campus-api)

| 파일 | 경로 | 설명 |
|------|------|------|
| `OrganizationSignupRequest.java` | `api/auth/request/` | 기관 회원가입 요청 DTO |
| `OrganizationSignupResponse.java` | `api/auth/response/` | 기관 회원가입 응답 DTO |

---

## 4. 수정된 파일

### 4.1 설정 파일

| 파일 | 변경 내용 |
|------|----------|
| `settings.gradle` | `sw-campus-infra:s3` 모듈 추가 |
| `sw-campus-api/build.gradle` | s3 모듈 의존성 추가 |

### 4.2 Domain Layer

| 파일 | 변경 내용 |
|------|----------|
| `Organization.java` | `approvalStatus`, `certificateUrl` 필드 추가, `approve()`, `reject()` 메서드 추가 |
| `Member.java` | `orgAuth` 필드 제거, `setOrgId()` 메서드 추가 |
| `AuthService.java` | `signupOrganization()` 메서드 추가 |

### 4.3 Infrastructure Layer

| 파일 | 변경 내용 |
|------|----------|
| `OrganizationEntity.java` | `approval_status`, `certificate_url` 컬럼 추가 |
| `MemberEntity.java` | `org_auth` 컬럼 제거 |
| `BaseEntity.java` | `createdAt`에 `@Column(updatable = false)` 추가 |

### 4.4 API Layer

| 파일 | 변경 내용 |
|------|----------|
| `AuthController.java` | `/signup/organization` 엔드포인트 추가 |
| `GlobalExceptionHandler.java` | `MissingServletRequestPartException` 핸들러 추가 |

### 4.5 Test 파일

| 파일 | 변경 내용 |
|------|----------|
| `OrganizationTest.java` | `Organization.create()` 시그니처 변경 반영, 승인/반려 테스트 추가 |
| `MemberTest.java` | `orgAuth` 제거 반영 |
| `OrganizationRepositoryTest.java` | `create()` 시그니처 변경 반영 |
| `AuthControllerSignupTest.java` | `Member.of()` 시그니처 변경 반영 |

---

## 5. API 명세

### POST /api/v1/auth/signup/organization

**Content-Type:** `multipart/form-data`

**Request Parameters:**

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| email | String | ✅ | 이메일 (인증 완료된) |
| password | String | ✅ | 비밀번호 |
| name | String | ✅ | 이름 |
| nickname | String | ✅ | 닉네임 |
| phone | String | ✅ | 전화번호 |
| location | String | ✅ | 주소 |
| organizationName | String | ✅ | 기관명 |
| certificateImage | File | ✅ | 재직증명서 이미지 |

**Response (201 Created):**

```json
{
  "userId": 1,
  "email": "org@example.com",
  "name": "김기관",
  "nickname": "기관담당자",
  "role": "ORGANIZATION",
  "organizationId": 1,
  "organizationName": "테스트교육기관",
  "approvalStatus": "PENDING",
  "message": "기관 회원가입이 완료되었습니다. 관리자 승인 후 서비스 이용이 가능합니다."
}
```

**Error Responses:**

| Status | 상황 | Message |
|--------|------|---------|
| 400 | 재직증명서 누락 | 재직증명서는 필수입니다 |
| 400 | 이메일 미인증 | 이메일 인증이 필요합니다 |
| 400 | 비밀번호 정책 위반 | (비밀번호 정책 메시지) |
| 409 | 이메일 중복 | 이미 가입된 이메일입니다 |

---

## 6. DB 스키마 변경

### 6.1 organizations 테이블

```sql
-- 추가된 컬럼
approval_status INTEGER      -- 0: PENDING, 1: APPROVED, 2: REJECTED
certificate_url TEXT         -- S3 재직증명서 URL
```

### 6.2 members 테이블

```sql
-- 제거된 컬럼
-- org_auth INTEGER (Organization.approval_status로 이동)
```

---

## 7. 테스트 결과

```
BUILD SUCCESSFUL in 9s
18 actionable tasks: 8 executed, 10 up-to-date
```

모든 테스트 통과 ✅

---

## 8. 발견 및 수정된 이슈

### 8.1 createdAt null 이슈

**문제:** 기관 회원가입 시 Member를 두 번 저장하면서 `createdAt`이 null로 덮어써짐

**원인:** `BaseEntity.createdAt`에 `@Column(updatable = false)`가 없어서 UPDATE 시 null로 설정됨

**해결:** `@Column(updatable = false)` 추가

### 8.2 MissingServletRequestPartException 미처리

**문제:** `certificateImage` 누락 시 500 에러 발생

**원인:** `GlobalExceptionHandler`에 해당 예외 핸들러 없음

**해결:** `MissingServletRequestPartException` 핸들러 추가, 사용자 친화적 메시지 반환

---

## 9. 다음 단계

→ [Phase 07: 로그인/로그아웃](./phase07-login.md)

---

## 10. 참고 자료

- [Postman 테스트 컬렉션](../../../sw-campus-server/postman/SW-Campus-Auth.postman_collection.json)
- [AWS S3 설정 가이드](application-local.yml의 aws 섹션 참고)
