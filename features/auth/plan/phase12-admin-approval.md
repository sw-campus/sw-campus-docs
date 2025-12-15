# Phase 12: 관리자 - 기관 가입 승인

> 작성일: 2025-12-15
> 목표: 기관 회원가입 신청을 관리자가 조회하고 승인/반려하는 기능을 구현합니다.

---

## 1. 개요

### 1.1 배경
기관 회원은 가입 직후 `PENDING` 상태이며, 관리자의 승인을 받아야 서비스를 이용할 수 있습니다. 관리자가 대기 중인 기관 목록을 확인하고, **재직증명서를 검토**한 뒤 승인(`APPROVED`) 또는 반려(`REJECTED`) 처리하는 기능이 필요합니다.

### 1.2 범위
- **Backend**:
    - 기관 목록 조회 API (상태별 필터링, 페이징)
    - 기관 상세 조회 API (재직증명서 URL 포함)
    - 기관 승인 API
    - 기관 반려 API
- **Frontend** (참고용):
    - 관리자 페이지 내 기관 관리 메뉴

---

## 2. 상세 요구사항

### 2.1 기관 목록 조회
- **Endpoint**: `GET /api/v1/admin/organizations`
- **Parameters**:
    - `status`: `PENDING` (기본값), `APPROVED`, `REJECTED`
    - `page`: 페이지 번호 (0부터 시작)
    - `size`: 페이지 크기 (기본 10)
- **Response**:

| 필드 | 타입 | 설명 |
|------|------|------|
| id | Long | 기관 ID |
| name | String | 기관명 |
| approvalStatus | String | 승인 상태 (PENDING/APPROVED/REJECTED) |
| createdAt | String | 신청일시 (ISO 8601) |

### 2.2 기관 상세 조회
- **Endpoint**: `GET /api/v1/admin/organizations/{id}`
- **Response**:

| 필드 | 타입 | 설명 |
|------|------|------|
| id | Long | 기관 ID |
| name | String | 기관명 |
| description | String | 기관 설명 |
| certificateUrl | String | 재직증명서 이미지 URL (S3) |
| approvalStatus | String | 승인 상태 |
| homepage | String | 홈페이지 URL |
| createdAt | String | 신청일시 |
| updatedAt | String | 수정일시 |

### 2.3 기관 승인
- **Endpoint**: `PATCH /api/v1/admin/organizations/{id}/approve`
- **Logic**:
    - 기관 상태를 `APPROVED`로 변경
    - **멱등성 유지**: 이미 `APPROVED` 상태인 경우에도 200 OK 반환
    - (추후) 승인 알림 메일 발송

### 2.4 기관 반려
- **Endpoint**: `PATCH /api/v1/admin/organizations/{id}/reject`
- **Logic**:
    - 기관 상태를 `REJECTED`로 변경
    - 반려 사유 입력 없음 (추후 메일 발송 시 공통 메시지 사용)
    - (추후) 반려 알림 메일 발송

---

## 3. 예외 처리

| HTTP Status | 상황 | 에러 코드 |
|-------------|------|----------|
| 404 Not Found | 존재하지 않는 기관 ID | `ORGANIZATION_NOT_FOUND` |
| 403 Forbidden | ADMIN 권한 없음 | Spring Security 기본 처리 |

> **멱등성**: 승인/반려 API는 이미 해당 상태인 경우에도 에러 없이 200 OK 반환

---

## 4. 구현 계획

### 4.1 Domain Layer

**OrganizationRepository 인터페이스 추가**:
```java
Page<Organization> findByApprovalStatus(ApprovalStatus status, Pageable pageable);
```

**OrganizationService 메서드 추가**:
- `getOrganizationsByStatus(ApprovalStatus status, Pageable pageable)`
- `getOrganizationDetail(Long id)` (기존 메서드 활용 가능)
- `approveOrganization(Long id)` - 기존 `Organization.approve()` 활용
- `rejectOrganization(Long id)` - 기존 `Organization.reject()` 활용

### 4.2 Infrastructure Layer

**OrganizationJpaRepository 쿼리 메서드 추가**:
```java
Page<OrganizationEntity> findByApprovalStatus(ApprovalStatus status, Pageable pageable);
```

**OrganizationEntityRepository 구현**:
- `findByApprovalStatus()` 메서드 구현

### 4.3 API Layer

**AdminOrganizationController 생성**:
- `@Tag(name = "Admin Organization", description = "관리자 기관 관리 API")`
- `@PreAuthorize("hasRole('ADMIN')")` 적용 (클래스 레벨)
- `@SecurityRequirement(name = "cookieAuth")` 적용

**DTO 생성**:
- `AdminOrganizationSummaryResponse` - 목록 내 개별 기관 요약
- `AdminOrganizationDetailResponse` - 상세 응답
- `AdminOrganizationApprovalResponse` - 승인/반려 결과

> **Page 처리**: Spring Data의 `Page<T>` 객체를 직접 반환 (기존 `AdminSurveyController` 패턴 준수)

### 4.4 Security 설정

**결정**: Controller 레벨 `@PreAuthorize("hasRole('ADMIN')")` 사용

