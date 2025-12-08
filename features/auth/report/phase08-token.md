# Phase 08: 토큰 갱신 - 완료 보고서

> 완료일: 2025-12-08

## 1. 개요

Refresh Token을 사용한 Access Token 갱신 기능을 구현했습니다.

---

## 2. 완료 항목

| 항목 | 상태 | 비고 |
|------|------|------|
| 토큰 갱신 API 구현 | ✅ | `POST /api/v1/auth/refresh` |
| Refresh Token 유효성 검증 | ✅ | JWT 서명 + DB 일치 확인 |
| 새 Access Token 발급 | ✅ | 쿠키로 반환 |
| 만료된 Refresh Token 처리 | ✅ | DB 삭제 후 예외 발생 |
| 단위 테스트 | ✅ | 6개 테스트 케이스 |
| 통합 테스트 | ✅ | 4개 테스트 케이스 |

---

## 3. 구현 상세

### 3.1 API 엔드포인트

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| POST | `/api/v1/auth/refresh` | Access Token 갱신 | refreshToken 쿠키 필요 |

### 3.2 토큰 갱신 프로세스

```
1. refreshToken 쿠키 확인
2. JWT 유효성 검증 (서명, 만료)
3. 토큰에서 memberId 추출
4. DB에서 저장된 Refresh Token 조회
5. 토큰 값 일치 확인 (동시 로그인 제한)
6. DB 토큰 만료 여부 확인
7. 회원 정보 조회
8. 새 Access Token 발급 및 쿠키 반환
```

### 3.3 예외 처리

| 예외 | 상황 | HTTP 상태 |
|------|------|----------|
| `InvalidTokenException` | 토큰 없음, 유효하지 않은 토큰, DB 불일치 | 401 |
| `TokenExpiredException` | DB 토큰 만료 | 401 |

---

## 4. 생성/수정 파일

### 4.1 Domain 모듈

| 파일 | 변경 | 설명 |
|------|------|------|
| `AuthService.java` | 수정 | `refresh()` 메서드 추가 |
| `AuthServiceRefreshTest.java` | 생성 | 단위 테스트 (6개) |

### 4.2 API 모듈

| 파일 | 변경 | 설명 |
|------|------|------|
| `AuthController.java` | 수정 | `/refresh` 엔드포인트 추가 |
| `AuthControllerRefreshTest.java` | 생성 | 통합 테스트 (4개) |

### 4.3 Postman

| 파일 | 변경 | 설명 |
|------|------|------|
| `sw-campus-auth.postman_collection.json` | 생성 | Auth API 테스트 컬렉션 |

---

## 5. 테스트 결과

### 5.1 단위 테스트 (AuthServiceRefreshTest)

| 테스트 | 결과 |
|--------|------|
| 유효한 Refresh Token으로 새 Access Token 발급 | ✅ |
| 유효하지 않은 Refresh Token으로 갱신 실패 | ✅ |
| DB에 없는 Refresh Token으로 갱신 실패 | ✅ |
| 토큰 값 불일치 시 갱신 실패 (동시 로그인 제한) | ✅ |
| 만료된 Refresh Token으로 갱신 실패 | ✅ |
| 회원이 존재하지 않으면 갱신 실패 | ✅ |

### 5.2 통합 테스트 (AuthControllerRefreshTest)

| 테스트 | 결과 |
|--------|------|
| 토큰 갱신 성공 시 새 Access Token 쿠키 반환 | ✅ |
| Refresh Token 없으면 401 반환 | ✅ |
| 유효하지 않은 Refresh Token이면 401 반환 | ✅ |
| 만료된 Refresh Token이면 401 반환 | ✅ |

---

## 6. 코드 품질

### 6.1 네이밍 컨벤션 준수

- ✅ `AuthService.refresh()` - Service 메서드명 패턴
- ✅ `AuthController.refresh()` - Controller 메서드명 패턴
- ✅ `InvalidTokenException`, `TokenExpiredException` - 예외 네이밍

### 6.2 레이어 분리

- ✅ Controller: 쿠키 처리, HTTP 응답만 담당
- ✅ Service: 비즈니스 로직 (토큰 검증, 발급)
- ✅ Repository: 데이터 접근

### 6.3 보안

- ✅ JWT 서명 검증
- ✅ DB 토큰 일치 확인 (동시 로그인 제한)
- ✅ 만료 토큰 자동 삭제

---

## 7. 관련 User Stories 완료

| US | 설명 | 상태 |
|----|------|------|
| US-15 | Access Token 만료 시 자동 갱신 | ✅ |
| US-16 | Refresh Token 만료 시 재로그인 | ✅ |
| US-17 | 동시 로그인 제한 | ✅ |

---

## 8. 다음 단계

→ [Phase 09: 비밀번호 관리](../plan/phase09-password.md)
