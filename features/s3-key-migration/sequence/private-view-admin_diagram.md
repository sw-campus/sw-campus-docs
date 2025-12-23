# Private 이미지 조회 (관리자) - 시퀀스 다이어그램

## 관리자 수료증 확인 및 승인 (US-4)

```mermaid
sequenceDiagram
    autonumber

    actor Admin as 관리자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as DB<br/>(PostgreSQL)
    participant S3 as S3 Private<br/>(AWS)

    %% 1. 관리자 수료증 목록 요청
    Admin->>Client: 관리자 > 수료증 관리 접속
    Client->>Server: GET /api/v1/admin/certificates?status=PENDING<br/>Authorization: Bearer {adminToken}
    activate Server

    Note over Server: ROLE_ADMIN 권한 확인

    Server->>DB: PENDING 수료증 조회
    activate DB
    DB-->>Server: List<Certificate> (imageKey 포함)
    deactivate DB

    Server-->>Client: AdminCertificateListResponse
    deactivate Server

    %% 2. 특정 수료증 이미지 조회
    Admin->>Client: 수료증 상세 모달 열기

    Note over Client: S3Image 컴포넌트 렌더링

    Client->>Server: GET /api/v1/storage/presigned/url?key=certificates/...<br/>Authorization: Bearer {adminToken}
    activate Server

    Note over Server: Private key 판별<br/>(certificates/* = private)
    Note over Server: 관리자 권한 확인 (ROLE_ADMIN)

    alt 관리자 권한 있음
        Server->>S3: S3Presigner.presignGetObject()
        activate S3
        S3-->>Server: Presigned URL
        deactivate S3
        Server-->>Client: { url: "https://...", expiresIn: 900 }
    else 관리자 아님
        Server--xClient: 403 Forbidden<br/>"관리자만 접근 가능합니다"
    end
    deactivate Server

    %% 3. 이미지 로드
    Client->>S3: GET {presignedUrl}
    activate S3
    S3-->>Client: 이미지 바이너리
    deactivate S3

    Client-->>Admin: 수료증 이미지 표시

    %% 4. 승인/거절 처리
    rect rgb(240, 255, 240)
        Note over Admin,Server: 수료증 승인/거절 처리
        alt 승인
            Admin->>Client: 승인 버튼 클릭
            Client->>Server: PATCH /api/v1/admin/certificates/{id}/approve
            activate Server
            Server->>DB: 상태 변경 (APPROVED)
            DB-->>Server: OK
            Server-->>Client: 200 OK
            deactivate Server
            Client-->>Admin: "승인되었습니다"
        else 거절
            Admin->>Client: 거절 버튼 클릭
            Client->>Server: PATCH /api/v1/admin/certificates/{id}/reject
            activate Server
            Server->>DB: 상태 변경 (REJECTED)
            DB-->>Server: OK
            Server-->>Client: 200 OK
            deactivate Server
            Client-->>Admin: "거절되었습니다"
        end
    end
```

## 일반 사용자/기관의 Private 파일 접근 시도 (차단)

```mermaid
sequenceDiagram
    autonumber

    actor User as 일반 사용자/기관
    participant Client as Client
    participant Server as Server

    User->>Client: 본인이 업로드한 수료증 조회 시도

    Client->>Server: GET /api/v1/storage/presigned/url?key=certificates/...<br/>Authorization: Bearer {userToken}
    activate Server

    Note over Server: Private key 판별<br/>(certificates/* = private)
    Note over Server: ROLE_ADMIN 확인 → 실패<br/>(ROLE_USER 또는 ROLE_ORGANIZATION)

    Server--xClient: 403 Forbidden<br/>"관리자만 접근 가능합니다"
    deactivate Server

    Client-->>User: 접근 거부 메시지

    rect rgb(255, 240, 240)
        Note over User: ⚠️ 업로드한 본인도 조회 불가<br/>오직 관리자만 조회 가능
    end
```

## 참고사항

- Private 파일 접근은 **관리자 전용** (ROLE_ADMIN)
- 수료증을 업로드한 USER도 조회 불가
- 재직증명서를 업로드한 ORGANIZATION도 조회 불가
- 권한 체크 실패 시 403 Forbidden 반환
- 수료증 상태: PENDING → APPROVED 또는 REJECTED
