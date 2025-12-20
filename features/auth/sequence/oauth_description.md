## 필수 정보

### 1. 참여자 (Participants/Actors)
| 참여자 | 설명 | 기술 스택 |
|--------|------|-----------|
| 사용자 (User) | 서비스 이용자 | 브라우저 |
| 프론트엔드 (Frontend) | 웹 클라이언트 | Next.js + Nginx |
| 백엔드 (Backend) | API 서버 | Spring + Spring Security |
| OAuth Provider | 외부 인증 제공자 | Google, GitHub |
| DB (Database) | 데이터 저장소 | PostgreSQL |

### 2. 시나리오/흐름 설명
- OAuth 로그인 (신규 사용자) - 랜덤 닉네임 자동 생성
- OAuth 로그인 (기존 OAuth 사용자)
- OAuth 로그인 (기존 이메일 사용자 - 소셜 연동)

> **Note**: 일반 이메일 회원가입/로그인은 `signup_login_description.md` 참조
> **Note**: OAuth 신규 사용자는 랜덤 닉네임("사용자_" + UUID 8자리)이 자동 생성됩니다. phone, location은 선택 사항입니다.

### 3. 메시지 흐름 순서

#### 3-1. OAuth 로그인 흐름 (신규 사용자)
```
1. 사용자 → 프론트엔드: OAuth 로그인 버튼 클릭 (Google 또는 GitHub)
2. 프론트엔드: OAuth Provider의 인증 URL 생성
3. 프론트엔드 → OAuth Provider: 인증 페이지로 리다이렉트
4. 사용자 → OAuth Provider: 로그인 및 권한 승인
5. OAuth Provider → 프론트엔드: Authorization Code와 함께 콜백 URL로 리다이렉트
6. 프론트엔드 → 백엔드: Authorization Code 전달 (POST /api/v1/auth/oauth/{provider})
7. 백엔드 → OAuth Provider: Authorization Code로 Access Token 요청
8. OAuth Provider → 백엔드: Access Token 반환
9. 백엔드 → OAuth Provider: Access Token으로 사용자 정보 요청
10. OAuth Provider → 백엔드: 사용자 정보 반환 (이메일, 이름, providerId)
11. 백엔드 → DB: 소셜 계정 조회 (provider + providerId)
12. DB → 백엔드: 조회 결과 없음
13. 백엔드 → DB: 이메일로 기존 회원 조회
14. DB → 백엔드: 조회 결과 없음
15. 백엔드: 랜덤 닉네임 생성 ("사용자_" + UUID 8자리)
16. 백엔드 → DB: 신규 회원 저장 (자동 생성된 nickname, phone/location은 null)
17. DB → 백엔드: 저장 완료 (memberId 반환)
18. 백엔드 → DB: 소셜 계정 연동 정보 저장 (memberId, provider, providerId)
19. DB → 백엔드: 저장 완료
20. 백엔드: Access Token 생성 (JWT)
21. 백엔드: Refresh Token 생성 (JWT)
22. 백엔드 → DB: Refresh Token 저장
23. 백엔드 → 프론트엔드: 로그인 성공 응답 (토큰을 Cookie에 설정, nickname 포함)
24. 프론트엔드 → 사용자: 홈화면으로 이동
```