**이유**:
- 기존 `AdminSurveyController`에서 동일한 패턴 사용 중
- SecurityConfig의 `/api/v1/admin/**`는 `.authenticated()` 유지
- 세부 권한은 Controller에서 제어 → 더 유연한 구조

### 4.5 ADMIN 계정 생성

테스트용 ADMIN 계정 생성 필요:
- `data.sql` 또는 `CommandLineRunner`로 초기 데이터 삽입
- Role: `ADMIN`

---

## 5. Swagger 문서화

### 5.1 Controller 레벨
```java
@Tag(name = "Admin Organization", description = "관리자 기관 관리 API")
@SecurityRequirement(name = "cookieAuth")
```

### 5.2 각 API 메서드
```java
@Operation(summary = "승인 대기 기관 목록 조회", description = "상태별로 기관 목록을 페이징하여 조회합니다.")
@ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공"),
    @ApiResponse(responseCode = "401", description = "인증 필요"),
    @ApiResponse(responseCode = "403", description = "관리자 권한 필요")
})
```

### 5.3 DTO 레벨
```java
@Schema(description = "기관 ID", example = "1")
private Long id;

@Schema(description = "기관명", example = "테스트교육기관")
private String name;
```

---

## 6. 테스트 계획

### 6.1 단위 테스트 (Domain Layer)
- `OrganizationServiceTest`
    - `approveOrganization_성공`
    - `approveOrganization_이미승인된기관_멱등성유지`
    - `rejectOrganization_성공`
    - `approveOrganization_존재하지않는기관_예외발생`

### 6.2 통합 테스트 (선택)
- `AdminOrganizationControllerTest`
    - 권한 없는 사용자 접근 시 403 반환
    - 목록 조회 페이징 동작 확인

---

## 7. API 명세 (Final)

### 7.1 목록 조회
```http
GET /api/v1/admin/organizations?status=PENDING&page=0&size=10
Authorization: Cookie (accessToken)

Response 200 (Spring Data Page 형식):
{
  "content": [
    {
      "id": 1,
      "name": "테스트교육기관",
      "approvalStatus": "PENDING",
      "createdAt": "2025-12-15T10:00:00"
    }
  ],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 10,
    "sort": { ... }
  },
  "totalElements": 1,
  "totalPages": 1,
  "size": 10,
  "number": 0,
  "first": true,
  "last": true,
  "empty": false
}
```

### 7.2 상세 조회
```http
GET /api/v1/admin/organizations/1
Authorization: Cookie (accessToken)

Response 200:
{
  "id": 1,
  "name": "테스트교육기관",
  "description": "기관 설명",
  "certificateUrl": "https://s3.../certificate.jpg",
  "approvalStatus": "PENDING",
  "homepage": "https://example.com",
  "createdAt": "2025-12-15T10:00:00",
  "updatedAt": "2025-12-15T10:00:00"
}
```

### 7.3 승인
```http
PATCH /api/v1/admin/organizations/1/approve
Authorization: Cookie (accessToken)

Response 200:
{
  "id": 1,
  "approvalStatus": "APPROVED",
  "message": "기관이 승인되었습니다."
}
```

### 7.4 반려
```http
PATCH /api/v1/admin/organizations/1/reject
Authorization: Cookie (accessToken)

Response 200:
{
  "id": 1,
  "approvalStatus": "REJECTED",
  "message": "기관이 반려되었습니다."
}
```

---

## 8. 파일 생성/수정 목록

### 8.1 생성할 파일

| 모듈 | 파일 | 설명 |
|------|------|------|
| api | `AdminOrganizationController.java` | 관리자 기관 API 컨트롤러 |
| api | `AdminOrganizationSummaryResponse.java` | 기관 요약 DTO (목록용) |
| api | `AdminOrganizationDetailResponse.java` | 기관 상세 DTO |
| api | `AdminOrganizationApprovalResponse.java` | 승인/반려 결과 DTO |
| domain | `AdminOrganizationService.java` | 관리자용 기관 서비스 |
| infra | `data.sql` (또는 기존 파일 수정) | ADMIN 계정 초기 데이터 |

### 8.2 수정할 파일

| 모듈 | 파일 | 변경 내용 |
|------|------|----------|
| domain | `OrganizationRepository.java` | `findByApprovalStatus()` 메서드 추가 |
| infra | `OrganizationJpaRepository.java` | JPA 쿼리 메서드 추가 |
| infra | `OrganizationEntityRepository.java` | Repository 구현 추가 |

---

## 9. 체크리스트

- [ ] OrganizationRepository에 페이징 쿼리 메서드 추가
- [ ] AdminOrganizationService 생성
- [ ] AdminOrganizationController 생성 (`Page<T>` 직접 반환)
- [ ] Response DTO 생성 (Summary, Detail, Approval)
- [ ] Swagger 어노테이션 적용
- [ ] @PreAuthorize("hasRole('ADMIN')") 클래스 레벨 적용
- [ ] ADMIN 테스트 계정 생성 스크립트 추가
- [ ] 단위 테스트 작성
- [ ] 빌드 및 테스트 통과 확인
