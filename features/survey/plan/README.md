# 설문조사 (Survey) - Development Plan

> 개발 계획서

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-12 |
| 목표 기간 | 0.5일 (4시간) |
| 개발 범위 | 백엔드 API Only |
| 참조 문서 | [PRD](../prd.md), [Tech Spec](../tech-spec.md) |

---

## 개발 일정 개요

| Phase | 내용 | 예상 시간 |
|:-----:|------|:--------:|
| 01 | 기반 구조 (Domain, Entity, Repository) | 1시간 |
| 02 | 사용자 API (CRU) | 1.5시간 |
| 03 | 관리자 API + 테스트 | 1.5시간 |
| **합계** | | **4시간** |

---

## Phase 구성

### [Phase 01: 기반 구조](./phase01-foundation.md)
- Domain 객체 (MemberSurvey)
- Repository 인터페이스
- JPA Entity
- Repository 구현체
- ErrorCode 정의

### [Phase 02: 사용자 API](./phase02-user-api.md)
- MemberSurveyService
- 설문조사 작성 API (POST)
- 설문조사 조회 API (GET)
- 설문조사 수정 API (PUT)

### [Phase 03: 관리자 API + 테스트](./phase03-admin-test.md)
- 전체 설문조사 목록 조회
- 특정 회원 설문조사 조회
- Domain 단위 테스트
- API 통합 테스트

---

## 의존성 순서

```
Phase 01 (기반 구조)
    │
    ├──▶ Phase 02 (사용자 API)
    │
    └──▶ Phase 03 (관리자 API + 테스트)
```

---

## 신규 생성 파일 목록

### Domain 모듈
```
sw-campus-domain/src/main/java/com/swcampus/domain/
└── survey/
    ├── MemberSurvey.java
    ├── MemberSurveyRepository.java
    ├── MemberSurveyService.java
    └── exception/
        ├── SurveyNotFoundException.java
        └── SurveyAlreadyExistsException.java
```

### Infra 모듈
```
sw-campus-infra/db-postgres/src/main/java/com/swcampus/infra/postgres/
└── survey/
    ├── MemberSurveyEntity.java
    ├── MemberSurveyJpaRepository.java
    └── MemberSurveyEntityRepository.java
```

### API 모듈
```
sw-campus-api/src/main/java/com/swcampus/api/
├── survey/
│   ├── SurveyController.java
│   ├── request/
│   │   ├── CreateSurveyRequest.java
│   │   └── UpdateSurveyRequest.java
│   └── response/
│       └── SurveyResponse.java
└── admin/
    └── AdminSurveyController.java
```

### Test
```
sw-campus-domain/src/test/java/com/swcampus/domain/survey/
└── MemberSurveyServiceTest.java

sw-campus-api/src/test/java/com/swcampus/api/
├── survey/
│   └── SurveyControllerTest.java
└── admin/
    └── AdminSurveyControllerTest.java
```

---

## 완료 현황

| Phase | 상태 | 완료일 |
|:-----:|:----:|:------:|
| 01 | ✅ 완료 | 2025-12-12 |
| 02 | ✅ 완료 | 2025-12-12 |
| 03 | ✅ 완료 | 2025-12-12 |

---

## 결과 보고서

개발 완료 후 결과는 [report/](../report/README.md)에서 확인할 수 있습니다.
