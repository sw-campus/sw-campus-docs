## 필수 정보

### 1. 참여자 (Participants/Actors)
| 참여자 | 설명 | 기술 스택 |
|--------|------|-----------|
| 사용자 (User) | 서비스 이용자 | 브라우저 |
| 프론트엔드 (Frontend) | 웹 클라이언트 | Next.js + Nginx |
| 백엔드 (Backend) | API 서버 | Spring + Spring Security |
| S3 | 이미지 저장소 | AWS S3 |
| OAuth Provider | 외부 인증 제공자 | Google, GitHub |
| DB (Database) | 데이터 저장소 | - |

### 2. 시나리오/흐름 설명
- 일반 사용자 회원가입 프로세스 (이메일)
- 일반 사용자 회원가입 프로세스 (OAuth - Google, GitHub)
- 공급자(Provider) 회원가입 프로세스
- 로그인 및 JWT 인증 프로세스
- 로그아웃 프로세스

> **Note**: 관리자 로그인은 별도 페이지(/admin/login)를 사용합니다. `admin_login_description.md` 참조

### 3. 메시지 흐름 순서

#### 3-1. 일반 사용자 회원가입 흐름 (이메일)
```
1. 사용자 → 프론트엔드: 이메일 입력 후 "인증 메일 발송" 버튼 클릭
2. 프론트엔드 → 백엔드: 이메일 인증 요청 (POST /api/auth/email/send, signupType: "personal")
3. 백엔드 → DB: 이메일 중복 확인
4. DB → 백엔드: 조회 결과 반환
5. [조건] 이메일 사용 가능 시:
   - 백엔드 → DB: 인증 토큰 저장 (유효시간: 1시간)
   - 백엔드: 인증 메일 발송 (인증 링크에 type=personal 포함)
   - 백엔드 → 프론트엔드: 발송 완료 응답
   - 프론트엔드 → 사용자: "인증 메일을 확인해주세요" 메시지 표시
6. [조건] 이메일 중복 시:
   - 백엔드 → 프론트엔드: 에러 응답 (이메일 중복)
   - 프론트엔드 → 사용자: 에러 메시지 표시

7. 사용자: 이메일에서 인증 링크 클릭 (/auth/verify?token=xxx&type=personal)
8. 백엔드: 인증 토큰 검증 및 인증 완료 처리
9. 백엔드 → DB: 이메일 인증 상태 업데이트 (verified: true)
10. 백엔드 → 프론트엔드: /signup/personal?verified=true 로 리다이렉트

11. 사용자 → 프론트엔드: 회원가입 폼 제출 (비밀번호, 기타 정보)
12. 프론트엔드 → 백엔드: 회원가입 API 요청 (POST /api/auth/signup)
13. 백엔드 → DB: 사용자 정보 저장 (비밀번호는 BCrypt 암호화)
14. DB → 백엔드: 저장 완료
15. 백엔드 → 프론트엔드: 회원가입 성공 응답
16. 프론트엔드 → 사용자: 회원가입 성공, 로그인 페이지로 이동
```

#### 3-2. 일반 사용자 회원가입 흐름 (OAuth - Google, GitHub)
```
1. 사용자 → 프론트엔드: OAuth 로그인 버튼 클릭 (Google 또는 GitHub)
2. 프론트엔드 → OAuth Provider: OAuth 인증 페이지로 리다이렉트
3. 사용자 → OAuth Provider: 로그인 및 권한 승인
4. OAuth Provider → 프론트엔드: Authorization Code와 함께 콜백 URL로 리다이렉트
5. 프론트엔드 → 백엔드: Authorization Code 전달 (POST /api/auth/oauth/{provider})
6. 백엔드 → OAuth Provider: Access Token 요청
7. OAuth Provider → 백엔드: Access Token 반환
8. 백엔드 → OAuth Provider: 사용자 정보 요청
9. OAuth Provider → 백엔드: 사용자 정보 반환 (이메일, 이름 등)
10. 백엔드 → DB: 기존 사용자 조회 (이메일로 검색)
11. DB → 백엔드: 조회 결과 반환
12. [조건] 신규 사용자 시:
    - 백엔드 → DB: 사용자 정보 저장 (OAuth 연동 정보 포함)
    - DB → 백엔드: 저장 완료
13. [조건] 기존 사용자 시:
    - 백엔드 → DB: OAuth 연동 정보 업데이트 (필요 시)
14. 백엔드: Access Token 생성 (JWT)
15. 백엔드: Refresh Token 생성 (JWT)
16. 백엔드 → DB: Refresh Token 저장
17. 백엔드 → 프론트엔드: 로그인 성공 응답 (토큰을 Cookie에 설정)
18. 프론트엔드 → 사용자: 홈화면으로 이동
```

