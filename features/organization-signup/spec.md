# 기관 회원가입 Spec

## 설계 결정

### 왜 기존 기관 선택과 신규 생성을 분리했는가?

담당자 변경 시 기관 데이터 유지.

```java
if (command.getOrganizationId() != null) {
    // 기존 기관 선택: 기관 이력(강의, 평가) 유지
    organization = organizationRepository.findById(organizationId);
    organization.updateCertificateKey(newCertificateKey);
} else {
    // 신규 기관 생성
    organization = Organization.create(...);
}
```

- 기존 기관: 담당자만 변경, 강의/평가 데이터 보존
- 신규 기관: 이름, 재직증명서로 새로 생성
- 두 경로 모두 재직증명서 필수 (담당자 검증)

### 왜 기관당 담당자는 1명인가?

책임 소재 명확화.

```java
if (memberRepository.existsByOrgId(command.getOrganizationId())) {
    throw new DuplicateOrganizationMemberException(organizationId);
}
```

- 1기관 1담당자로 의사결정 단순화
- 복수 담당자 시 권한 충돌 가능성
- 담당자 변경 시 기존 담당자 해제 후 신규 연결

### 왜 PENDING 상태에서 강의 등록만 제한하는가?

기관 신뢰성 검증 전 공개 강의 금지.

| 기능 | PENDING | APPROVED |
|------|---------|----------|
| 로그인 | O | O |
| 기관 정보 조회 | O | O |
| 기관 정보 수정 | O | O |
| 강의 등록 | X | O |

- 재직증명서 검증 전 = 기관 신원 미확인
- PENDING 상태로 강의 등록 → 학생 모집 → 승인 거부 시 피해 발생
- 정보 조회/수정은 허용하여 재심사 준비 가능

### 왜 반려 시 관리자 연락처를 포함하는가?

재심사 경로 제공.

```java
return new RejectOrganizationResult(
    memberEmail,
    admin.getEmail(),   // 관리자 이메일
    admin.getPhone()    // 관리자 전화
);
```

- 반려 사유가 단순 서류 미흡일 수 있음
- 관리자와 직접 소통으로 빠른 해결
- "반려 후 끝"이 아닌 "다음 단계 가이드"

### 왜 재직증명서를 Private Bucket에 저장하는가?

민감한 개인/기업 정보 보호.

```java
String certificateKey = fileStorageService.uploadPrivate(
    "certificates/",
    certificateFile
);
```

- Public URL로 직접 접근 불가
- 관리자가 Presigned URL로만 조회
- 기관 정보(사업자번호, 주소 등) 외부 노출 차단

---

## 구현 노트

### 2025-12-20 - 초기 구현 [Server]

- PR: #173
- 변경:
  - 기관 검색 API (`/auth/organizations/search`)
  - 기존 기관 선택 회원가입 지원
  - 승인/반려 시 이메일 발송
  - PENDING 상태 기능 제한 (`OrganizationNotApprovedException`)
  - 시드 데이터 271개 기관 PENDING으로 마이그레이션 (V15)
- 관련: `AuthController.java`, `AuthService.java`, `AdminOrganizationController.java`

### 2025-12-21 - 재직증명서 Private Bucket 저장 [Server]

- PR: #180
- 변경:
  - `FileStorageService.uploadPrivate()` 메서드 추가
  - 재직증명서를 private bucket의 `certificates/` 디렉토리에 저장
  - 조회 시 Presigned URL 필요
- 관련: `S3FileStorageService.java`