#### 3-2. OAuth 로그인 흐름 (기존 OAuth 사용자)
```
1. 사용자 → 프론트엔드: OAuth 로그인 버튼 클릭 (Google 또는 GitHub)
2. 프론트엔드: OAuth Provider의 인증 URL 생성
3. 프론트엔드 → OAuth Provider: 인증 페이지로 리다이렉트
4. 사용자 → OAuth Provider: 로그인 및 권한 승인
5. OAuth Provider → 프론트엔드: Authorization Code와 함께 콜백 URL로 리다이렉트
6. 프론트엔드 → 백엔드: Authorization Code 전달 (POST /api/v1/auth/oauth/{provider})
7. 백엔드 → OAuth Provider: Authorization Code로 Access Token 요청
8. OAuth Provider → 백엔드: Access Token 반환
9. 백엔드 → OAuth Provider: Access Token으로 사용자 정보 요청
10. OAuth Provider → 백엔드: 사용자 정보 반환 (이메일, 이름, providerId)
11. 백엔드 → DB: 소셜 계정 조회 (provider + providerId)
12. DB → 백엔드: 소셜 계정 정보 반환 (memberId 포함)
13. 백엔드 → DB: 회원 정보 조회 (memberId)
14. DB → 백엔드: 회원 정보 반환
15. 백엔드 → DB: 기존 Refresh Token 삭제
16. 백엔드: Access Token 생성 (JWT)
17. 백엔드: Refresh Token 생성 (JWT)
18. 백엔드 → DB: Refresh Token 저장
19. 백엔드 → 프론트엔드: 로그인 성공 응답 (토큰을 Cookie에 설정, nickname 포함)
20. 프론트엔드 → 사용자: 홈화면으로 이동
```

#### 3-3. OAuth 로그인 흐름 (기존 이메일 사용자 - 소셜 연동)
```
1. 사용자 → 프론트엔드: OAuth 로그인 버튼 클릭 (Google 또는 GitHub)
2. 프론트엔드: OAuth Provider의 인증 URL 생성
3. 프론트엔드 → OAuth Provider: 인증 페이지로 리다이렉트
4. 사용자 → OAuth Provider: 로그인 및 권한 승인
5. OAuth Provider → 프론트엔드: Authorization Code와 함께 콜백 URL로 리다이렉트
6. 프론트엔드 → 백엔드: Authorization Code 전달 (POST /api/v1/auth/oauth/{provider})
7. 백엔드 → OAuth Provider: Authorization Code로 Access Token 요청
8. OAuth Provider → 백엔드: Access Token 반환
9. 백엔드 → OAuth Provider: Access Token으로 사용자 정보 요청
10. OAuth Provider → 백엔드: 사용자 정보 반환 (이메일, 이름, providerId)
11. 백엔드 → DB: 소셜 계정 조회 (provider + providerId)
12. DB → 백엔드: 조회 결과 없음
13. 백엔드 → DB: 이메일로 기존 회원 조회
14. DB → 백엔드: 기존 회원 정보 반환 (이메일로 가입한 회원)
15. 백엔드 → DB: 소셜 계정 연동 정보 저장 (기존 memberId, provider, providerId)
16. DB → 백엔드: 저장 완료
17. 백엔드 → DB: 기존 Refresh Token 삭제
18. 백엔드: Access Token 생성 (JWT)
19. 백엔드: Refresh Token 생성 (JWT)
20. 백엔드 → DB: Refresh Token 저장
21. 백엔드 → 프론트엔드: 로그인 성공 응답 (토큰을 Cookie에 설정, nickname 포함)
22. 프론트엔드 → 사용자: 홈화면으로 이동
```

---

## 선택 정보 (더 정교한 다이어그램을 위해)

### 4. 조건부 흐름 (alt/opt)
| 시나리오 | 분기 조건 |
|----------|----------|
| OAuth 로그인 | 소셜 계정 존재 여부 |
| OAuth 로그인 | 이메일로 기존 회원 존재 여부 |

### 5. 반복 (loop)
- 없음

### 6. 병렬 처리 (par)
- 없음

### 7. 비동기 호출
- 없음

### 8. 노트/주석
- OAuth 제공자: Google, GitHub
- OAuth 사용자는 비밀번호가 null
- 소셜 계정은 여러 개 연동 가능 (Google + GitHub 동시 연동)
- 신규 OAuth 사용자는 랜덤 닉네임 자동 생성 ("사용자_" + UUID 8자리)
- phone, location은 선택 사항 (nullable)

---

## 추가 기술 정보

### OAuth 제공자별 정보
| Provider | 인증 URL | 토큰 URL | 사용자 정보 URL |
|----------|----------|----------|-----------------|
| Google | https://accounts.google.com/o/oauth2/v2/auth | https://oauth2.googleapis.com/token | https://www.googleapis.com/oauth2/v2/userinfo |
| GitHub | https://github.com/login/oauth/authorize | https://github.com/login/oauth/access_token | https://api.github.com/user |

