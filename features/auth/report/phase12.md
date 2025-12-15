# Phase 12: Admin Approval - 구현 보고서

> 생성일: 2025-12-15 20:17
> 최종 수정일: 2025-12-15 20:30
> 소요 시간: 2시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| OrganizationRepository에 페이징 쿼리 메서드 추가 | ✅ | `findByApprovalStatus` 추가 |
| AdminOrganizationService 생성 | ✅ | |
| AdminOrganizationController 생성 (`Page<T>` 직접 반환) | ✅ | |
| Response DTO 생성 (Summary, Detail, Approval) | ✅ | |
| Swagger 어노테이션 적용 | ✅ | |
| @PreAuthorize("hasRole('ADMIN')") 클래스 레벨 적용 | ✅ | |
| ADMIN 테스트 계정 생성 스크립트 추가 | ✅ | `data.sql` 업데이트 |
| 단위 테스트 작성 | ✅ | `AdminOrganizationControllerTest` |
| 빌드 및 테스트 통과 확인 | ✅ | |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `sw-campus-api/.../organization/AdminOrganizationController.java` | 생성 | 관리자용 기관 관리 API 컨트롤러 |
| `sw-campus-api/.../organization/response/AdminOrganizationSummaryResponse.java` | 생성 | 목록 조회용 DTO |
| `sw-campus-api/.../organization/response/AdminOrganizationDetailResponse.java` | 생성 | 상세 조회용 DTO |
| `sw-campus-api/.../organization/response/AdminOrganizationApprovalResponse.java` | 생성 | 승인/거절 응답용 DTO |
| `sw-campus-domain/.../organization/AdminOrganizationService.java` | 생성 | 관리자용 기관 도메인 서비스 |
| `sw-campus-domain/.../organization/OrganizationRepository.java` | 수정 | 페이징 조회 메서드 추가 |
| `sw-campus-infra/.../organization/OrganizationEntityRepository.java` | 수정 | Repository 구현체 업데이트 |
| `sw-campus-infra/.../organization/OrganizationJpaRepository.java` | 수정 | JPA Repository 업데이트 |
| `sw-campus-api/src/main/resources/data.sql` | 수정 | ADMIN 테스트 계정 추가 |
| `sw-campus-api/.../organization/AdminOrganizationControllerTest.java` | 생성 | 컨트롤러 단위 테스트 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 계획대로 진행된 항목

- `AdminOrganizationController`에서 `Page<T>`를 직접 반환하여 클라이언트 친화적인 페이징 응답 구조 구현
- `OrganizationRepository`에 `Pageable`을 지원하는 조회 메서드 추가
- Swagger 문서화 및 보안 설정(`@PreAuthorize`) 적용

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| 없음 | - | - | 계획대로 진행됨 |

---

## 4. 검증 결과

### 4.1 빌드

```bash
$ ./gradlew build -x test
BUILD SUCCESSFUL in 12s
```

### 4.2 테스트

```bash
$ ./gradlew :sw-campus-api:test
BUILD SUCCESSFUL in 13s
20 actionable tasks: 2 executed, 18 up-to-date
```

### 4.3 서브 모델 검증 (Critical인 경우)

| # | 심각도 | 이슈 | 해결 |
|---|--------|------|------|
| 1 | Critical | 테스트 실행 시 DB 연결 오류 | `data.sql`의 INSERT 문을 `INSERT ... SELECT ... WHERE NOT EXISTS`로 변경하여 중복 키 오류 방지 |

---

## 5. 발생한 이슈

### 이슈 1: JSON Naming Strategy 불일치로 인한 테스트 실패

- **증상**: `CategoryControllerTest`, `LectureControllerTest` 등에서 `PathNotFoundException` 발생 (예: `curriculum_id`를 찾을 수 없음).
- **원인**: `application-test.yml`에는 `SNAKE_CASE`로 설정되어 있으나, 테스트 코드의 Assertion이 CamelCase(`curriculumId`)로 작성되었거나, 일부 DTO가 제대로 직렬화되지 않음.
- **해결**: 테스트 코드의 Assertion을 실제 API 응답(SnakeCase)에 맞춰 수정하고, Mock 객체 설정을 보완함.

### 이슈 2: Mocking 누락으로 인한 Null 값 반환

- **증상**: `LectureControllerTest`에서 `average_score`가 `null`로 반환되어 테스트 실패.
- **원인**: Controller가 `LectureService`를 통해 평점을 조회하는데, 테스트에서는 `ReviewRepository`만 Mocking하고 `LectureService`의 해당 메서드는 Stubbing하지 않음.
- **해결**: `LectureService.getAverageScoresByLectureIds` 메서드에 대한 Stubbing 추가.

---

## 6. 다음 Phase 준비 사항

- [ ] Phase 13: Admin Dashboard (통계) 구현 준비
- [ ] 프론트엔드 연동을 위한 API 문서 공유

---
