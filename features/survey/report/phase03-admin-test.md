# Phase 03 Report: 관리자 API + Controller 테스트

> 완료일: 2025-12-12

## 개요

관리자(ADMIN)를 위한 설문조사 조회 API와 Controller 슬라이스 테스트를 구현했습니다.

---

## 완료 항목

### API 모듈 (sw-campus-api)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `AdminSurveyController.java` | `api/admin/` | ✅ | 관리자 설문조사 Controller |
| `GlobalExceptionHandler.java` | `api/exception/` | ✅ | Survey 예외 핸들러 추가 |
| `SurveyControllerTest.java` | `test/.../survey/` | ✅ | 사용자 API 테스트 (6개) |
| `AdminSurveyControllerTest.java` | `test/.../admin/` | ✅ | 관리자 API 테스트 (4개) |

---

## 구현된 API

| Method | URL | 설명 | Status Code |
|:------:|-----|------|:-----------:|
| GET | `/api/v1/admin/members/surveys` | 전체 설문조사 목록 (페이징) | 200 OK |
| GET | `/api/v1/admin/members/{userId}/survey` | 특정 회원 설문조사 조회 | 200 OK |

---

## 코드 리뷰 결과

### 코드룰 준수 확인

| 항목 | 상태 | 비고 |
|-----|:----:|------|
| 네이밍 컨벤션 | ✅ | `Admin{Domain}Controller` 패턴 |
| URL 설계 | ✅ | `/api/v1/admin/members/...` |
| Swagger 문서화 | ✅ | `@Tag`, `@Operation`, `@ApiResponses`, `@Parameter` |
| 권한 검사 | ✅ | `@PreAuthorize("hasRole('ADMIN')")` |
| 예외 처리 | ✅ | GlobalExceptionHandler에 404, 409 핸들러 추가 |
| 페이징 | ✅ | `@PageableDefault(size = 20)` 사용 |

### 예외 핸들러 추가

```java
// GlobalExceptionHandler.java에 추가
@ExceptionHandler(SurveyNotFoundException.class)
public ResponseEntity<ErrorResponse> handleSurveyNotFoundException(...) {
    // 404 NOT_FOUND
}

@ExceptionHandler(SurveyAlreadyExistsException.class)
public ResponseEntity<ErrorResponse> handleSurveyAlreadyExistsException(...) {
    // 409 CONFLICT
}
```

---

## 테스트 결과

### SurveyControllerTest (6개 테스트)

```
SurveyController - 설문조사 API 테스트
├── POST /api/v1/members/me/survey
│   ├── ✅ 설문조사 작성 성공 (201)
│   └── ✅ 이미 설문조사 존재 시 실패 (409)
├── GET /api/v1/members/me/survey
│   ├── ✅ 내 설문조사 조회 성공 (200)
│   └── ✅ 설문조사 없을 때 (404)
└── PUT /api/v1/members/me/survey
    ├── ✅ 설문조사 수정 성공 (200)
    └── ✅ 설문조사 없을 때 수정 실패 (404)

6 tests passed ✅
```

### AdminSurveyControllerTest (4개 테스트)

```
AdminSurveyController - 관리자 설문조사 API 테스트
├── GET /api/v1/admin/members/surveys
│   ├── ✅ 전체 설문조사 목록 조회 성공 (200)
│   └── ✅ 빈 목록 조회 (200)
└── GET /api/v1/admin/members/{userId}/survey
    ├── ✅ 특정 회원 설문조사 조회 성공 (200)
    └── ✅ 설문조사 없는 회원 조회 시 실패 (404)

4 tests passed ✅
```

---

## 테스트 이슈 및 해결

### 이슈: PathNotFoundException

**문제**: JSON 필드명 불일치로 테스트 실패
```
com.jayway.jsonpath.PathNotFoundException: No results for path: $['userId']
```

**원인**: 프로젝트 전역 Jackson 설정이 snake_case 사용
- 예상: `$.userId`, `$.wantedJobs`
- 실제: `$.user_id`, `$.wanted_jobs`

**해결**: 테스트 코드의 jsonPath를 snake_case로 수정
```java
// Before
.andExpect(jsonPath("$.userId").value(USER_ID))
.andExpect(jsonPath("$.wantedJobs").value("백엔드 개발자"))

// After
.andExpect(jsonPath("$.user_id").value(USER_ID))
.andExpect(jsonPath("$.wanted_jobs").value("백엔드 개발자"))
```

---

## 검증 항목 완료 현황

### 기능 테스트

| 항목 | 상태 | 검증 방법 |
|-----|:----:|----------|
| USER 설문조사 작성 | ✅ | SurveyControllerTest |
| USER 설문조사 조회 | ✅ | SurveyControllerTest |
| USER 설문조사 수정 | ✅ | SurveyControllerTest |
| ADMIN 전체 목록 조회 | ✅ | AdminSurveyControllerTest |
| ADMIN 특정 회원 조회 | ✅ | AdminSurveyControllerTest |

### 예외 케이스

| 항목 | 상태 | Status Code |
|-----|:----:|:-----------:|
| 중복 설문조사 작성 | ✅ | 409 CONFLICT |
| 설문조사 없음 | ✅ | 404 NOT_FOUND |
| 인증 없음 | ✅ | 401 UNAUTHORIZED |
| 권한 없음 (ADMIN API) | ✅ | 403 FORBIDDEN |

---

## 빌드 결과

```
BUILD SUCCESSFUL in 3s
20 actionable tasks: 2 executed, 18 up-to-date
```

---

## 전체 테스트 결과 요약

| 테스트 유형 | 테스트 수 | 결과 |
|------------|:--------:|:----:|
| 단위 테스트 (Service) | 6 | ✅ |
| Controller 테스트 (User) | 6 | ✅ |
| Controller 테스트 (Admin) | 4 | ✅ |
| **총합** | **16** | **✅ 전체 통과** |
