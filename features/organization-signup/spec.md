# 기관 회원가입 리팩토링 Spec

## 개요

기존 시드 데이터 271개 기관을 PENDING 상태로 변경하고, 기관 회원가입 시 기존 기관 선택 또는 신규 기관 생성을 지원합니다.

---

## API

### 기관 검색 (신규)

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/auth/organizations/search` | 기관 검색 | X |

**Request**: `GET /api/v1/auth/organizations/search?keyword=한국`

**Response**:
```json
[
  { "id": 1, "name": "한국기술사업화진흥협회" },
  { "id": 2, "name": "한국IT교육원" }
]
```

### 기관 회원가입 (변경)

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/signup/organization` | 기관 회원가입 | X |

**추가된 필드**:
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| organizationId | String | X | 기존 기관 ID (선택 시) |

**동작**:
- `organizationId` 있음 → 기존 기관에 연결
- `organizationId` 없음 → 신규 기관 생성

### 관리자 승인/반려

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| PATCH | `/api/v1/admin/organizations/{orgId}/approve` | 승인 | ADMIN |
| PATCH | `/api/v1/admin/organizations/{orgId}/reject` | 반려 | ADMIN |

**반려 Response**:
```json
{
  "approvalStatus": "REJECTED",
  "message": "반려되었습니다.",
  "adminEmail": "admin@swcampus.com",
  "adminPhone": "02-1234-5678"
}
```

---

## 기능 제한 (PENDING 상태)

| 기능 | PENDING | APPROVED |
|------|---------|----------|
| 로그인 | O | O |
| 기관 정보 조회 | O | O |
| 강의 등록 | X | O |
| 기관 정보 수정 | X | O |

**구현**: `OrganizationService.getApprovedOrganizationByUserId()`

---

## 에러 코드

| 예외 | HTTP | 설명 |
|------|------|------|
| `OrganizationNotApprovedException` | 403 | 승인되지 않은 기관 |
| `DuplicateOrganizationMemberException` | 409 | 이미 연결된 기관 |
| `OrganizationNotFoundException` | 404 | 기관 없음 |
| `AdminNotFoundException` | 500 | 관리자 없음 |

---

## 이메일 발송

| 이벤트 | 수신자 | 내용 |
|--------|--------|------|
| 승인 | 기관 담당자 | 승인 완료 안내 |
| 반려 | 기관 담당자 | 반려 안내 + 관리자 연락처 |

---

## 구현 노트

### 2025-12-20 - 초기 구현

- **PR**: [#173](https://github.com/sw-campus/sw-campus-server/pull/173)
- **마이그레이션**: V15 - 시드 데이터 271개 기관 PENDING으로 변경
- **주요 변경**:
  - 기관 검색 API 추가
  - 기존 기관 선택 회원가입 지원
  - 승인/반려 시 이메일 발송
  - PENDING 상태 기능 제한

### 코드 리뷰 반영

- `NumberFormatException` 처리 추가 (AuthController)
- `RuntimeException` → `OrganizationNotFoundException` 변경
- 승인 상태 체크 로직을 Controller → Service로 이동
