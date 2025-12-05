# Code Rules Index

> **AI 협업용 인덱스 문서**

이 문서를 컨텍스트로 제공하면 AI가 필요한 코드 규칙을 참조할 수 있습니다.  
문서 경로: `sw-campus-docs/code-rules/`

---

## 문서별 참조 가이드

### 01-module-structure.md
**참조 시점:** 새 파일/클래스 생성, 패키지 구조 결정

| 내용 | 설명 |
|------|------|
| 모듈 구조 | api, domain, infra, shared 모듈 역할 |
| 패키지 구조 | 각 모듈의 패키지 네이밍 및 구조 |
| 레이어별 책임 | 각 모듈에 포함/미포함되어야 할 것 |

### 02-naming-convention.md
**참조 시점:** 클래스, 메서드, 변수 네이밍

| 내용 | 설명 |
|------|------|
| 패키지 네이밍 | 소문자, 단수형 규칙 |
| 클래스 네이밍 | Controller, Service, Repository 등 패턴 |
| 메서드 네이밍 | CRUD 메서드명 패턴 |
| 변수 네이밍 | camelCase, 컬렉션 네이밍 등 |

### 03-dependency-rules.md
**참조 시점:** build.gradle 수정, 모듈 간 의존성 설정

| 내용 | 설명 |
|------|------|
| 의존성 방향 | domain 중심 의존성 흐름 |
| 의존성 매트릭스 | 모듈 간 허용/금지 의존성 |
| build.gradle 예시 | 각 모듈별 의존성 설정 방법 |

### 04-api-design.md
**참조 시점:** REST API 엔드포인트 설계, Controller 작성

| 내용 | 설명 |
|------|------|
| URL 설계 | 소문자, 복수형, 케밥케이스 규칙 |
| HTTP Method | GET, POST, PUT, PATCH, DELETE 사용법 |
| Status Code | 성공/실패 응답 코드 |
| Request/Response | DTO 형식, 페이징, 에러 응답 |

### 05-exception-handling.md
**참조 시점:** 예외 클래스 생성, 에러 처리 로직 작성

| 내용 | 설명 |
|------|------|
| 예외 구조 | BusinessException 계층 구조 |
| 에러 코드 | ErrorCode enum 정의 방법 |
| 전역 핸들러 | GlobalExceptionHandler 구현 |
| 도메인 예외 | 도메인별 커스텀 예외 작성법 |

### 06-design-principles.md
**참조 시점:** 설계 결정, 코드 리뷰, 리팩토링

| 내용 | 설명 |
|------|------|
| YAGNI | 필요할 때만 만들기 |
| 중복 허용 정책 | 레이어/모듈 경계의 중복 허용 기준 |
| 예광탄 개발 | 핵심 기능 먼저 관통 구현 |
| 깨진 창문 금지 | 나쁜 코드 방치 금지 |
| 우연 금지 | 이해 없이 넘어가지 않기 |
| 테스트 전략 | Domain TDD 권장, 나머지 선택적 |

---

## 작업별 참조 문서

| 작업 | 참조 문서 |
|------|----------|
| 새 도메인 추가 | 01, 02, 03 |
| Controller 작성 | 01, 02, 04 |
| Service 작성 | 01, 02, 06 |
| Repository 작성 | 01, 02, 03 |
| Entity 작성 | 01, 02, 03 |
| 예외 처리 추가 | 02, 05 |
| API 엔드포인트 설계 | 04 |
| build.gradle 수정 | 03 |
| 코드 리뷰 | 06 |
| 리팩토링 | 06 |

---

## AI 지시사항

코드 작성 시 해당 작업에 필요한 규칙 문서를 먼저 읽고 준수하십시오.

**핵심 원칙:**
- YAGNI: 현재 필요한 것만 구현
- 레이어 분리: `api → domain ← infra`
- 네이밍 컨벤션 준수
- Domain 레이어는 테스트 권장
