# OAuth 인증 시스템 Sequence Diagrams

## 1. OAuth 로그인 (신규 사용자)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant OAuth as OAuth Provider<br/>(Google/GitHub)
    participant DB as Database

    User->>Frontend: OAuth 로그인 버튼 클릭<br/>(Google 또는 GitHub)
    Frontend->>OAuth: 인증 페이지로 리다이렉트<br/>(client_id, redirect_uri, scope)
    User->>OAuth: 로그인 및 권한 승인
    OAuth-->>Frontend: Authorization Code와 함께<br/>콜백 URL로 리다이렉트

    Frontend->>Backend: POST /api/v1/auth/oauth/{provider}<br/>(Authorization Code)
    
    Backend->>OAuth: Access Token 요청<br/>(code, client_id, client_secret)
    OAuth-->>Backend: Access Token 반환
    
    Backend->>OAuth: 사용자 정보 요청<br/>(Bearer Token)
    OAuth-->>Backend: 사용자 정보 반환<br/>(email, name, providerId)

    Backend->>DB: 소셜 계정 조회<br/>(provider + providerId)
    DB-->>Backend: 조회 결과 없음
    
    Backend->>DB: 이메일로 기존 회원 조회
    DB-->>Backend: 조회 결과 없음

    Note over Backend: 신규 사용자 처리<br/>랜덤 닉네임 생성

    Backend->>DB: 신규 회원 저장<br/>(랜덤 닉네임, email, name)
    DB-->>Backend: 저장 완료 (memberId)
    
    Backend->>DB: 소셜 계정 연동 저장<br/>(memberId, provider, providerId)
    DB-->>Backend: 저장 완료

    Note over Backend: JWT 토큰 생성

    Backend->>DB: Refresh Token 저장
    DB-->>Backend: 저장 완료
    
    Backend-->>Frontend: 200 OK + Set-Cookie<br/>(nickname 포함)
    Frontend-->>User: 홈화면으로 이동
```

---

## 2. OAuth 로그인 (기존 OAuth 사용자)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant OAuth as OAuth Provider<br/>(Google/GitHub)
    participant DB as Database

    User->>Frontend: OAuth 로그인 버튼 클릭
    Frontend->>OAuth: 인증 페이지로 리다이렉트
    User->>OAuth: 로그인 및 권한 승인
    OAuth-->>Frontend: Authorization Code 반환

    Frontend->>Backend: POST /api/v1/auth/oauth/{provider}<br/>(Authorization Code)
    
    Backend->>OAuth: Access Token 요청
    OAuth-->>Backend: Access Token 반환
    
    Backend->>OAuth: 사용자 정보 요청
    OAuth-->>Backend: 사용자 정보 반환

    Backend->>DB: 소셜 계정 조회<br/>(provider + providerId)
    DB-->>Backend: 소셜 계정 정보 반환<br/>(memberId 포함)

    Backend->>DB: 회원 정보 조회 (memberId)
    DB-->>Backend: 회원 정보 반환

    Backend->>DB: 기존 Refresh Token 삭제
    
    Note over Backend: JWT 토큰 생성

    Backend->>DB: Refresh Token 저장
    DB-->>Backend: 저장 완료

    Backend-->>Frontend: 200 OK + Set-Cookie<br/>(nickname 포함)
    Frontend-->>User: 홈화면으로 이동
```

---

## 3. OAuth 로그인 (기존 이메일 사용자 - 소셜 연동)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant OAuth as OAuth Provider<br/>(Google/GitHub)
    participant DB as Database

    User->>Frontend: OAuth 로그인 버튼 클릭
    Frontend->>OAuth: 인증 페이지로 리다이렉트
    User->>OAuth: 로그인 및 권한 승인
    OAuth-->>Frontend: Authorization Code 반환

    Frontend->>Backend: POST /api/v1/auth/oauth/{provider}<br/>(Authorization Code)
    
    Backend->>OAuth: Access Token 요청
    OAuth-->>Backend: Access Token 반환
    
    Backend->>OAuth: 사용자 정보 요청
    OAuth-->>Backend: 사용자 정보 반환

    Backend->>DB: 소셜 계정 조회<br/>(provider + providerId)
    DB-->>Backend: 조회 결과 없음

    Backend->>DB: 이메일로 기존 회원 조회
    DB-->>Backend: 기존 회원 정보 반환<br/>(이메일로 가입한 회원)

    Note over Backend: 기존 계정에 소셜 연동

    Backend->>DB: 소셜 계정 연동 저장<br/>(기존 memberId, provider, providerId)
    DB-->>Backend: 저장 완료

    Backend->>DB: 기존 Refresh Token 삭제
    
    Note over Backend: JWT 토큰 생성

    Backend->>DB: Refresh Token 저장
    DB-->>Backend: 저장 완료

    Backend-->>Frontend: 200 OK + Set-Cookie<br/>(nickname 포함)
    Frontend-->>User: 홈화면으로 이동