#### 3-3. 공급자(Provider) 회원가입 흐름
```
1. 사용자 → 프론트엔드: 이메일 입력 후 "인증 메일 발송" 버튼 클릭
2. 프론트엔드 → 백엔드: 이메일 인증 요청 (POST /api/auth/email/send, signupType: "organization")
3. 백엔드 → DB: 이메일 중복 확인
4. DB → 백엔드: 조회 결과 반환
5. [조건] 이메일 사용 가능 시:
   - 백엔드 → DB: 인증 토큰 저장 (유효시간: 1시간)
   - 백엔드: 인증 메일 발송 (인증 링크에 type=organization 포함)
   - 백엔드 → 프론트엔드: 발송 완료 응답
   - 프론트엔드 → 사용자: "인증 메일을 확인해주세요" 메시지 표시
6. [조건] 이메일 중복 시:
   - 백엔드 → 프론트엔드: 에러 응답 (이메일 중복)
   - 프론트엔드 → 사용자: 에러 메시지 표시

7. 사용자: 이메일에서 인증 링크 클릭 (/auth/verify?token=xxx&type=organization)
8. 백엔드: 인증 토큰 검증 및 인증 완료 처리
9. 백엔드 → DB: 이메일 인증 상태 업데이트 (verified: true)
10. 백엔드 → 프론트엔드: /signup/organization?verified=true 로 리다이렉트

11. 사용자 → 프론트엔드: 회원가입 폼 제출 (비밀번호, 재직증명서 이미지)
12. 프론트엔드 → 백엔드: 공급자 회원가입 API 요청 (POST /api/auth/signup/organization, 이미지 포함)
13. 백엔드 → S3: 재직증명서 이미지 업로드
14. S3 → 백엔드: 이미지 URL 반환
15. 백엔드 → DB: 공급자 정보 저장 (비밀번호 BCrypt 암호화, 이미지 URL, 승인상태: PENDING)
16. DB → 백엔드: 저장 완료
17. 백엔드 → 프론트엔드: 회원가입 성공 응답 (승인 대기 상태)
18. 프론트엔드 → 사용자: 회원가입 성공, "관리자 승인 후 이용 가능" 안내 표시
```
12. 백엔드 → 프론트엔드: 인증 완료 응답
13. 프론트엔드 → 사용자: 나머지 정보 입력 폼 활성화
14. 사용자 → 프론트엔드: 회원가입 폼 제출 (비밀번호, 재직증명서 이미지)
15. 프론트엔드 → 백엔드: 공급자 회원가입 API 요청 (POST /api/auth/signup/provider, 이미지 포함)
16. 백엔드 → S3: 재직증명서 이미지 업로드
17. S3 → 백엔드: 이미지 URL 반환
18. 백엔드 → DB: 공급자 정보 저장 (비밀번호 BCrypt 암호화, 이미지 URL, 승인상태: PENDING)
19. DB → 백엔드: 저장 완료
20. 백엔드 → 프론트엔드: 회원가입 성공 응답 (승인 대기 상태)
21. 프론트엔드 → 사용자: 회원가입 성공, "관리자 승인 후 이용 가능" 안내 표시
```

#### 3-4. 로그인 흐름
```
1. 사용자 → 프론트엔드: 로그인 폼 제출 (이메일, 비밀번호)
2. 프론트엔드 → 백엔드: 로그인 API 요청 (POST /api/auth/login)
3. 백엔드 → DB: 사용자 조회 (이메일로 검색)
4. DB → 백엔드: 사용자 정보 반환
5. 백엔드: 비밀번호 검증 (BCrypt 매칭)
6. [조건] 인증 성공 시:
   - 백엔드: Access Token 생성 (JWT)
   - 백엔드: Refresh Token 생성 (JWT)
   - 백엔드 → DB: Refresh Token 저장
   - DB → 백엔드: 저장 완료
   - 백엔드 → 프론트엔드: 로그인 성공 응답 (토큰을 Cookie에 설정)
   - 프론트엔드 → 사용자: 로그인 성공, 홈화면으로 이동
7. [조건] 인증 실패 시:
   - 백엔드 → 프론트엔드: 에러 응답 (401 Unauthorized)
   - 프론트엔드 → 사용자: 로그인 실패, 에러 메시지 표시
```

#### 3-5. 토큰 갱신 흐름 (Access Token 만료 시)
```
1. 사용자 → 프론트엔드: API 요청
2. 프론트엔드 → 백엔드: API 요청 (만료된 Access Token)
3. 백엔드 → 프론트엔드: 401 Unauthorized (토큰 만료)
4. 프론트엔드 → 백엔드: 토큰 갱신 요청 (POST /api/auth/refresh, Refresh Token)
5. 백엔드 → DB: Refresh Token 유효성 확인
6. DB → 백엔드: Refresh Token 정보 반환
7. [조건] Refresh Token 유효 시:
   - 백엔드: 새 Access Token 생성
   - 백엔드 → 프론트엔드: 새 Access Token 응답 (Cookie에 설정)
   - 프론트엔드 → 백엔드: 원래 API 재요청 (새 Access Token)
   - 백엔드 → 프론트엔드: API 응답
   - 프론트엔드 → 사용자: 결과 표시
