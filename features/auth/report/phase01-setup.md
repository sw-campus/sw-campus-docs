# Phase 01: 프로젝트 설정 - 구현 보고서

> 작성일: 2025-12-05
> 소요 시간: 약 40분

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| 의존성 추가 (api/build.gradle) | ✅ | Security, JWT, OAuth2, Mail, Validation, H2 |
| 의존성 추가 (domain/build.gradle) | ✅ | Spring Security Core |
| application.yml 수정 | ✅ | Submodule config import 추가 |
| application-local.yml 생성 | ✅ | Submodule에 직접 생성 |
| application-test.yml 생성 | ✅ | H2 In-Memory 설정 |
| 빌드 검증 | ✅ | `./gradlew build -x test` 성공 |

---

## 2. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `sw-campus-api/build.gradle` | 수정 | Auth 관련 의존성 추가 |
| `sw-campus-domain/build.gradle` | 수정 | Spring Security Core 추가 |
| `sw-campus-infra/db-postgres/build.gradle` | 수정 | 의존성 규칙 위반 수정 |
| `sw-campus-api/src/main/resources/application.yml` | 수정 | Submodule import 추가 |
| `sw-campus-api/src/main/resources/config/application-local.yml` | 생성 | 로컬 환경 설정 (Submodule) |
| `sw-campus-api/src/test/resources/application-test.yml` | 생성 | 테스트 환경 설정 |

---

## 3. Tech Spec 대비 변경 사항

### 3.1 의존성 버전

| 항목 | Tech Spec | 실제 적용 | 사유 |
|------|-----------|----------|------|
| JWT (jjwt) | 0.12.x | 0.12.3 | 최신 안정 버전 |

### 3.2 추가 수정 사항

**db-postgres/build.gradle 의존성 수정**
- 기존: `compileOnly project(':sw-campus-api')` ❌
- 변경: `implementation project(':sw-campus-domain')` ✅
- 사유: 코드 룰 `03-dependency-rules.md` 위반 (infra → api 금지)

---

## 4. 환경 설정

### 4.1 Java 환경
```
openjdk version "17.0.17" 2025-10-21
OpenJDK Runtime Environment Homebrew (build 17.0.17+0)
```

### 4.2 Gradle
```
Gradle 8.14.3
```

---

## 5. 검증 결과

```bash
$ ./gradlew build -x test
BUILD SUCCESSFUL in 12s
13 actionable tasks: 5 executed, 8 up-to-date
```

---

## 6. 다음 Phase 준비 사항

- [x] PostgreSQL Docker 컨테이너 실행
- [ ] config/application-local.yml에 실제 값 설정 (Mail, OAuth, S3)

---

## 7. 참고 사항

- Submodule 설정 파일은 별도 Private 저장소에서 관리
- 테스트는 H2 In-Memory DB 사용 (PostgreSQL 모드)
