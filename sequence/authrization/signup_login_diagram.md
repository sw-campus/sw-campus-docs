# 인증 시스템 Sequence Diagrams

## 1. 일반 사용자 회원가입 (이메일)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(넷Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 이메일 입력 후<br/>"인증 메일 발송" 버튼 클릭
    Frontend->>Backend: POST /api/auth/email/send
    Backend->>DB: 이메일 중복 확인
    DB-->>Backend: 조회 결과 반환

    alt 이메일 사용 가능
        Backend->>DB: 인증 토큰 저장<br/>(유효시간: 1시간)
        Note over Backend: 인증 메일 발송
        Backend-->>Frontend: 발송 완료 응답
        Frontend-->>User: "인증 메일을 확인해주세요"

        Note over User: 이메일에서 인증 링크 클릭
        Backend->>DB: 이메일 인증 상태 업데이트<br/>(verified: true)
        
        User->>Frontend: "인증 확인" 버튼 클릭
        Frontend->>Backend: GET /api/auth/email/status
        Backend-->>Frontend: 인증 완료 응답
        
        Frontend-->>User: 나머지 정보 입력 폼 활성화
        User->>Frontend: 회원가입 폼 제출<br/>(비밀번호, 기타 정보)
        Frontend->>Backend: POST /api/auth/signup
        Backend->>DB: 사용자 정보 저장<br/>(비밀번호 BCrypt 암호화)
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 201 Created
        Frontend-->>User: 회원가입 성공<br/>로그인 페이지로 이동

    else 이메일 중복
        Backend-->>Frontend: 400 Bad Request<br/>(이메일 중복)
        Frontend-->>User: 에러 메시지 표시
    end
```

---

## 2. 일반 사용자 회원가입 (OAuth - Google, GitHub)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant OAuth as OAuth Provider<br/>(Google/GitHub)
    participant DB as Database

    User->>Frontend: OAuth 로그인 버튼 클릭<br/>(Google 또는 GitHub)
    Frontend->>OAuth: OAuth 인증 페이지로 리다이렉트
    User->>OAuth: 로그인 및 권한 승인
    OAuth-->>Frontend: Authorization Code와 함께<br/>콜백 URL로 리다이렉트
    Frontend->>Backend: POST /api/auth/oauth/{provider}<br/>(Authorization Code)
    Backend->>OAuth: Access Token 요청
    OAuth-->>Backend: Access Token 반환
    Backend->>OAuth: 사용자 정보 요청
    OAuth-->>Backend: 사용자 정보 반환<br/>(이메일, 이름 등)
    Backend->>DB: 기존 사용자 조회 (이메일)
    DB-->>Backend: 조회 결과 반환

    alt 신규 사용자
        Backend->>DB: 사용자 정보 저장<br/>(OAuth 연동 정보 포함)
        DB-->>Backend: 저장 완료
    else 기존 사용자
        Backend->>DB: OAuth 연동 정보 업데이트
    end

    Note over Backend: Access Token 생성 (JWT)
    Note over Backend: Refresh Token 생성 (JWT)
    Backend->>DB: Refresh Token 저장
    Backend-->>Frontend: 200 OK + Set-Cookie<br/>(Access Token, Refresh Token)
    Frontend-->>User: 홈화면으로 이동
```

---

## 3. 공급자(Provider) 회원가입

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자 (공급자)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 이메일 입력 후<br/>"인증 메일 발송" 버튼 클릭
    Frontend->>Backend: POST /api/auth/email/send
    Backend->>DB: 이메일 중복 확인
    DB-->>Backend: 조회 결과 반환

    alt 이메일 사용 가능
        Backend->>DB: 인증 토큰 저장<br/>(유효시간: 1시간)
        Note over Backend: 인증 메일 발송
        Backend-->>Frontend: 발송 완료 응답
        Frontend-->>User: "인증 메일을 확인해주세요"

        Note over User: 이메일에서 인증 링크 클릭
        Backend->>DB: 이메일 인증 상태 업데이트<br/>(verified: true)
        
        User->>Frontend: "인증 확인" 버튼 클릭
        Frontend->>Backend: GET /api/auth/email/status
        Backend-->>Frontend: 인증 완료 응답
        
        Frontend-->>User: 나머지 정보 입력 폼 활성화
        User->>Frontend: 회원가입 폼 제출<br/>(비밀번호, 사업자등록번호,<br/>사업주명, 사업자등록일)
        Frontend->>Backend: POST /api/auth/signup/provider
        Backend->>DB: 공급자 정보 저장<br/>(비밀번호 BCrypt 암호화)
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 201 Created
        Frontend-->>User: 회원가입 성공<br/>로그인 페이지로 이동

    else 이메일 중복
        Backend-->>Frontend: 400 Bad Request<br/>(이메일 중복)
        Frontend-->>User: 에러 메시지 표시
    end
