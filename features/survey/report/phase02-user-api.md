# Phase 02 Report: 사용자 API

> 완료일: 2025-12-12

## 개요

사용자(USER)를 위한 설문조사 CRUD API와 Service 레이어, 단위 테스트를 구현했습니다.

---

## 완료 항목

### Domain 모듈 (sw-campus-domain)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `MemberSurveyService.java` | `domain/survey/` | ✅ | 비즈니스 로직 |
| `MemberSurveyServiceTest.java` | `test/.../domain/survey/` | ✅ | 단위 테스트 (6개) |

### API 모듈 (sw-campus-api)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `SurveyController.java` | `api/survey/` | ✅ | 사용자 설문조사 Controller |
| `CreateSurveyRequest.java` | `api/survey/request/` | ✅ | 생성 요청 DTO |
| `UpdateSurveyRequest.java` | `api/survey/request/` | ✅ | 수정 요청 DTO |
| `SurveyResponse.java` | `api/survey/response/` | ✅ | 응답 DTO (record) |

---

## 구현된 API

| Method | URL | 설명 | Status Code |
|:------:|-----|------|:-----------:|
| POST | `/api/v1/members/me/survey` | 설문조사 작성 | 201 Created |
| GET | `/api/v1/members/me/survey` | 내 설문조사 조회 | 200 OK |
| PUT | `/api/v1/members/me/survey` | 내 설문조사 수정 | 200 OK |

---

## 코드 리뷰 결과

### 코드룰 준수 확인

| 항목 | 상태 | 비고 |
|-----|:----:|------|
| 네이밍 컨벤션 | ✅ | `{Domain}Service`, `{Action}{Domain}Request`, `{Domain}Response` |
| 의존성 방향 | ✅ | Controller → Service → Repository |
| Request DTO 패턴 | ✅ | `@Getter`, `@NoArgsConstructor`, `@AllArgsConstructor` |
| Response DTO 패턴 | ✅ | record 패턴 + `from()` 정적 팩토리 |
| Controller 패턴 | ✅ | `SecurityContextHolder`로 memberId 추출 |
| Swagger 문서화 | ✅ | `@Tag`, `@Operation`, `@ApiResponses`, `@Schema` |
| URL 설계 | ✅ | `/api/v1/members/me/survey` (RESTful) |

### 기존 프로젝트 패턴 반영

- `CartController`의 `getCurrentUserId()` 패턴 동일 적용
- `LoginRequest` 패턴 (클래스 기반) → Request DTO에 적용
- `CartLectureResponse` 패턴 (record 기반) → Response DTO에 적용

---

## 테스트 결과

### MemberSurveyServiceTest (6개 테스트)

```
MemberSurveyServiceTest - 설문조사 서비스 테스트
├── createSurvey
│   ├── ✅ 성공 - 새 설문조사 생성
│   └── ✅ 실패 - 이미 설문조사가 존재하면 예외 발생
├── getSurveyByUserId
│   ├── ✅ 성공 - 설문조사 조회
│   └── ✅ 실패 - 설문조사가 없으면 예외 발생
└── updateSurvey
    ├── ✅ 성공 - 설문조사 수정
    └── ✅ 실패 - 설문조사가 없으면 예외 발생

BUILD SUCCESSFUL - 6 tests passed ✅
```

---

## 빌드 결과

```
BUILD SUCCESSFUL in 1s
14 actionable tasks: 3 executed, 11 up-to-date
```

---

## 다음 단계

- ✅ Phase 03: 관리자 API + 테스트 진행 완료
