# Phase 1: 기본 구조 및 DTO 구현

> 마이페이지 API의 뼈대를 구축하는 단계입니다.

## 1. 목표
- API 명세(Tech Spec)에 정의된 모든 Request/Response DTO를 구현한다.
- `MypageController`의 스켈레톤 코드를 작성하여 엔드포인트를 노출한다.
- 컴파일 에러가 없는 상태로 빌드가 가능해야 한다.

## 2. 상세 태스크 (Tasks)

### 2.1 Request DTO 구현
- **패키지**: `com.swcampus.api.mypage.request`
- [ ] **`UpdateProfileRequest.java`**
    - 필드: `nickname`, `phone`, `address`
    - Validation: `@Size(max=20)`, `@Pattern`(전화번호) 등 적용
- [ ] **`UpdateOrganizationRequest.java`**
    - 필드: `organizationName`, `representativeName`, `phone`, `address`
    - 필드: `MultipartFile businessRegistration` (재직증명서/사업자등록증)
    - Validation: 필수 값 체크
- [ ] **`SurveyRequest.java`**
    - 필드: `major`, `bootcampCompleted`, `wantedJobs`, `licenses`, `hasGovCard`, `affordableAmount`
    - Validation: 없음 (All Optional)

### 2.2 Response DTO 구현
- **패키지**: `com.swcampus.api.mypage.response`
- [ ] **`MypageProfileResponse.java`**
    - 필드: `email`, `name`, `nickname`, `phone`, `address`, `profileImageUrl`, `provider`, `role`, `hasSurvey`
    - 정적 팩토리 메서드 `from(Member member, boolean hasSurvey)` 구현
- [ ] **`MyReviewListResponse.java`**
    - 필드: `reviewId`, `lectureId`, `lectureName`, `rating`, `content`, `approvalStatus`, `rejectReason`, `createdAt`, `updatedAt`, `canEdit`
    - `canEdit` 로직: `status == REJECTED`
- [ ] **`MyLectureListResponse.java`**
    - 필드: `lectureId`, `lectureName`, `lectureImageUrl`, `lectureAuthStatus`, `rejectReason`, `status`, `createdAt`, `updatedAt`, `canEdit`
    - `canEdit` 로직: `status == REJECTED`
- [ ] **`OrganizationInfoResponse.java`**
    - 필드: `organizationId`, `organizationName`, `representativeName`, `businessNumber`, `phone`, `address`, `approvalStatus`, `rejectReason`
- [ ] **`SurveyResponse.java`**
    - 필드: `surveyId`, `major`, `bootcampCompleted`, ... , `exists`
    - 정적 팩토리 메서드 `empty()` 및 `from(MemberSurvey survey)` 구현

### 2.3 Controller 스켈레톤 구현
- **클래스**: `com.swcampus.api.mypage.MypageController`
- [ ] `@RestController`, `@RequestMapping("/api/v1/mypage")` 적용
- [ ] **메서드 정의** (Return `null` or Empty Body)
    - `getProfile(@CurrentMember MemberPrincipal member)`
    - `updateProfile(@CurrentMember MemberPrincipal member, @RequestBody UpdateProfileRequest request)`
    - `getMyReviews(...)`
    - `getSurvey(...)`
    - `upsertSurvey(...)`
    - `getMyLectures(...)`
    - `getOrganization(...)`
    - `updateOrganization(...)`

## 3. 완료 조건 (Definition of Done)
- [ ] 모든 DTO 클래스가 생성되었다.
- [ ] `MypageController`가 생성되었고, Swagger UI에서 엔드포인트가 확인된다.
- [ ] `./gradlew clean build -x test`가 성공한다.
