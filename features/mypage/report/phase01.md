# Phase 01: Structure - 구현 보고서

> 생성일: 2025-12-15
> 소요 시간: 1시간

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| **`UpdateProfileRequest.java`** | ✅ | Validation 적용 완료 |
| **`UpdateOrganizationRequest.java`** | ✅ | 재직증명서 파일 필드 포함 |
| **`SurveyRequest.java`** | ✅ | |
| **`MypageProfileResponse.java`** | ✅ | Provider 로직 구현 |
| **`MyReviewListResponse.java`** | ✅ | |
| **`MyLectureListResponse.java`** | ✅ | |
| **`OrganizationInfoResponse.java`** | ✅ | |
| **`SurveyResponse.java`** | ✅ | exists 필드 설명 추가 |
| `@RestController`, `@RequestMapping("/api/v1/mypage")` | ✅ | |
| **메서드 정의** (Return `null` or Empty Body) | ✅ | Swagger 문서화 적용 |
| 모든 DTO 클래스가 생성되었다. | ✅ | |
| `MypageController`가 생성되었고, Swagger UI에서 엔드포인트가 확인된다. | ✅ | |
| `./gradlew clean build -x test`가 성공한다. | ✅ | |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `sw-campus-api/.../mypage/MypageController.java` | 생성 | 마이페이지 컨트롤러 스켈레톤 |
| `sw-campus-api/.../mypage/request/UpdateProfileRequest.java` | 생성 | 프로필 수정 요청 DTO |
| `sw-campus-api/.../mypage/request/UpdateOrganizationRequest.java` | 생성 | 기관 정보 수정 요청 DTO |
| `sw-campus-api/.../mypage/request/SurveyRequest.java` | 생성 | 설문조사 요청 DTO |
| `sw-campus-api/.../mypage/response/MypageProfileResponse.java` | 생성 | 프로필 응답 DTO |
| `sw-campus-api/.../mypage/response/MyReviewListResponse.java` | 생성 | 후기 목록 응답 DTO |
| `sw-campus-api/.../mypage/response/MyLectureListResponse.java` | 생성 | 강의 목록 응답 DTO |
| `sw-campus-api/.../mypage/response/OrganizationInfoResponse.java` | 생성 | 기관 정보 응답 DTO |
| `sw-campus-api/.../mypage/response/SurveyResponse.java` | 생성 | 설문조사 응답 DTO |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 계획대로 진행된 항목

- 대부분의 Request/Response DTO 구조 및 필드 타입
- Controller의 기본 엔드포인트 URL 구조

### 3.2 변경된 항목

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| **용어** | 사업자등록증 | **재직증명서** | 도메인 정책 및 엔티티(`Organization.certificateUrl`) 반영 |
| **Response 필드** | `businessNumber`, `rejectReason` 포함 | **제거** | 도메인 모델(`Organization`, `Lecture`, `Review`)에 해당 필드 부재 |
| **메서드명** | `upsertSurvey` | **`saveSurvey`** | 네이밍 컨벤션 준수 (표준 동사 사용) |
| **Provider 로직** | 명시되지 않음 | **Password 유무로 판단** | OAuth 사용자는 비밀번호가 없음을 이용하여 `LOCAL`/`OAUTH` 구분 |

---

## 4. 검증 결과

### 4.1 빌드

```bash
$ ./gradlew clean build -x test

BUILD SUCCESSFUL in 3s
33 actionable tasks: 33 executed
```

### 4.2 테스트

Phase 01은 구조 잡기 단계로, 별도의 단위 테스트 코드는 작성하지 않았습니다. (Phase 02 로직 구현 시 작성 예정)

### 4.3 코드 리뷰 반영

| # | 심각도 | 이슈 | 해결 |
|---|--------|------|------|
| 1 | 🟠 Major | Swagger 문서화 미흡 | `@ApiResponses`, `@SecurityRequirement` 추가 완료 |
| 2 | 🟠 Major | 용어 불일치 (사업자등록증) | "재직증명서"로 용어 통일 및 주석 수정 |
| 3 | 🟡 Minor | 네이밍 컨벤션 위반 (`upsert`) | `saveSurvey`로 메서드명 변경 |

---

## 5. 발생한 이슈

### 이슈 1: 도메인 모델과 DTO 필드 불일치

- **증상**: Tech Spec에는 `rejectReason`(반려 사유)이나 `businessNumber`(사업자번호)가 있었으나, 실제 `Organization`, `Lecture`, `Review` 엔티티에는 해당 필드가 없음.
- **원인**: Tech Spec 작성 시점과 현재 도메인 모델 간의 동기화 부족.
- **해결**: 현재 도메인 모델에 맞춰 DTO에서 해당 필드를 제거함. 추후 도메인 모델 확장이 필요할 수 있음.

---

## 6. 다음 Phase 준비 사항

- [ ] **Phase 02: Business Logic**
    - `MypageService` 구현 필요 (없다면 기존 Service 활용 검토)
    - 각 Controller 메서드에 실제 비즈니스 로직 연결
    - 단위 테스트(ControllerTest, ServiceTest) 작성
    - 도메인 모델에 없는 필드(`rejectReason` 등)가 비즈니스적으로 필수라면 도메인 팀과 협의 필요

---

## 7. 참고 사항

- `MypageProfileResponse`의 프로필 이미지 URL은 현재 `null`로 반환 중이며, 추후 파일 업로드/조회 로직 구현 시 연동 필요.
- `OrganizationInfoResponse`의 대표자명은 현재 `Member.name`을 사용하도록 가정함.

---

## 📊 진행률

```
Phase 01 ██████████ 100% ✅
```

완료: 13/13 tasks
