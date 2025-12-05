# Phase 01: 프로젝트 설정

> 예상 시간: 1시간

## 1. 목표

개발 환경 및 프로젝트 의존성을 설정하고, 테스트 환경을 구축합니다.

---

## 2. 완료 조건 (Definition of Done)

- [ ] 필요한 의존성이 모두 추가됨
- [ ] Submodule 설정이 동기화됨
- [ ] 애플리케이션이 정상 실행됨
- [ ] 테스트가 정상 실행됨
- [ ] 환경별 설정 파일이 구성됨 (submodule)

---

## 3. Tasks

### 3.1 의존성 추가

**sw-campus-api/build.gradle**
```groovy
dependencies {
    // Spring Security
    implementation 'org.springframework.boot:spring-boot-starter-security'
    
    // JWT
    implementation 'io.jsonwebtoken:jjwt-api:0.12.3'
    runtimeOnly 'io.jsonwebtoken:jjwt-impl:0.12.3'
    runtimeOnly 'io.jsonwebtoken:jjwt-jackson:0.12.3'
    
    // OAuth2 Client
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-client'
    
    // Validation
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    
    // Mail
    implementation 'org.springframework.boot:spring-boot-starter-mail'
    
    // AWS S3
    implementation 'software.amazon.awssdk:s3:2.21.0'
    
    // Test
    testImplementation 'org.springframework.security:spring-security-test'
}
```

**sw-campus-domain/build.gradle**
```groovy
dependencies {
    // Spring Security (PasswordEncoder 등)
    implementation 'org.springframework.security:spring-security-core'
}
```

### 3.2 Submodule 설정 (민감 정보 관리)

> ⚠️ **중요**: 모든 민감한 설정(DB 정보, JWT Secret, OAuth 키 등)은 **Private Git Submodule**로 관리합니다.

#### Submodule 구조

```
sw-campus-server/
└── sw-campus-api/src/main/resources/
    ├── application.yml          # 공통 설정 (Git 추적됨)
    └── config/                   # 🔒 Submodule (Private Repo)
        ├── application-local.yml
        └── application-prod.yml
```

#### Submodule 초기화 및 업데이트

```bash
# 최초 클론 시 submodule 포함
git clone --recurse-submodules <repository-url>

# 기존 프로젝트에서 submodule 초기화
git submodule update --init --recursive

# submodule 최신 버전으로 업데이트
git submodule update --remote --merge
```

### 3.3 설정 파일 구조

#### 메인 설정 (application.yml) - 공개 저장소

> 이미 존재하는 파일에 Auth 관련 설정 추가

```yaml
spring:
  profiles:
    active: local
  config:
    import:
      - optional:classpath:logging.yml
      - optional:classpath:config/application-${spring.profiles.active}.yml  # Submodule 설정 import
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: none
    properties:
      hibernate:
        default_batch_fetch_size: 100
```

#### 환경별 설정 (Submodule) - Private 저장소

**config/application-local.yml**
```yaml
spring:
  # Database
  datasource:
    url: jdbc:postgresql://localhost:5432/swcampus
    username: postgres
    password: <local-password>
  
  # Mail (SMTP)
  mail:
    host: smtp.gmail.com
    port: 587
    username: <your-email>
    password: <app-password>
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: true
  
  # OAuth2
  security:
    oauth2:
      client:
        registration:
          google:
            client-id: <google-client-id>
            client-secret: <google-client-secret>
            scope: email, profile
          github:
            client-id: <github-client-id>
            client-secret: <github-client-secret>
            scope: user:email, read:user

# JWT
jwt:
  secret: <your-jwt-secret-key-at-least-32-characters>
  access-token-validity: 3600      # 1시간
  refresh-token-validity: 86400    # 1일

# AWS S3
aws:
  s3:
    bucket: s3-oneday
    region: ap-northeast-2
  credentials:
    access-key: <aws-access-key>
    secret-key: <aws-secret-key>
```

### 3.4 테스트 설정 (In-Memory)

> 테스트 설정은 민감 정보가 없으므로 메인 프로젝트에 위치

**src/test/resources/application-test.yml**
```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL
    driver-class-name: org.h2.Driver
    username: sa
    password:
  
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
  
  mail:
    host: localhost
    port: 3025  # GreenMail 등 테스트용

jwt:
  secret: test-secret-key-for-testing-purpose-only-32bytes!!
  access-token-validity: 3600
  refresh-token-validity: 86400

aws:
  s3:
    bucket: test-bucket
    region: ap-northeast-2
```

### 3.5 Submodule 설정 파일 추가 절차

1. **config 저장소로 이동** (별도 클론 필요)
   ```bash
   git clone https://github.com/sw-campus/config.git
   cd config
   ```

2. **Auth 설정 추가**
   ```bash
   # application-local.yml 수정 (JWT, OAuth, Mail, S3 설정 추가)
   vi application-local.yml
   ```

3. **커밋 및 푸시**
   ```bash
   git add .
   git commit -m "feat(auth): add JWT, OAuth, Mail, S3 configuration"
   git push origin main
   ```

4. **메인 프로젝트에서 submodule 업데이트**
   ```bash
   cd /path/to/sw-campus-server
   git submodule update --remote --merge
   ```

---

## 4. 검증

```bash
# 1. Submodule 상태 확인
git submodule status

# 2. 설정 파일 존재 확인
ls -la sw-campus-api/src/main/resources/config/

# 3. 빌드 확인
./gradlew build -x test

# 4. 애플리케이션 실행 확인
./gradlew :sw-campus-api:bootRun

# 5. 테스트 실행 확인
./gradlew test
```

---

## 5. 산출물

| 파일 | 위치 | 설명 |
|------|------|------|
| `sw-campus-api/build.gradle` | 메인 프로젝트 | API 모듈 의존성 |
| `sw-campus-domain/build.gradle` | 메인 프로젝트 | Domain 모듈 의존성 |
| `application.yml` | 메인 프로젝트 | 공통 설정 (import 경로 추가) |
| `application-test.yml` | 메인 프로젝트 | 테스트 설정 (H2) |
| `application-local.yml` | **Submodule (config)** | 로컬 환경 민감 정보 |

---

## 6. 참고: Submodule 관리 주의사항

### ⚠️ 절대 하지 말 것
- 민감 정보(비밀번호, API 키 등)를 메인 프로젝트에 커밋
- `.env` 파일을 Git에 추적

### ✅ 권장 사항
- config 저장소는 반드시 **Private**으로 유지
- 팀원에게 config 저장소 접근 권한 부여
- CI/CD에서는 환경변수 또는 Secrets Manager 사용

---

## 7. 다음 Phase

→ [Phase 02: Member 도메인](./phase02-member.md)