```

---

## 4. 로그인 (Login)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring Security)
    participant DB as Database

    User->>Frontend: 로그인 폼 제출<br/>(이메일, 비밀번호)
    Frontend->>Backend: POST /api/auth/login
    Backend->>DB: 사용자 조회 (이메일)
    DB-->>Backend: 사용자 정보 반환
    
    Note over Backend: 비밀번호 검증<br/>(BCrypt 매칭)

    alt 인증 성공
        Note over Backend: Access Token 생성 (JWT)
        Note over Backend: Refresh Token 생성 (JWT)
        Backend->>DB: Refresh Token 저장
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 200 OK + Set-Cookie<br/>(Access Token, Refresh Token)
        Frontend-->>User: 로그인 성공<br/>홈화면으로 이동
    else 인증 실패
        Backend-->>Frontend: 401 Unauthorized
        Frontend-->>User: 로그인 실패<br/>에러 메시지 표시
    end
```

---

## 5. 토큰 갱신 (Token Refresh)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring Security)
    participant DB as Database

    User->>Frontend: API 요청
    Frontend->>Backend: API 요청<br/>(만료된 Access Token)
    Backend-->>Frontend: 401 Unauthorized<br/>(토큰 만료)
    
    Frontend->>Backend: POST /api/auth/refresh<br/>(Refresh Token)
    Backend->>DB: Refresh Token 유효성 확인
    DB-->>Backend: Refresh Token 정보 반환

    alt Refresh Token 유효
        Note over Backend: 새 Access Token 생성
        Backend-->>Frontend: 200 OK + Set-Cookie<br/>(새 Access Token)
        Frontend->>Backend: 원래 API 재요청<br/>(새 Access Token)
        Backend-->>Frontend: API 응답
        Frontend-->>User: 결과 표시
    else Refresh Token 무효
        Backend-->>Frontend: 401 Unauthorized
        Frontend-->>User: 로그인 페이지로 이동
    end
```

---

## 6. 로그아웃 (Logout)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring Security)
    participant DB as Database

    User->>Frontend: 로그아웃 버튼 클릭
    Frontend->>Backend: POST /api/auth/logout
    Backend->>DB: Refresh Token 삭제
    DB-->>Backend: 삭제 완료
    Backend-->>Frontend: 200 OK + Set-Cookie<br/>(Cookie 삭제 지시)
    
    Note over Frontend: Cookie에서 토큰 삭제
    
    Frontend-->>User: 로그아웃 완료<br/>홈화면으로 이동
```

---

## 전체 인증 흐름 요약

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant OAuth as OAuth Provider
    participant DB as Database

    rect rgb(255, 230, 200)
        Note over User, DB: 일반 사용자 회원가입 (이메일)
        User->>Frontend: 이메일 입력
        Frontend->>Backend: 인증 메일 요청
        Backend->>DB: 중복 확인 & 토큰 저장
        Note over Backend: 인증 메일 발송
        Note over User: 인증 링크 클릭
        User->>Frontend: "인증 확인" 버튼 클릭
        Frontend->>Backend: 인증 상태 확인
        User->>Frontend: 회원가입 정보 제출
        Frontend->>Backend: POST /api/auth/signup
        Backend->>DB: 사용자 저장
    end

    rect rgb(230, 255, 200)
        Note over User, DB: 일반 사용자 회원가입 (OAuth)
        User->>Frontend: OAuth 버튼 클릭
        Frontend->>OAuth: 인증 요청
        OAuth-->>Frontend: Authorization Code
        Frontend->>Backend: OAuth 처리
        Backend->>OAuth: 토큰 & 사용자 정보
        Backend->>DB: 사용자 저장/조회
        Backend-->>Frontend: JWT 토큰 (Cookie)
    end

    rect rgb(200, 230, 255)
        Note over User, DB: 공급자 회원가입
        User->>Frontend: 이메일 입력
        Frontend->>Backend: 인증 메일 요청
        Note over User: 인증 링크 클릭
        User->>Frontend: 회원가입 정보 제출<br/>(사업자 정보 포함)
        Frontend->>Backend: POST /api/auth/signup/provider
        Backend->>DB: 공급자 저장
    end

    rect rgb(200, 200, 230)
        Note over User, DB: 로그인
        User->>Frontend: 로그인 요청
        Frontend->>Backend: POST /api/auth/login
        Backend->>DB: 사용자 조회
        Backend-->>Frontend: JWT 토큰 (Cookie)
        Frontend-->>User: 홈화면 이동
    end

    rect rgb(230, 230, 200)
        Note over User, DB: 토큰 갱신
        Frontend->>Backend: 만료된 토큰으로 요청
        Backend-->>Frontend: 401 Unauthorized
        Frontend->>Backend: Refresh Token
        Backend-->>Frontend: 새 Access Token
    end

    rect rgb(230, 200, 200)
        Note over User, DB: 로그아웃
        User->>Frontend: 로그아웃 요청
        Frontend->>Backend: POST /api/auth/logout
        Backend->>DB: Refresh Token 삭제
        Backend-->>Frontend: Cookie 삭제
        Frontend-->>User: 홈화면 이동
    end
```
