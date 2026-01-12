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
