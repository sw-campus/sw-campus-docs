# Phase 3: 통합 및 테스트

> Controller와 Service를 연결하고, 전체 기능을 검증하는 단계입니다.

## 1. 목표
- `MypageController`에서 각 Service 메서드를 호출하여 기능을 완성한다.
- Role 기반 접근 제어(Security)가 정상 동작하는지 확인한다.
- 단위 테스트 및 통합 테스트를 통해 기능의 안정성을 확보한다.

## 2. 상세 태스크 (Tasks)

### 2.1 Controller - Service 연결
- **파일**: `com.swcampus.api.mypage.MypageController`
- [ ] **의존성 주입**: `ReviewService`, `LectureService`, `MemberSurveyService`, `OrganizationService`, `MemberService` 주입.
- [ ] **메서드 구현**:
    - [ ] `getProfile`: `MemberService` 조회 + `MemberSurveyService.existsByMemberId` (User인 경우).
    - [ ] `updateProfile`: `MemberService.updateProfile` 호출.
    - [ ] `getMyReviews`: `ReviewService.findAllByMemberId` 호출 (DTO 변환).
    - [ ] `getSurvey`: `MemberSurveyService.findByMemberId` 호출.
    - [ ] `upsertSurvey`: `MemberSurveyService.upsertSurvey` 호출.
    - [ ] `getMyLectures`: `LectureService.findAllByOrgId` 호출 (DTO 변환).
    - [ ] `getOrganization`: `OrganizationService.findByOrgId` 호출.
    - [ ] `updateOrganization`: `OrganizationService.updateOrganization` 호출.

### 2.2 Security 및 권한 검증
- [ ] **Role 체크**:
    - User Only API (`/reviews`, `/survey`)에 `@PreAuthorize("hasRole('USER')")` 또는 내부 로직으로 검증.
    - Org Only API (`/lectures`, `/organization`)에 `@PreAuthorize("hasRole('ORGANIZATION')")` 또는 내부 로직으로 검증.
- [ ] **본인 확인**: PathVariable이나 RequestBody로 넘어온 ID가 아닌, `@CurrentMember`의 ID를 기준으로 동작하는지 재확인.

### 2.3 테스트 작성
- **Unit Test**: `MypageControllerTest`
    - [ ] MockMvc를 이용한 Controller 슬라이스 테스트.
    - [ ] 권한 없는 Role로 접근 시 403 Forbidden 확인.
    - [ ] 정상 요청 시 200 OK 및 Response Body 구조 확인.
- **Integration Test** (Optional but Recommended)
    - [ ] H2 DB를 이용한 전체 흐름 테스트.
    - [ ] 설문조사 생성 -> 조회 -> 수정 -> 조회 시나리오 검증.

## 3. 완료 조건 (Definition of Done)
- [ ] 모든 API 엔드포인트가 정상 동작한다.
- [ ] 잘못된 Role로 접근 시 적절한 에러(403)가 반환된다.
- [ ] 테스트 커버리지(Line Coverage)가 도메인 로직 기준 90% 이상이다.