### OAuth 흐름에서 얻는 사용자 정보
| Provider | providerId | email | name |
|----------|------------|-------|------|
| Google | id 필드 | email 필드 | name 필드 |
| GitHub | id 필드 (숫자) | /user/emails API 호출 필요 | name 필드 |

### 소셜 계정 연동 테이블 (social_accounts)
| 필드 | 설명 |
|------|------|
| id | PK |
| member_id | 연동된 회원 ID (FK) |
| provider | OAuth 제공자 (GOOGLE, GITHUB) |
| provider_id | 제공자에서 받은 고유 ID |
| created_at | 연동 일시 |

### OAuth 사용자 vs 일반 사용자
| 항목 | OAuth 사용자 | 일반 사용자 |
|------|-------------|-------------|
| password | null | BCrypt 암호화 |
| 이메일 인증 | 불필요 (이미 인증됨) | 필요 |
| 추가 정보 | OAuth 로그인 후 입력 | 회원가입 시 입력 |
| 로그인 방식 | OAuth 버튼 클릭 | 이메일 + 비밀번호 |

### 동일 이메일 처리 정책
| 상황 | 처리 방식 |
|------|----------|
| 이메일로 가입 후 같은 이메일의 Google로 로그인 | 기존 계정에 Google 연동 추가 |
| Google로 가입 후 같은 이메일의 GitHub로 로그인 | 기존 계정에 GitHub 연동 추가 |
| 이메일로 가입 후 같은 이메일의 OAuth로 재가입 시도 | 새 계정 생성 없이 연동만 추가 |

### 랜덤 닉네임 생성 규칙
| 항목 | 설명 |
|------|----------|
| 형식 | "사용자_" + UUID 8자리 |
| 예시 | "사용자_a1b2c3d4" |
| 생성 시점 | OAuth 신규 회원 등록 시 자동 생성 |
| 변경 | 회원 프로필 수정 API를 통해 변경 가능 |

### API 명세
| Method | Endpoint | 설명 | 인증 필요 |
|--------|----------|------|----------|
| POST | `/api/v1/auth/oauth/{provider}` | OAuth 로그인/회원가입 | X |

### Request/Response 형식

#### POST /api/v1/auth/oauth/{provider}
**Request:**
```json
{
  "code": "authorization_code_from_oauth_provider"
}
```

**Response (성공):**
```json
{
  "memberId": 1,
  "email": "user@gmail.com",
  "name": "홍길동",
  "nickname": "사용자_a1b2c3d4",
  "role": "USER"
}
```
+ Set-Cookie: accessToken, refreshToken

### 에러 케이스
| 상황 | HTTP Status | 에러 메시지 |
|------|-------------|------------|
| 유효하지 않은 Authorization Code | 400 | 유효하지 않은 인증 코드입니다 |
| OAuth Provider 응답 실패 | 502 | 외부 인증 서버 오류입니다 |
| 지원하지 않는 Provider | 400 | 지원하지 않는 OAuth 제공자입니다 |

### 프론트엔드 OAuth 콜백 URL
| Provider | 콜백 URL |
|----------|----------|
| Google | http://localhost:3000/oauth/callback/google |
| GitHub | http://localhost:3000/oauth/callback/github |

### OAuth 인증 흐름 (Authorization Code Grant)
```
1. 프론트엔드 → OAuth Provider: 인증 요청
   - client_id
   - redirect_uri
   - response_type=code
   - scope (email, profile 등)

2. OAuth Provider → 프론트엔드: Authorization Code 반환

3. 프론트엔드 → 백엔드: Authorization Code 전달

4. 백엔드 → OAuth Provider: Access Token 요청
   - client_id
   - client_secret
   - code
   - redirect_uri
   - grant_type=authorization_code

5. OAuth Provider → 백엔드: Access Token 반환

6. 백엔드 → OAuth Provider: 사용자 정보 요청
   - Authorization: Bearer {access_token}

7. OAuth Provider → 백엔드: 사용자 정보 반환
```