```

---

## 4. 전체 OAuth 흐름 요약

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant OAuth as OAuth Provider
    participant DB as Database

    rect rgb(255, 230, 200)
        Note over User, DB: OAuth 인증 (공통)
        User->>Frontend: OAuth 버튼 클릭
        Frontend->>OAuth: 인증 페이지 리다이렉트
        User->>OAuth: 로그인 & 승인
        OAuth-->>Frontend: Authorization Code
        Frontend->>Backend: Code 전달
        Backend->>OAuth: Access Token 요청
        OAuth-->>Backend: Access Token
        Backend->>OAuth: 사용자 정보 요청
        OAuth-->>Backend: 사용자 정보
    end

    rect rgb(230, 255, 200)
        Note over Backend, DB: 사용자 처리 분기
        Backend->>DB: 소셜 계정 조회
        
        alt 기존 소셜 계정 존재
            DB-->>Backend: 소셜 계정 정보
            Backend->>DB: 회원 조회
        else 소셜 계정 없음
            DB-->>Backend: 조회 결과 없음
            Backend->>DB: 이메일로 회원 조회
            
            alt 기존 이메일 회원 존재
                DB-->>Backend: 기존 회원 정보
                Backend->>DB: 소셜 연동 추가
            else 완전 신규
                DB-->>Backend: 조회 결과 없음
                Note over Backend: 랜덤 닉네임 생성
                Backend->>DB: 신규 회원 저장
                Backend->>DB: 소셜 연동 저장
            end
        end
    end

    rect rgb(200, 230, 255)
        Note over Backend, DB: 토큰 발급
        Backend->>DB: RT 삭제 (기존)
        Note over Backend: JWT 생성
        Backend->>DB: RT 저장
        Backend-->>Frontend: 토큰 + 회원정보 (nickname 포함)
    end

    Frontend-->>User: 홈화면 이동
```

---

## 5. OAuth Provider별 상세 흐름

### 5-1. Google OAuth

```mermaid
sequenceDiagram
    autonumber
    participant Backend as 백엔드
    participant Google as Google OAuth

    Note over Backend, Google: Access Token 획득

    Backend->>Google: POST https://oauth2.googleapis.com/token
    Note right of Backend: code, client_id,<br/>client_secret, redirect_uri,<br/>grant_type=authorization_code
    Google-->>Backend: { access_token, token_type, ... }

    Note over Backend, Google: 사용자 정보 조회

    Backend->>Google: GET https://www.googleapis.com/oauth2/v2/userinfo
    Note right of Backend: Authorization: Bearer {access_token}
    Google-->>Backend: { id, email, name, picture, ... }
```

### 5-2. GitHub OAuth

```mermaid
sequenceDiagram
    autonumber
    participant Backend as 백엔드
    participant GitHub as GitHub OAuth

    Note over Backend, GitHub: Access Token 획득

    Backend->>GitHub: POST https://github.com/login/oauth/access_token
    Note right of Backend: code, client_id, client_secret
    GitHub-->>Backend: { access_token, token_type, scope }

    Note over Backend, GitHub: 사용자 정보 조회

    Backend->>GitHub: GET https://api.github.com/user
    Note right of Backend: Authorization: Bearer {access_token}
    GitHub-->>Backend: { id, login, name, ... }

    Note over Backend, GitHub: 이메일 조회 (별도 API)

    Backend->>GitHub: GET https://api.github.com/user/emails
    Note right of Backend: Authorization: Bearer {access_token}
    GitHub-->>Backend: [{ email, primary, verified }, ...]
    
    Note over Backend: primary=true인 이메일 사용
```
