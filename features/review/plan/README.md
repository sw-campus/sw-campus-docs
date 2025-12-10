# 후기 (Review) - Development Plan

> 개발 계획서

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-10 |
| 목표 기간 | 2일 |
| 개발 범위 | 백엔드 API Only |
| 참조 문서 | [PRD](../prd.md), [Tech Spec](../tech-spec.md) |

---

## 개발 일정 개요

| Phase | 내용 | 예상 시간 |
|:-----:|------|:--------:|
| 01 | 기반 구조 (Domain, Entity, Repository) | 3시간 |
| 02 | 수료증 인증 API | 3시간 |
| 03 | 후기 CRUD API | 3시간 |
| 04 | 관리자 API (2단계 승인) | 3시간 |
| 05 | 테스트 및 검증 | 2시간 |
| **합계** | | **14시간** |

---

## Phase 구성

### [Phase 01: 기반 구조](./phase01-foundation.md)
- Domain 객체 (Review, Certificate, Enums)
- Repository 인터페이스
- JPA Entity
- Repository 구현체
- ErrorCode 정의

### [Phase 02: 수료증 인증 API](./phase02-certificate.md)
- OCR 클라이언트 (sw-campus-ai 연동)
- 수료증 확인/인증 API
- S3 업로드 연동 (기존 모듈 활용)

### [Phase 03: 후기 CRUD API](./phase03-review-crud.md)
- 후기 작성 API
- 후기 수정 API
- 후기 조회 API
- 닉네임 검증 로직

### [Phase 04: 관리자 API](./phase04-admin.md)
- 대기 중 후기 목록 조회
- 수료증 승인/반려 (1단계)
- 후기 승인/반려 (2단계)
- 블라인드 처리
- 반려 이메일 발송

### [Phase 05: 테스트 및 검증](./phase05-testing.md)
- Domain 레이어 단위 테스트
- API 통합 테스트
- 시나리오 검증

---

## 의존성 순서

```
Phase 01 (기반 구조)
    │
    ├──▶ Phase 02 (수료증) ──▶ Phase 03 (후기 CRUD)
    │                              │
    └──────────────────────────────┴──▶ Phase 04 (관리자)
                                              │
                                              ▼
                                       Phase 05 (테스트)
```

---

## 기존 모듈 재사용

| 모듈 | 재사용 내용 |
|------|-----------|
| `sw-campus-infra/s3` | `FileStorageService` - 수료증 이미지 업로드 |
| `sw-campus-domain/storage` | `FileStorageService` 인터페이스 |
| `sw-campus-domain/member` | `Member`, `MemberRepository` - 작성자 정보 |
| `sw-campus-domain/lecture` | `Lecture`, `LectureRepository` - 강의 정보 |

---

## 신규 생성 파일 목록

### Domain 모듈
```
sw-campus-domain/src/main/java/com/swcampus/domain/
├── review/
│   ├── Review.java
│   ├── ReviewDetail.java
│   ├── ReviewRepository.java
│   ├── ReviewService.java
│   ├── ApprovalStatus.java
│   ├── ReviewCategory.java
│   └── exception/
│       ├── ReviewNotFoundException.java
│       └── ReviewAlreadyExistsException.java
├── certificate/
│   ├── Certificate.java
│   ├── CertificateRepository.java
│   ├── CertificateService.java
│   └── exception/
│       ├── CertificateNotFoundException.java
│       └── CertificateAlreadyVerifiedException.java
└── ocr/
    └── OcrClient.java (interface)
```

### Infra 모듈
```
sw-campus-infra/
├── db-postgres/src/main/java/com/swcampus/infra/postgres/
│   ├── review/
│   │   ├── ReviewEntity.java
│   │   ├── ReviewJpaRepository.java
│   │   ├── ReviewEntityRepository.java
│   │   ├── ReviewDetailEntity.java
│   │   └── ReviewDetailJpaRepository.java
│   └── certificate/
│       ├── CertificateEntity.java
│       ├── CertificateJpaRepository.java
│       └── CertificateEntityRepository.java
└── ocr/
    └── src/main/java/com/swcampus/infra/ocr/
        ├── OcrClientImpl.java
        └── OcrResponse.java
```

### API 모듈
```
sw-campus-api/src/main/java/com/swcampus/api/
├── review/
│   ├── ReviewController.java
│   ├── request/
│   │   ├── CreateReviewRequest.java
│   │   └── UpdateReviewRequest.java
│   └── response/
│       ├── ReviewResponse.java
│       └── ReviewListResponse.java
├── certificate/
│   ├── CertificateController.java
│   ├── request/
│   │   └── VerifyCertificateRequest.java
│   └── response/
│       ├── CertificateCheckResponse.java
│       └── CertificateVerifyResponse.java
└── admin/
    ├── AdminReviewController.java
    ├── request/
    │   └── BlindReviewRequest.java
    └── response/
        ├── AdminReviewListResponse.java
        └── AdminReviewDetailResponse.java
```

---

## 다음 단계

각 Phase 문서를 참조하여 순차적으로 개발을 진행합니다.
