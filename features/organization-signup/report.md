# 기관 회원가입 리팩토링 구현 보고서

> **Version**: 1.0
> **작성일**: 2025-12-20
> **PR**: [#173](https://github.com/sw-campus/sw-campus-server/pull/173)

---

## 1. 개요

### 1.1 배경
기존 시드 데이터로 등록된 271개의 기관(Organization)은 모두 APPROVED 상태였으나, 실제 운영 환경에서는 기관 담당자가 회원가입 후 관리자 승인을 받아야 하는 프로세스가 필요했습니다.

### 1.2 목표
- 기존 시드 기관 데이터를 PENDING 상태로 변경
- 기관 회원가입 시 기존 기관 선택 또는 신규 기관 생성 지원
- 관리자 승인/반려 워크플로우 개선
- 승인/반려 시 이메일 발송 기능 추가

---

## 2. 주요 변경 사항

### 2.1 데이터베이스 마이그레이션

**Flyway Migration V15**
```sql
-- 기존 시드 데이터(userId=1)의 기관을 PENDING으로 변경
UPDATE swcampus.organizations
SET approval_status = 'PENDING', updated_at = NOW()
WHERE user_id = 1 AND approval_status = 'APPROVED';
```

| 변경 전 | 변경 후 |
|---------|---------|
| 271개 기관 APPROVED | 271개 기관 PENDING |

### 2.2 기관 회원가입 흐름 변경

#### 기존 기관 선택 (신규 추가)
```
1. 사용자가 기관 검색 API 호출
2. 기존 기관 목록에서 선택
3. 회원가입 시 organizationId 전달
4. Member 생성 + Member.orgId 연결
5. Organization은 PENDING 상태 유지
```

#### 신규 기관 생성 (기존 로직 유지)
```
1. organizationId 없이 회원가입
2. Member 생성 (Role=ORGANIZATION)
3. Organization 생성 (PENDING)
4. Member.orgId = Organization.id
```

### 2.3 중복 가입 방지
- 이미 다른 사용자가 연결된 기관은 선택 불가
- `memberRepository.existsByOrgId()` 체크

### 2.4 PENDING 상태 기능 제한

| 기능 | PENDING | APPROVED |
|------|---------|----------|
| 로그인 | O | O |
| 기관 정보 조회 | O | O |
| 강의 등록 | X | O |
| 기관 정보 수정 | X | O |

**구현 방식**: `OrganizationService.getApprovedOrganizationByUserId()` 메서드 추가
- APPROVED가 아닌 경우 `OrganizationNotApprovedException` 발생

### 2.5 관리자 승인/반려 워크플로우

#### 승인 시
```
1. Organization.userId를 신청자 Member.id로 매핑
2. Organization.approvalStatus = APPROVED
3. 승인 이메일 발송
```

#### 반려 시
```
1. 해당 Member만 삭제 (Organization은 PENDING 유지)
2. 반려 이메일 발송 (관리자 연락처 포함)
```

### 2.6 이메일 발송

| 이벤트 | 수신자 | 내용 |
|--------|--------|------|
| 승인 | 기관 담당자 | 승인 완료 안내, 로그인 링크 |
| 반려 | 기관 담당자 | 반려 안내, 관리자 연락처 |

---

## 3. API 변경 사항

### 3.1 신규 API

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/v1/auth/organizations/search` | 기관 검색 (회원가입용, 인증 불필요) |

**Request**
```
GET /api/v1/auth/organizations/search?keyword=한국
```

**Response**
```json
[
  { "id": 1, "name": "한국기술사업화진흥협회" },
  { "id": 2, "name": "한국IT교육원" }
]
```

### 3.2 변경된 API

#### POST /api/v1/auth/signup/organization

**추가된 필드**
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| organizationId | String | X | 기존 기관 ID (선택 시) |

**동작 변경**
- `organizationId` 있음: 기존 기관에 연결
- `organizationId` 없음: 신규 기관 생성

#### PATCH /api/v1/admin/organizations/{orgId}/reject

**Response 변경**
```json
{
  "approvalStatus": "REJECTED",
  "message": "반려되었습니다.",
  "adminEmail": "admin@swcampus.com",
  "adminPhone": "02-1234-5678"
}
```

---

## 4. 신규 클래스

### 4.1 Domain 모듈

| 클래스 | 위치 | 설명 |
|--------|------|------|
| `OrganizationNotApprovedException` | domain/organization/exception | 승인되지 않은 기관 접근 시 예외 |
| `DuplicateOrganizationMemberException` | domain/auth/exception | 이미 연결된 기관 선택 시 예외 |
| `AdminNotFoundException` | domain/auth/exception | 관리자 조회 실패 시 예외 |
| `ApproveOrganizationResult` | domain/organization | 승인 결과 DTO |
| `RejectOrganizationResult` | domain/organization | 반려 결과 DTO |

### 4.2 API 모듈

| 클래스 | 위치 | 설명 |
|--------|------|------|
| `OrganizationSearchResponse` | api/auth/response | 기관 검색 응답 DTO |

### 4.3 Repository 메서드 추가

| Repository | 메서드 | 설명 |
|------------|--------|------|
| `MemberRepository` | `existsByOrgId(Long)` | 기관에 연결된 회원 존재 여부 |
| `MemberRepository` | `findByOrgId(Long)` | 기관에 연결된 회원 조회 |
| `MemberRepository` | `findFirstByRole(Role)` | 역할별 첫 번째 회원 조회 |

---

## 5. 코드 리뷰 반영 사항

### 5.1 NumberFormatException 처리
**AuthController.java**
```java
// Before
Long organizationId = Long.parseLong(organizationIdStr);

// After
try {
    organizationId = Long.parseLong(organizationIdStr);
} catch (NumberFormatException e) {
    throw new IllegalArgumentException("유효하지 않은 기관 ID 형식입니다: " + organizationIdStr);
}
```

### 5.2 도메인 예외 사용
**AuthService.java**
```java
// Before
.orElseThrow(() -> new RuntimeException("기관을 찾을 수 없습니다."));

// After
.orElseThrow(() -> new OrganizationNotFoundException(command.getOrganizationId()));
```

### 5.3 비즈니스 로직 Service 이동
**LectureController.java, MypageController.java**
```java
// Before (Controller에서 직접 체크)
Organization org = organizationService.getOrganizationByUserId(userId);
if (org.getApprovalStatus() != ApprovalStatus.APPROVED) {
    throw new OrganizationNotApprovedException();
}

// After (Service에서 체크)
Organization org = organizationService.getApprovedOrganizationByUserId(userId);
```

---

## 6. 테스트 결과

| 모듈 | 테스트 수 | 결과 |
|------|----------|------|
| sw-campus-api | 87 | PASS |
| sw-campus-domain | 55 | PASS |
| sw-campus-infra | 5 | PASS |
| **Total** | **147** | **PASS** |

---

## 7. 파일 변경 목록

### Domain 모듈 (sw-campus-domain)
- `OrganizationSignupCommand.java` - organizationId 필드 추가
- `AuthService.java` - 기존/신규 기관 분기 로직
- `OrganizationService.java` - getApprovedOrganizationByUserId() 추가
- `AdminOrganizationService.java` - 승인/반려 로직 개선
- `EmailService.java` - 승인/반려 이메일 발송 메서드 추가
- `MemberRepository.java` - existsByOrgId, findByOrgId, findFirstByRole
- `OrganizationNotApprovedException.java` (신규)
- `DuplicateOrganizationMemberException.java` (신규)
- `AdminNotFoundException.java` (신규)
- `ApproveOrganizationResult.java` (신규)
- `RejectOrganizationResult.java` (신규)

### API 모듈 (sw-campus-api)
- `OrganizationSignupRequest.java` - organizationId 필드 추가
- `AuthController.java` - 기관 검색 API 추가
- `LectureController.java` - getApprovedOrganizationByUserId 사용
- `MypageController.java` - getApprovedOrganizationByUserId 사용
- `AdminOrganizationController.java` - 승인/반려 응답 개선, 이메일 발송
- `AdminOrganizationApprovalResponse.java` - 관리자 연락처 필드 추가
- `OrganizationSearchResponse.java` (신규)

### Infra 모듈 (sw-campus-infra/db-postgres)
- `MemberEntityRepository.java` - 메서드 구현 추가
- `MemberJpaRepository.java` - 쿼리 메서드 추가
- `V15__update_organizations_to_pending.sql` (신규)

---

## 8. 관련 문서

- [시퀀스 다이어그램](../../sequence/organization-signup/)
- [기존 회원가입 시퀀스](../../sequence/auth/signup_login_description.md)
- [관리자 승인 시퀀스](../../sequence/auth/admin_provider_approval_description.md)
