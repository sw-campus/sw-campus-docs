# Phase 01 Report: 기반 구조

> 완료일: 2025-12-12

## 개요

설문조사 기능의 기반이 되는 Domain 객체, Repository 인터페이스, JPA Entity, Repository 구현체를 생성했습니다.

---

## 완료 항목

### Domain 모듈 (sw-campus-domain)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `MemberSurvey.java` | `domain/survey/` | ✅ | Domain 객체 |
| `MemberSurveyRepository.java` | `domain/survey/` | ✅ | Repository 인터페이스 |
| `SurveyNotFoundException.java` | `domain/survey/exception/` | ✅ | 설문조사 미존재 예외 |
| `SurveyAlreadyExistsException.java` | `domain/survey/exception/` | ✅ | 설문조사 중복 예외 |

### Infra 모듈 (sw-campus-infra/db-postgres)

| 파일 | 경로 | 상태 | 설명 |
|-----|------|:----:|------|
| `MemberSurveyEntity.java` | `infra/postgres/survey/` | ✅ | JPA Entity |
| `MemberSurveyJpaRepository.java` | `infra/postgres/survey/` | ✅ | Spring Data JPA |
| `MemberSurveyEntityRepository.java` | `infra/postgres/survey/` | ✅ | Repository 구현체 |

---

## 코드 리뷰 결과

### 코드룰 준수 확인

| 항목 | 상태 | 비고 |
|-----|:----:|------|
| 네이밍 컨벤션 | ✅ | `{Domain}`, `{Domain}Repository`, `{Domain}Entity` 패턴 |
| 의존성 방향 | ✅ | `api → domain ← infra` |
| 패키지 구조 | ✅ | 모듈별 survey 패키지 생성 |
| Domain 객체 패턴 | ✅ | `create()`, `of()`, `update()` 정적 팩토리 |
| Entity 변환 패턴 | ✅ | `from()`, `toDomain()`, `update()` |
| Repository 패턴 | ✅ | 인터페이스/구현체 분리 |
| 예외 패턴 | ✅ | 기존 `MemberNotFoundException` 동일 패턴 |

### 구현 상세

#### MemberSurvey (Domain 객체)
```java
// 정적 팩토리 메서드 패턴
public static MemberSurvey create(...)  // 신규 생성용
public static MemberSurvey of(...)      // Entity → Domain 변환용
public void update(...)                  // 수정용
```

#### MemberSurveyEntity (JPA Entity)
```java
@Entity
@Table(name = "member_surveys")
public class MemberSurveyEntity extends BaseEntity {
    @Id
    @Column(name = "user_id")
    private Long userId;  // 1:1 관계, FK가 PK
    ...
}
```

### 변경 사항

- **ErrorCode 미사용**: 기존 프로젝트에 `ErrorCode`, `BusinessException`이 없어서 `RuntimeException` 기반으로 구현
- 기존 `MemberNotFoundException` 패턴과 동일하게 적용

---

## 빌드 결과

```
BUILD SUCCESSFUL in 2s
14 actionable tasks: 7 executed, 7 up-to-date
```

---

## 다음 단계

- ✅ Phase 02: 사용자 API 진행 완료
