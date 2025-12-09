# 01. 모듈 구조 및 패키지 규칙

> Multi Module + Layer Architecture 원칙을 따릅니다.

---

## 📦 모듈 구조

```
sw-campus-server/
├── sw-campus-api/           # Presentation Layer
├── sw-campus-domain/        # Business Logic Layer
├── sw-campus-infra/         # Infrastructure Layer
│   ├── db-postgres/         # PostgreSQL (JPA)
│   └── file-s3/             # AWS S3
└── sw-campus-shared/        # Cross-cutting Concerns
    └── logging/             # 로깅
```

---

## 🎯 각 모듈의 책임

### sw-campus-api (Presentation Layer)

| 포함                 | 미포함                |
| -------------------- | --------------------- |
| REST Controller      | 비즈니스 로직         |
| Request/Response DTO | Entity 클래스         |
| 입력 검증 (@Valid)   | DB 접근 코드          |
| 인증/인가 설정       | 외부 서비스 직접 호출 |

**패키지 구조:**

```
com.swcampus.api/
├── {도메인}/
│   ├── {Domain}Controller.java
│   ├── request/
│   │   └── {Action}{Domain}Request.java
│   └── response/
│       └── {Domain}Response.java
├── config/                    # 설정 클래스
├── security/                  # 인증/인가
└── exception/                 # API 예외 핸들러
```

**예시:**

```
com.swcampus.api/
├── user/
│   ├── UserController.java
│   ├── request/
│   │   ├── CreateUserRequest.java
│   │   └── UpdateUserRequest.java
│   └── response/
│       └── UserResponse.java
```

---

### sw-campus-domain (Business Logic Layer)

| 포함                  | 미포함               |
| --------------------- | -------------------- |
| Domain 객체 (POJO)    | JPA Entity (@Entity) |
| Service 클래스        | Controller           |
| Repository 인터페이스 | Repository 구현체    |
| 비즈니스 규칙         | 프레임워크 의존 코드 |

**패키지 구조:**

```
com.swcampus.domain/
├── {도메인}/
│   ├── {Domain}.java              # 도메인 객체
│   ├── {Domain}Service.java       # 도메인 서비스
│   ├── {Domain}Repository.java    # 인터페이스
│   └── exception/                 # 도메인 예외
│       └── {Domain}NotFoundException.java
```

**예시:**

```
com.swcampus.domain/
├── user/
│   ├── User.java
│   ├── UserService.java
│   ├── UserRepository.java
│   └── exception/
│       └── UserNotFoundException.java
```

---

### sw-campus-infra (Infrastructure Layer)

| 포함                   | 미포함        |
| ---------------------- | ------------- |
| JPA Entity (@Entity)   | 비즈니스 로직 |
| Repository 구현체      | Controller    |
| 외부 서비스 클라이언트 | 도메인 객체   |
| DB 설정                | API 관련 코드 |

**패키지 구조:**

```
com.swcampus.infra.postgres/
├── {도메인}/
│   ├── {Domain}Entity.java           # JPA 엔티티
│   ├── {Domain}JpaRepository.java    # Spring Data JPA
│   ├── {Domain}EntityRepository.java # Repository 구현체
│   └── {Domain}Mapper.java           # Entity ↔ Domain 변환
├── config/                           # JPA 설정
└── BaseEntity.java                   # 공통 엔티티
```

**예시:**

```
com.swcampus.infra.postgres/
├── user/
│   ├── UserEntity.java
│   ├── UserJpaRepository.java
│   ├── UserEntityRepository.java
│   └── UserMapper.java
```

---

### sw-campus-shared (Cross-cutting Concerns)

| 포함           | 미포함              |
| -------------- | ------------------- |
| 로깅 설정      | 비즈니스 로직       |
| 공통 유틸리티  | 도메인 특화 코드    |
| 공통 에러 모델 | 특정 모듈 의존 코드 |

---

## ✅ 체크리스트

- [ ] Controller는 `api` 모듈에만 존재하는가?
- [ ] Entity는 `infra` 모듈에만 존재하는가?
- [ ] Domain 객체는 `domain` 모듈에만 존재하는가?
- [ ] Repository 인터페이스는 `domain`에, 구현체는 `infra`에 있는가?
- [ ] 각 도메인별로 패키지가 분리되어 있는가?