8. [조건] Refresh Token 무효 시:
   - 백엔드 → 프론트엔드: 에러 응답 (401 Unauthorized)
   - 프론트엔드 → 사용자: 로그인 페이지로 이동
```

#### 3-6. 로그아웃 흐름
```
1. 사용자 → 프론트엔드: 로그아웃 버튼 클릭
2. 프론트엔드 → 백엔드: 로그아웃 API 요청 (POST /api/auth/logout)
3. 백엔드 → DB: Refresh Token 삭제
4. DB → 백엔드: 삭제 완료
5. 백엔드 → 프론트엔드: 로그아웃 성공 응답 (Cookie 삭제 지시)
6. 프론트엔드: Cookie에서 토큰 삭제
7. 프론트엔드 → 사용자: 로그아웃 완료, 홈화면으로 이동
```

---

## 선택 정보 (더 정교한 다이어그램을 위해)

### 4. 조건부 흐름 (alt/opt)
| 시나리오 | 분기 조건 |
|----------|-----------|
| 이메일 인증 | 이메일 사용 가능 / 중복 |
| 이메일 회원가입 | 인증 완료 후 진행 |
| OAuth 회원가입 | 신규 사용자 / 기존 사용자 |
| 로그인 | 성공 / 실패 |
| 토큰 갱신 | Refresh Token 유효 / 무효 |
| 로그아웃 | 없음 (단일 흐름) |

### 5. 반복 (loop)
- 없음

### 6. 병렬 처리 (par)
- 없음

### 7. 비동기 호출
- 이메일 발송 (백엔드 내부에서 비동기 처리 가능)

### 8. 노트/주석
- 이메일 인증 유효시간: 1시간
- OAuth 제공자: Google, GitHub

---

## 추가 기술 정보

### 사용자 유형
| 유형 | 설명 | 가입 방식 |
|------|------|----------|
| 일반 사용자 (User) | 서비스 이용자 | 이메일 + OAuth (Google, GitHub) |
| 공급자 (Provider) | 강의 등록 가능한 교육기관 재직자 | 이메일만 |
| 관리자 (Admin) | 시스템 관리자 | 사전 등록 (ROLE_ADMIN 권한 부여) |

### 관리자 권한
| 항목 | 설명 |
|------|------|
| 로그인 방식 | 별도 관리자 로그인 페이지 (/admin/login) |
| 권한 확인 | JWT 토큰에 ROLE_ADMIN 포함 여부 |
| API 접근 제어 | /api/admin/** 경로는 ROLE_ADMIN 권한 필수 |

> **Note**: 관리자 로그인 상세는 `admin_login_description.md` 참조

### 공급자 추가 정보
| 필드 | 설명 |
|------|------|
| certificateImageUrl | 재직증명서 이미지 S3 URL |
| approvalStatus | 승인 상태 (PENDING / APPROVED / REJECTED) |

### 공급자 승인 상태
| 상태 | 설명 | 기능 제한 |
|------|------|----------|
| PENDING | 승인 대기 | 로그인 가능, 강의 등록 불가 |
| APPROVED | 승인 완료 | 모든 기능 이용 가능 |
| REJECTED | 승인 거부 | 로그인 가능, 강의 등록 불가 |

### 인증/인가 방식
| 항목 | 설명 |
|------|------|
| 인증 방식 | JWT (JSON Web Token) |
| 토큰 종류 | Access Token + Refresh Token |
| 비밀번호 암호화 | BCrypt (Spring Security 기본) |
| 토큰 저장 위치 (클라이언트) | Cookie |
| Refresh Token 저장 위치 (서버) | Database |
| OAuth 제공자 | Google, GitHub |

### 이메일 인증
| 항목 | 설명 |
|------|------|
| 인증 방식 | 인증 링크 클릭 |
| 유효 시간 | 1시간 |
| 인증 링크 파라미터 | token (UUID), type (personal/organization) |
| 리다이렉트 | type에 따라 /signup/personal 또는 /signup/organization으로 이동 |
| 발송 서버 | 백엔드에서 직접 발송 |

### 보안 정책
| 항목 | 설명 |
|------|------|
| 로그인 시도 제한 | 없음 |
| 이메일 인증 | 미사용 |
| 소셜 로그인 | 추후 도입 예정 (현재 미포함) |

### 통신 방식
| 항목 | 설명 |
|------|------|
| 프론트엔드 ↔ 백엔드 | 클라이언트에서 직접 API 호출 |
| 호출 방식 | 동기 (Synchronous) |