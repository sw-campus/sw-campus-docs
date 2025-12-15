# Phase 03: Integration - 구현 보고서

> ⚠️ 이 파일은 자동 생성된 **초안**입니다. 검토 후 수정하세요.
> 
> 생성일: 2025-12-15 16:58
> 소요 시간: 4시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| **의존성 주입**: `ReviewService`, `LectureService`, `MemberService`, `OrganizationService`, `MemberSurveyService` | ✅ | |
| **메서드 구현**: | ✅ | |
| `getProfile`: `MemberService` 조회 + `MemberSurveyService.existsByMemberId` | ✅ | |
| `updateProfile`: `MemberService.updateProfile` 호출. | ✅ | |
| `getMyReviews`: `ReviewService.findAllByMemberId`  | ✅ | |
| `getSurvey`: `MemberSurveyService.findByMemberId`  | ✅ | |
| `upsertSurvey`: `MemberSurveyService.upsertSurvey` | ✅ | |
| `getMyLectures`: `LectureService.findAllByOrgId` 호출 | ✅ | |
| `getOrganization`: `OrganizationService.findByOrgId` 호출 | ✅ | |
| `updateOrganization`: `OrganizationService.updateOrganization` 호출 | ✅ | |
| **Role 체크**: | ✅ | `@PreAuthorize` 사용 |
| **본인 확인**: PathVariable이나 RequestBody로 넘어온 ID가 아닌, `@CurrentMember` 사용 | ✅ | |
| MockMvc를 이용한 Controller 슬라이스 테스트. | ✅ | |
| 권한 없는 Role로 접근 시 403 Forbidden 확인. | ✅ | |
| 정상 요청 시 200 OK 및 Response Body 구조 확인. | ✅ | |
| H2 DB를 이용한 전체 흐름 테스트. | ✅ | |
| 설문조사 생성 -> 조회 -> 수정 -> 조회 시나리오 검증. | ✅ | |
| 모든 API 엔드포인트가 정상 동작한다. | ✅ | |
| 잘못된 Role로 접근 시 적절한 에러(403)가 반환된다. | ✅ | |
| 테스트 커버리지(Line Coverage)가 도메인 로직 기준 90% 이상이다. | ✅ | |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `sw-campus-api/.../MypageController.java` | 수정 | Service 연결, `@RequestPart` 적용 |
| `sw-campus-api/.../OrganizationInfoResponse.java` | 수정 | `govAuth`, `homepage` 등 필드 추가 |
| `sw-campus-domain/.../UpdateOrganizationParams.java` | 수정 | `govAuth` 추가, `FileUploadData` 적용 |
| `sw-campus-domain/.../OrganizationService.java` | 수정 | `updateOrganization` 로직 개선 |
| `sw-campus-domain/.../Organization.java` | 수정 | `govAuth`, `homepage` 수정 메서드 추가 |
| `sw-campus-api/.../UpdateOrganizationRequest.java` | 삭제 | 미사용 DTO 삭제 (Style Guide 준수) |
| `sw-campus-api/.../application-test.yml` | 수정 | AWS Credentials 설정 추가 |
| `sw-campus-api/.../MypageControllerTest.java` | 수정 | 테스트 케이스 업데이트 |
| `sw-campus-api/.../SecurityConfig.java` | 수정 | `@EnableMethodSecurity` 추가 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 계획대로 진행된 항목

- Controller와 Service 간의 의존성 주입 및 메서드 호출 연결 완료.
- Security `@PreAuthorize` 및 `@CurrentMember`를 이용한 권한 제어 구현.

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| `updateOrganization` 파라미터 | DTO (`UpdateOrganizationRequest`) 사용 | 개별 `@RequestPart` 사용 | 프로젝트 Style Guide 준수 (MultipartFile과 DTO 혼용 지양) |
| `Organization` 필드 | `govAuth` 수정 불가 | `govAuth` 수정 가능 | 사용자 요구사항 반영 |
| 필드 네이밍 | `address` | `location` | Domain/Entity 용어 통일 |

---

## 4. 검증 결과

### 4.1 빌드

```bash
$ ./gradlew build -x test
BUILD SUCCESSFUL in 3s
```

### 4.2 테스트

```bash
$ ./gradlew test
BUILD SUCCESSFUL in 21s
25 actionable tasks: 6 executed, 19 up-to-date
```

### 4.3 서브 모델 검증 (Critical인 경우)

| # | 심각도 | 이슈 | 해결 |
|---|--------|------|------|
| 1 | High | 통합 테스트 실패 (AWS Config) | `application-test.yml`에 Dummy Credentials 추가 |

---

## 5. 발생한 이슈

### 이슈 1: 통합 테스트 시 AWS Credentials 누락

- **증상**: `PlaceholderResolutionException: Could not resolve placeholder 'aws.credentials.access-key'` 에러 발생하며 테스트 실패.
- **원인**: `S3Config` 빈 생성 시 필요한 프로퍼티가 테스트 환경 설정(`application-test.yml`)에 정의되지 않음.
- **해결**: `application-test.yml`에 `aws.credentials.access-key` 및 `secret-key` 더미 값 추가.

### 이슈 2: Organization 수정 필드 누락

- **증상**: `govAuth` 등 일부 필드가 수정되지 않음.
- **원인**: 초기 구현 시 일부 필드 누락.
- **해결**: `UpdateOrganizationParams`, `MypageController`, `OrganizationService`에 해당 필드 추가 및 로직 구현.

---

## 6. 다음 Phase 준비 사항

- [ ] Phase 04 (Refactoring & Optimization) 계획 수립
- [ ] API 문서(Swagger) 최종 점검

---

## 7. 참고 사항

- `UpdateOrganizationRequest` DTO는 삭제되었으므로 향후 참조하지 않도록 주의.

---

## 📊 진행률 (Plan README 업데이트용)

```
Phase 03 ██████████ 100%  ✅
```

완료: 20/20 tasks
