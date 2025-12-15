# Phase 02: Domain - 구현 보고서

> 생성일: 2025-12-15 12:10
> 소요 시간: 1시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| **`updateReview` 메서드 로직 변경** | ✅ | |
| **Pre-condition Check**: `review.getApprovalStatus` | ✅ | `REJECTED` 상태 체크 |
| **State Transition**: 수정 로직 수행 후 `review.resubmit()` | ✅ | `changeStatus` 대신 `resubmit` 사용 |
| **Test**: `ReviewServiceTest`에 해당 시나리오 테스트 케이스 추가. | ✅ | |
| **`modifyLecture` 메서드 로직 변경** | ✅ | |
| **Pre-condition Check**: `lecture.getLectureAuthStatus` | ✅ | `REJECTED` 상태 체크 |
| **State Transition**: 수정 로직 수행 후 `lecture.changeAuthStatus` | ✅ | |
| **Test**: `LectureServiceTest`에 해당 시나리오 테스트 케이스 추가 | ✅ | |
| **Repository 생성**: `MemberSurveyRepository` | ✅ | 기존 Repository 사용 |
| **`upsertSurvey` 메서드 구현** | ✅ | |
| `memberId`로 조회. | ✅ | |
| **Case 1 (Exist)**: `existingSurvey.update(params)` | ✅ | |
| **Case 2 (Not Exist)**: `MemberSurvey.create(params)` | ✅ | |
| `@Transactional` 적용 확인. | ✅ | |
| **`updateOrganization` 메서드 추가** | ✅ | |
| 파라미터: `Long orgId`, `UpdateOrganizationParams params` | ✅ | `userId` 파라미터 추가 (권한 검증) |
| **File Upload**: 파일이 존재하면 `FileStorageService.upload()` | ✅ | |
| **Update**: `organization.update(params, fileUrl)` | ✅ | |
| **Future Proofing**: 추후 승인 로직 추가를 위해 업데이트 로직 분리 | ✅ | |
| `ReviewService`, `LectureService` 수정 후 기존 테스트가 모두 통과 | ✅ | |
| `MemberSurveyService`가 정상적으로 Upsert를 수행한다. | ✅ | |
| `OrganizationService`가 파일 업로드와 함께 정보를 업데이트한다. | ✅ | |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `sw-campus-domain/.../review/ReviewService.java` | 수정 | `updateReview` 로직 변경 (반려된 후기만 수정, 재제출) |
| `sw-campus-domain/.../review/Review.java` | 수정 | `resubmit()` 메서드 추가 |
| `sw-campus-domain/.../lecture/LectureService.java` | 수정 | `modifyLecture` 로직 변경 (반려된 강의만 수정) |
| `sw-campus-domain/.../lecture/exception/LectureNotModifiableException.java` | 생성 | 강의 수정 불가 예외 추가 |
| `sw-campus-domain/.../survey/MemberSurveyService.java` | 수정 | `upsertSurvey` 메서드 추가 및 최적화 |
| `sw-campus-domain/.../organization/OrganizationService.java` | 수정 | `updateOrganization` 메서드 추가 (권한 검증 포함) |
| `sw-campus-domain/.../organization/dto/UpdateOrganizationParams.java` | 생성 | 업체 수정 파라미터 DTO |
| `sw-campus-domain/.../review/ReviewServiceTest.java` | 수정 | 반려된 후기 수정 테스트 추가 |
| `sw-campus-domain/.../lecture/LectureServiceTest.java` | 수정 | 반려된 강의 수정 테스트 추가 |
| `sw-campus-domain/.../survey/MemberSurveyServiceTest.java` | 생성 | 설문조사 Upsert 테스트 추가 |
| `sw-campus-domain/.../organization/OrganizationServiceTest.java` | 생성 | 업체 정보 수정 테스트 추가 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 계획대로 진행된 항목

- `ReviewService`, `LectureService`의 상태 변경 로직 구현
- `MemberSurveyService`의 Upsert 로직 구현
- `OrganizationService`의 파일 업로드 및 정보 수정 구현

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| 예외 클래스명 | `LectureCannotBeModifiedException` | `LectureNotModifiableException` | `ReviewNotModifiableException`과 네이밍 통일 |
| Review 상태 변경 | `changeStatus(PENDING)` | `resubmit()` | 도메인 의도 명확화 및 불변식 보호 |
| Org 수정 권한 | `orgId`만 확인 | `userId` 소유권 확인 | 보안 강화 (권한 검증 로직 추가) |
| Survey Upsert | `findBy` -> `map`/`orElseGet` | `updateSurveyInternal` 분리 | 가독성 및 재사용성 향상 (기존 메서드 활용) |

---

## 4. 검증 결과

### 4.1 빌드

```bash
$ ./gradlew build -x test
BUILD SUCCESSFUL in 1s
```

### 4.2 테스트

```bash
$ ./gradlew test
<summary passed=42 failed=0 />
```

- `ReviewServiceTest`: 27 passed
- `LectureServiceTest`: 4 passed
- `MemberSurveyServiceTest`: 9 passed
- `OrganizationServiceTest`: 2 passed

### 4.3 서브 모델 검증 (Critical인 경우)

| # | 심각도 | 이슈 | 해결 |
|---|--------|------|------|
| 1 | 🟠 Major | Javadoc 불일치 | 주석 수정 완료 |
| 2 | 🟠 Major | Org 권한 검증 누락 | `userId` 검증 로직 추가 |
| 3 | 🟠 Major | Review 상태 전이 취약 | `resubmit()` 메서드로 캡슐화 |

---

## 5. 발생한 이슈

### 이슈 1: 기존 메서드 재활용 누락

- **증상**: `MemberSurveyService.upsertSurvey` 구현 시 기존 `create`/`update` 메서드를 활용하지 않고 로직을 중복 구현함.
- **원인**: 기계적인 구현으로 인한 기존 코드 파악 미흡.
- **해결**: `updateSurveyInternal` 메서드를 추출하여 중복을 제거하고 로직을 통합함.

---

## 6. 다음 Phase 준비 사항

- [ ] **Phase 3: Integration** 준비
- [ ] `MypageController` 구현 및 API 연동
- [ ] Swagger 문서화 확인

---

## 📊 진행률 (Plan README 업데이트용)

```
Phase 02 ██████████ 100% ✅
```

완료: 22/22 tasks
