# Phase 2: 도메인 로직 강화

> 비즈니스 요구사항을 충족하기 위해 Service 계층의 로직을 구현하고 수정하는 단계입니다.

## 1. 목표
- 기존 `ReviewService`, `LectureService`에 상태 변경 로직(REJECTED -> PENDING)을 추가한다.
- 신규 `MemberSurveyService`를 구현하여 Upsert 로직을 완성한다.
- `OrganizationService`에 정보 수정 및 파일 업로드 기능을 구현한다.

## 2. 상세 태스크 (Tasks)

### 2.1 ReviewService 수정
- **파일**: `com.swcampus.domain.review.ReviewService`
- [x] **`updateReview` 메서드 로직 변경**
    - [x] **Pre-condition Check**: `review.getApprovalStatus() == REJECTED` 인지 확인. 아니면 `ReviewNotModifiableException` 발생.
        - *Note*: 기존 `isApproved()` 메서드는 `APPROVED` 상태만 체크할 가능성이 높으므로, `REJECTED` 상태를 명시적으로 체크하는 로직으로 대체해야 함.
    - [x] **State Transition**: 수정 로직 수행 후 `review.changeStatus(ApprovalStatus.PENDING)` 호출.
    - [x] **Test**: `ReviewServiceTest`에 해당 시나리오 테스트 케이스 추가.

### 2.2 LectureService 수정
- **파일**: `com.swcampus.domain.lecture.LectureService`
- [x] **`modifyLecture` 메서드 로직 변경**
    - [x] **Pre-condition Check**: `lecture.getLectureAuthStatus() == REJECTED` 인지 확인. 아니면 `LectureCannotBeModifiedException` 발생.
    - [x] **State Transition**: 수정 로직 수행 후 `lecture.changeAuthStatus(LectureAuthStatus.PENDING)` 호출.
    - [x] **Test**: `LectureServiceTest`에 해당 시나리오 테스트 케이스 추가.

### 2.3 MemberSurveyService 구현 (신규)
- **파일**: `com.swcampus.domain.survey.MemberSurveyService`
- [x] **Repository 생성**: `MemberSurveyRepository` (findByMemberId 등)
- [x] **`upsertSurvey` 메서드 구현**
    - [x] `memberId`로 조회.
    - [x] **Case 1 (Exist)**: `existingSurvey.update(params)` 호출.
    - [x] **Case 2 (Not Exist)**: `MemberSurvey.create(params)` 호출 후 `save()`.
    - [x] `@Transactional` 적용 확인.

### 2.4 OrganizationService 수정
- **파일**: `com.swcampus.domain.organization.OrganizationService`
- [x] **`updateOrganization` 메서드 추가**
    - [x] 파라미터: `Long orgId`, `UpdateOrganizationParams params`, `MultipartFile file`
    - [x] **File Upload**: 파일이 존재하면 `FileStorageService.upload()` 호출하여 URL 획득.
    - [x] **Update**: `organization.update(params, fileUrl)` 호출.
    - [x] **Future Proofing**: 추후 승인 로직 추가를 위해 업데이트 로직을 별도 private 메서드로 분리 고려.

## 3. 완료 조건 (Definition of Done)
- [x] `ReviewService`, `LectureService` 수정 후 기존 테스트가 모두 통과한다.
- [x] `MemberSurveyService`가 정상적으로 Upsert를 수행한다.
- [x] `OrganizationService`가 파일 업로드와 함께 정보를 업데이트한다.

## 4. 리포트
- [Phase 02 리포트](../report/phase02.md)
