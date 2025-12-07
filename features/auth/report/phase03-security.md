# Phase 03: Security + JWT - 구현 보고서

> 작성일: 2025-12-07
> 소요 시간: 약 1시간 30분

---

## 1. 완료 항목

| Task | 상태 | 비고 |
|------|------|------|
| JWT 의존성 추가 (domain/build.gradle) | ✅ | jjwt 0.12.3 |
| TokenProvider 구현 | ✅ | Access/Refresh Token 생성/검증 |
| TokenProviderTest 작성 | ✅ | 14개 테스트 케이스 |
| TokenInfo DTO 구현 | ✅ | Phase 05에서 사용 예정 |
| 예외 클래스 구현 | ✅ | TokenExpiredException, InvalidTokenException |
| SecurityConfig 구현 | ✅ | Filter Chain, PasswordEncoder |
| JwtAuthenticationFilter 구현 | ✅ | Cookie + Bearer 토큰 지원 |
| CookieUtil 구현 | ✅ | Phase 05에서 사용 예정 |
| 빌드 검증 | ✅ | `./gradlew build -x test` 성공 |

---

## 2. 생성/변경 파일 목록

### 2.1 생성된 파일

| 파일 | 위치 | 설명 |
|------|------|------|
| `TokenProvider.java` | domain/auth | JWT 토큰 생성/검증 |
| `TokenInfo.java` | domain/auth | 토큰 정보 DTO |
| `TokenExpiredException.java` | domain/auth/exception | 토큰 만료 예외 |
| `InvalidTokenException.java` | domain/auth/exception | 유효하지 않은 토큰 예외 |
| `TokenProviderTest.java` | domain/test/auth | TokenProvider 단위 테스트 |
| `SecurityConfig.java` | api/config | Spring Security 설정 |
| `JwtAuthenticationFilter.java` | api/security | JWT 인증 필터 |
| `CookieUtil.java` | api/config | Cookie 유틸리티 |

### 2.2 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `sw-campus-domain/build.gradle` | JWT 의존성 추가 (jjwt-api, jjwt-impl, jjwt-jackson) |

---

## 3. Plan 대비 변경 사항

### 3.1 TokenProvider 위치
| 항목 | Plan | 실제 적용 | 사유 |
|------|------|----------|------|
| TokenProvider | domain (api에 JWT 의존성) | domain (domain에 JWT 의존성) | domain에서 직접 사용하므로 의존성 이동 |

### 3.2 메서드명 변경
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| `getUserId()` | `getMemberId()` | 프로젝트 네이밍 컨벤션 (User → Member) |

### 3.3 SecurityConfig 설정 변경
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| `/api/v1/health` 허용 | 제거 | YAGNI - 해당 API 미구현, Actuator로 대체 |
| `/actuator/**` 허용 | `/actuator/health`만 허용 | 보안 강화 |

### 3.4 JwtAuthenticationFilter 추가 기능
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| Cookie만 지원 | Cookie + Authorization 헤더 지원 | API 테스트 및 모바일 클라이언트 지원 |

### 3.5 CorsConfig.java
| Plan | 실제 적용 | 사유 |
|------|----------|------|
| 구현 예정 | 미구현 | YAGNI - 현재 필요하지 않음, 필요 시 추가 |

---

## 4. 테스트 결과

### 4.1 TokenProviderTest (14개 테스트)

```
✅ Access Token 생성
  - Access Token을 생성할 수 있다
  - 생성된 Access Token에서 memberId를 추출할 수 있다
  - 생성된 Access Token에서 email을 추출할 수 있다
  - 생성된 Access Token에서 role을 추출할 수 있다

✅ Refresh Token 생성
  - Refresh Token을 생성할 수 있다
  - 생성된 Refresh Token에서 memberId를 추출할 수 있다

✅ 토큰 검증
  - 유효한 토큰은 검증에 성공한다
  - 만료된 토큰은 검증에 실패한다
  - 잘못된 형식의 토큰은 검증에 실패한다
  - null 토큰은 검증에 실패한다
  - 빈 문자열 토큰은 검증에 실패한다
  - 다른 secret으로 생성된 토큰은 검증에 실패한다

✅ 토큰 유효시간 조회
  - Access Token 유효시간을 조회할 수 있다
  - Refresh Token 유효시간을 조회할 수 있다
```

### 4.2 빌드 검증

```bash
$ ./gradlew build -x test
BUILD SUCCESSFUL in 1s
13 actionable tasks: 8 executed, 5 up-to-date
```

---

## 5. Security 설정 요약

### 5.1 인증 없이 접근 가능
| 엔드포인트 | 용도 |
|------------|------|
| `/api/v1/auth/**` | 로그인, 회원가입, 토큰 갱신 |
| `/actuator/health` | 헬스체크 (로드밸런서/K8s) |

### 5.2 인증 필요
- 위 엔드포인트를 제외한 모든 요청

### 5.3 토큰 추출 우선순위
1. Cookie (`accessToken`)
2. Authorization 헤더 (`Bearer {token}`)

---

## 6. YAGNI 적용 사항

| 파일 | 현재 상태 | 사용 시점 |
|------|----------|----------|
| `TokenInfo.java` | 생성됨, 미사용 | Phase 05 (로그인 응답) |
| `TokenExpiredException.java` | 생성됨, 미사용 | Phase 05 (토큰 갱신) |
| `InvalidTokenException.java` | 생성됨, 미사용 | Phase 05 (토큰 갱신) |
| `CookieUtil.java` | 생성됨, 미사용 | Phase 05 (로그인/로그아웃) |
| `CorsConfig.java` | 미생성 | 필요 시 추가 |

---

## 7. 다음 Phase 준비 사항

- [x] Spring Security 기본 설정 완료
- [x] JWT 토큰 생성/검증 구현 완료
- [ ] Phase 04: 이메일 인증 구현

---

## 8. 참고 사항

- JWT secret은 최소 32바이트 이상 필요 (HMAC-SHA256)
- 토큰 유효시간은 초 단위로 설정 (`jwt.access-token-validity`, `jwt.refresh-token-validity`)
- PasswordEncoder는 BCrypt (strength: 10) 사용
