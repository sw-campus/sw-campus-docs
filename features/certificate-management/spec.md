# 수료증 관리 (Certificate Management) Spec

## 설계 결정

### 왜 APPROVED 상태에서는 수정 불가인가?

검증 완료된 수료증의 무결성 보장.

| 상태 | 수정 허용 | 이유 |
|------|:--------:|------|
| PENDING | ✅ | 아직 검토 전, 사용자 실수 수정 가능 |
| REJECTED | ✅ | 반려 후 올바른 이미지로 재제출 필요 |
| APPROVED | ❌ | 관리자가 검증 완료, 변경 시 재검증 필요 |

- 승인된 수료증이 변경되면 이미 작성된 후기의 신뢰성 훼손
- 승인 후 수정 허용 시 악용 가능성 (다른 이미지로 교체)
- 필요시 관리자에게 재검토 요청하는 별도 프로세스 고려

### 왜 수정 시 상태를 PENDING으로 초기화하는가?

기존 2단계 승인 체계 유지.

```
수료증 수정 → 상태 PENDING → 관리자 재검증 → APPROVED/REJECTED
```

- 새 이미지도 관리자 검증 필요 (허위 수료증 방지)
- REJECTED 상태에서 수정 시에도 재검토 대기 상태로 전환
- 기존 검증 워크플로우 재사용 (추가 개발 최소화)

### 왜 기존 이미지를 S3에서 삭제하는가?

스토리지 비용 절감 및 데이터 정리.

| 방식 | 장점 | 단점 |
|------|------|------|
| **삭제** | 스토리지 비용 절감, 불필요 데이터 제거 | 이전 이미지 복구 불가 |
| 보관 | 이력 추적 가능 | 스토리지 비용 증가, 관리 복잡 |

선택: **삭제** - 수료증 이미지는 검증 목적이므로 이력 보관 불필요

### 왜 기존 마이페이지 API를 확장하는가?

일관된 데이터 제공 및 추가 요청 최소화.

```
GET /api/v1/mypage/reviews 응답에 수료증 정보 포함
→ 별도 API 호출 없이 한 번에 필요한 데이터 제공
```

- 프론트엔드 추가 요청 불필요 (N+1 문제 방지)
- 기존 API 확장으로 일관성 유지
- 수료증 정보는 후기와 1:1 관계이므로 함께 조회 자연스러움

### 왜 PDF, JPEG, PNG만 허용하는가? (2026-01-13 리팩토링)

보안 및 호환성 강화.

| 파일 형식 | 허용 | 이유 |
|----------|:----:|------|
| PDF | ✅ | 공식 수료증의 일반적인 형식 |
| JPEG | ✅ | 스캔/사진 이미지의 표준 형식 |
| PNG | ✅ | 고품질 캡처 이미지 지원 |
| GIF, WebP | ❌ | 수료증으로 부적합, 악용 가능성 |
| 기타 | ❌ | 보안 위험, 검증 불가 |

- Frontend에서 accept 속성으로 1차 필터링
- 향후 Backend에서 Magic Number 기반 2차 검증 추가 가능

### 왜 S3Document 컴포넌트를 신규 생성했는가? (2026-01-13 리팩토링)

PDF와 이미지를 모두 지원하는 통합 뷰어 필요.

**기존 S3Image**:
- img 태그만 사용
- PDF 렌더링 불가

**신규 S3Document**:
- 파일 확장자 기반 자동 판별
- PDF: iframe으로 렌더링
- 이미지: img 태그로 렌더링
- S3Image 기존 기능 유지 (영향 최소화)

### 왜 InputStream 기반으로 변경하는가? (2026-01-13 리팩토링)

메모리 효율성 개선.

**변경 전** (`image.getBytes()`):
- 파일 전체를 메모리에 로드
- 대용량 파일 업로드 시 OutOfMemoryError 위험

**변경 후** (`image.getInputStream()`):
- 스트림 기반으로 처리
- 메모리 사용량 최소화

| 방식 | 메모리 사용 | 대용량 파일 |
|------|-----------|------------|
| getBytes() | 파일 크기만큼 | OOM 위험 |
| getInputStream() | 버퍼 크기만큼 | 안전 |

**영향 범위**: FileStorageService, S3FileStorageService, CertificateService, CertificateController

---

## 구현 노트

### 2026-01-12 - 수료증 이미지 조회 및 수정 기능 구현 [Server][Client]

- PR: Server #382, Client #186
- 변경:
  - 마이페이지 API 응답에 수료증 이미지 URL, 승인 상태 추가
  - 수료증 이미지 수정 API (`PATCH /api/v1/certificates/{id}/image`)
  - 수료증 상태별 수정 가능 여부 검증 (PENDING/REJECTED만 수정 가능)
  - 마이페이지 UI에서 수료증 이미지 조회/수정 모달
  - 이미지 클릭 시 전체화면 원본 보기
  - 업로드 전 미리보기 및 업로드/취소 버튼
- 관련: `CertificateController.java`, `CertificateService.java`, `ManagementSection.tsx`, `PersonalMain.tsx`

### 2026-01-12 - certificates 테이블 status 컬럼 삭제 [Server]

- PR: #382
- 배경: status 컬럼이 항상 'SUCCESS'로 설정되어 사용되지 않음, 실제 상태는 approval_status로 관리
- 변경: Certificate 도메인 및 Entity에서 status 필드 제거, Flyway 마이그레이션 추가
- 관련: `Certificate.java`, `CertificateEntity.java`, `V6__drop_certificates_status_column.sql`

### 2026-01-13 - 파일 업로드 시 InputStream 기반 처리로 개선 [Server]

- PR: #387
- 관련 이슈: #384
- 배경: `image.getBytes()`로 파일 전체를 메모리에 로드하여 대용량 파일 업로드 시 OOM 위험
- 변경:
  - FileStorageService에 InputStream 오버로드 메서드 추가
  - CertificateController/Service에서 `getInputStream()` 사용으로 변경
  - 대용량 파일 업로드 시 메모리 효율성 개선
- 관련: `FileStorageService.java`, `S3FileStorageService.java`, `CertificateService.java`, `CertificateController.java`

### 2026-01-13 - 수료증 파일 타입 제한 및 PDF 미리보기 지원 [Client]

- 배경:
  - 파일 타입 검증 없이 모든 파일 업로드 가능
  - PDF 파일이 관리자 화면에서 미리보기 안 됨
- 변경:
  - PDF, JPEG, PNG 파일만 허용하도록 accept 속성 추가
  - `validateCertificateFile` 함수 추가 (useFileValidation.ts)
  - S3Document 컴포넌트 신규 생성 (PDF/이미지 통합 뷰어)
  - 관리자 수료증 검증 모달에서 PDF 미리보기 지원
- 관련: `useFileValidation.ts`, `S3Document.tsx`, `CertificateVerifyModal.tsx`, `ManagementSection.tsx`, `PersonalMain.tsx`, `CertificateDetailModal.tsx`
