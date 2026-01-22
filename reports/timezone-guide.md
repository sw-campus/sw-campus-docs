# Timezone 설정 가이드

## 문제 상황

- DB에 한국 시간(+09:00) 기준으로 저장된 `createdAt`
- 로컬에서는 정상 응답: `2026-01-20T16:15:37`
- 프로덕션에서 UTC로 변환되어 응답: `2026-01-20T07:15:37`

## 원인

| 환경 | OS/컨테이너 타임존 | JVM 타임존 | 결과 |
|------|-------------------|-----------|------|
| 로컬 (Windows/Mac) | Asia/Seoul | Asia/Seoul | 정상 |
| 프로덕션 (Docker/EKS) | UTC | UTC | 9시간 차이 |

### 동작 원리

1. DB에 `timestamp without time zone`으로 `16:15:37` 저장
2. JVM이 이 값을 읽을 때 **JVM 기본 타임존 기준**으로 해석
3. 프로덕션 JVM이 UTC면 → UTC로 변환하여 `07:15:37` 응답

## 해결 방법

### 1. JVM 옵션 (권장)

가장 확실한 방법. JVM 시작 시점부터 적용됨.

```bash
java -Duser.timezone=Asia/Seoul -jar app.jar
```

### 2. EKS (Kubernetes Deployment) - 권장

`server-deployment.yaml`에 환경 변수 추가:

```yaml
spec:
  containers:
    - name: server
      env:
        - name: TZ
          value: "Asia/Seoul"
        - name: JAVA_TOOL_OPTIONS
          value: "-Djava.net.preferIPv4Stack=true -Duser.timezone=Asia/Seoul"
```

**수정 위치:** `sw-campus-manifest/k8s/charts/sw-campus/templates/server-deployment.yaml` (48-49번 라인)

### 3. Docker (Dockerfile)

```dockerfile
ENV TZ=Asia/Seoul
```

Alpine 기반인 경우:
```dockerfile
RUN apk add --no-cache tzdata
ENV TZ=Asia/Seoul
```

### 4. Spring Boot (application.yml)

Hibernate 레벨에서 설정하는 방법:

```yaml
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          time_zone: Asia/Seoul
```

### 5. Java 코드에서 설정 (대안)

인프라 설정이 어려운 경우 코드로 설정 가능.

#### main() 메서드

```java
public static void main(String[] args) {
    TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"));
    SpringApplication.run(Application.class, args);
}
```
- Spring Context 로드 전에 적용

#### @PostConstruct

```java
@Configuration
public class TimeZoneConfig {
    @PostConstruct
    public void setTimeZone() {
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"));
    }
}
```
- Spring Bean 초기화 시점에 실행
- main()보다 늦게 적용됨

## 설정 방식 비교

| 방식 | 적용 시점 | 장점 | 단점 | 권장 |
|------|----------|------|------|------|
| JVM 옵션 (`-Duser.timezone`) | JVM 시작 시 | 가장 확실, 환경별 설정 가능 | 인프라 설정 필요 | **권장** |
| `TZ` 환경 변수 | 컨테이너 시작 시 | 간단함 | OS 레벨 설정 | 권장 |
| `main()` 메서드 | Spring 시작 전 | 코드로 관리 | 코드 수정 필요 | 대안 |
| `@PostConstruct` | Bean 초기화 시 | 코드로 관리 | 늦은 적용 | 대안 |
| Hibernate 설정 | DB 연결 시 | DB 레벨 제어 | JPA만 적용 | 보조 |

## 설정 우선순위

1. `TimeZone.setDefault()` (Java 코드)
2. `JAVA_TOOL_OPTIONS` 환경 변수
3. `-Duser.timezone` JVM 옵션
4. `TZ` 환경 변수 (OS 레벨)
5. Hibernate `jdbc.time_zone` 설정

## 확인 방법

### JVM 타임존 확인

```java
System.out.println(TimeZone.getDefault().getID());
// 예상 출력: Asia/Seoul
```

### API 응답 확인

```bash
curl -s https://api.example.com/some-endpoint | jq '.createdAt'
# 예상: "2026-01-20T16:15:37" (한국 시간)
```

## 관련 코드

- **BaseEntity:** `sw-campus-infra/db-postgres/src/main/java/com/swcampus/infra/postgres/BaseEntity.java`
  - `LocalDateTime createdAt` 필드 사용
- **Jackson 설정:** `application.yml`
  - `WRITE_DATES_AS_TIMESTAMPS: false` (ISO-8601 문자열 직렬화)
- **DB 스키마:** `timestamp(6) without time zone` (시간대 정보 없음)
