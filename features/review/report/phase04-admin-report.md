# Phase 04: 관리자 API - 구현 보고서

> 작성일: 2025-12-11

## 개요

2단계 관리자 승인 및 블라인드 처리 API를 구현했습니다.

## 구현 결과

### 완료 항목

| 항목 | 상태 | 비고 |
|------|------|------|
| AdminReviewService 구현 | ✅ | domain 모듈 |
| EmailService 인터페이스 | ✅ | domain 모듈 |
| ReviewEmailService 구현 | ✅ | api/mail - 기존 MailSender 활용 |
| Request/Response DTO | ✅ | 6개 DTO 생성 |
| AdminReviewController | ✅ | 8개 API 엔드포인트 |
| SecurityConfig 설정 | ✅ | `/api/v1/admin/**` 인증 필요 |
| GlobalExceptionHandler | ✅ | CertificateNotFoundException 추가 |
| 컴파일 | ✅ | 성공 |

---

## 생성된 파일

### Domain 모듈 (`sw-campus-domain`)

| 파일 | 경로 | 설명 |
|------|------|------|
| `EmailService.java` | `domain/review/` | 이메일 발송 인터페이스 |
| `AdminReviewService.java` | `domain/review/` | 관리자 후기 관리 서비스 |

### API 모듈 (`sw-campus-api`)

| 파일 | 경로 | 설명 |
|------|------|------|
| `ReviewEmailService.java` | `api/mail/` | 이메일 발송 구현체 |
| `BlindReviewRequest.java` | `api/admin/request/` | 블라인드 요청 DTO |
| `AdminReviewListResponse.java` | `api/admin/response/` | 대기 목록 응답 DTO |
| `AdminCertificateResponse.java` | `api/admin/response/` | 수료증 조회 응답 DTO |
| `AdminReviewDetailResponse.java` | `api/admin/response/` | 후기 상세 응답 DTO |
| `CertificateApprovalResponse.java` | `api/admin/response/` | 수료증 승인/반려 응답 DTO |
| `ReviewApprovalResponse.java` | `api/admin/response/` | 후기 승인/반려 응답 DTO |
| `AdminReviewController.java` | `api/admin/` | 관리자 컨트롤러 |

### 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `SecurityConfig.java` | `/api/v1/admin/**` 인증 설정 추가 |
| `GlobalExceptionHandler.java` | `CertificateNotFoundException` 예외 처리 추가 |

---

## API 엔드포인트

| 기능 | Method | Endpoint | 설명 |
|------|--------|----------|------|
| 대기 중 후기 목록 | GET | `/api/v1/admin/reviews` | PENDING 상태 목록 |
| 수료증 조회 | GET | `/api/v1/admin/certificates/{certificateId}` | 1단계 모달용 |
| 수료증 승인 | PATCH | `/api/v1/admin/certificates/{certificateId}/approve` | 1단계 승인 |
| 수료증 반려 | PATCH | `/api/v1/admin/certificates/{certificateId}/reject` | 1단계 반려 + 이메일 |
| 후기 상세 조회 | GET | `/api/v1/admin/reviews/{reviewId}` | 2단계 모달용 |
| 후기 승인 | PATCH | `/api/v1/admin/reviews/{reviewId}/approve` | 2단계 승인 |
| 후기 반려 | PATCH | `/api/v1/admin/reviews/{reviewId}/reject` | 2단계 반려 + 이메일 |
| 블라인드 처리 | PATCH | `/api/v1/admin/reviews/{reviewId}/blind` | 블라인드 ON/OFF |

---

## 구현 세부 사항

### 1. 2단계 승인 프로세스

```
[1단계: 수료증 검증]
  └─ 승인 → [2단계: 후기 검토]
  └─ 반려 → 반려 이메일 발송 (종료)

[2단계: 후기 검토]
  └─ 승인 → 일반 사용자에게 노출
  └─ 반려 → 반려 이메일 발송
```

### 2. 이메일 발송

- **비동기 처리**: `@Async` 어노테이션으로 비동기 발송
- **기존 인프라 활용**: `MailSender` 인터페이스 재사용
- **HTML 형식**: 이메일 내용을 HTML로 전송

### 3. 보안 설정

```java
// SecurityConfig.java
.requestMatchers("/api/v1/admin/**").authenticated()
```

- 현재: 인증된 사용자만 접근 가능
- 추후: `hasRole('ADMIN')` 역할 기반 권한 추가 가능

### 4. 기존 도메인 재사용

`Review`, `Certificate` 도메인에 이미 존재하는 메서드 활용:
- `approve()`, `reject()`: 승인/반려 상태 변경
- `blind()`, `unblind()`: 블라인드 처리

---

## 파일 구조

```
sw-campus-server/
├── sw-campus-domain/
│   └── src/main/java/com/swcampus/domain/
│       └── review/
│           ├── AdminReviewService.java    ✅ 신규
│           └── EmailService.java          ✅ 신규
│
└── sw-campus-api/
    └── src/main/java/com/swcampus/api/
        ├── admin/
        │   ├── AdminReviewController.java     ✅ 신규
        │   ├── request/
        │   │   └── BlindReviewRequest.java    ✅ 신규
        │   └── response/
        │       ├── AdminReviewListResponse.java      ✅ 신규
        │       ├── AdminCertificateResponse.java     ✅ 신규
        │       ├── AdminReviewDetailResponse.java    ✅ 신규
        │       ├── CertificateApprovalResponse.java  ✅ 신규
        │       └── ReviewApprovalResponse.java       ✅ 신규
        ├── mail/
        │   └── ReviewEmailService.java        ✅ 신규
        ├── config/
        │   └── SecurityConfig.java            🔄 수정
        └── exception/
            └── GlobalExceptionHandler.java    🔄 수정
```

---

## 향후 작업

- [ ] ROLE_ADMIN 역할 기반 권한 적용
- [ ] 관리자 API 통합 테스트 작성
- [ ] Swagger UI에서 API 테스트
- [ ] 프론트엔드 연동

---

## 참고

- 계획 문서: `sw-campus-docs/features/review/plan/phase04-admin.md`
- 시퀀스 다이어그램: `sw-campus-docs/sequence/review/admin_review_approval_diagram.md`
