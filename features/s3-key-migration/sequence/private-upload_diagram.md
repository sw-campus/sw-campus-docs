# Private 이미지 업로드 - 시퀀스 다이어그램

## USER 수료증 업로드 (US-2)

```mermaid
sequenceDiagram
    autonumber

    actor User as 일반 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as DB<br/>(PostgreSQL)
    participant S3 as S3 Private<br/>(AWS)

    %% 1. 수료증 제출 페이지 접속
    User->>Client: 수료증 제출 페이지 접속
    Client-->>User: 파일 업로드 UI 표시

    %% 2. 파일 선택 및 검증
    User->>Client: 수료증 이미지 파일 선택
    Note over Client: 파일 검증<br/>- 타입: JPEG, PNG<br/>- 크기: < 25MB

    %% 3. Presigned PUT URL 발급
    Client->>Server: POST /api/v1/storage/presigned/upload<br/>{ category: "certificates", fileName: "cert.jpg" }<br/>Authorization: Bearer {token}
    activate Server

    Note over Server: Private Bucket 선택<br/>key 생성: certificates/{date}/{uuid}.jpg

    Server->>S3: S3Presigner.presignPutObject()
    activate S3
    S3-->>Server: Presigned PUT URL
    deactivate S3

    Server-->>Client: { uploadUrl: "https://...", key: "certificates/..." }
    deactivate Server

    %% 4. S3 직접 업로드
    Client->>S3: PUT {uploadUrl}<br/>Content-Type: image/jpeg<br/>[이미지 바이너리]
    activate S3
    S3-->>Client: 200 OK
    deactivate S3

    Note over Client: 업로드 진행률 표시

    %% 5. 업로드 완료 처리
    Client->>Server: POST /api/v1/certificates/verify<br/>{ lectureId: 123, imageKey: "certificates/..." }
    activate Server

    Server->>DB: Certificate 저장 (PENDING 상태)
    activate DB
    DB-->>Server: OK
    deactivate DB

    Server-->>Client: { certificateId: 456, status: "PENDING" }
    deactivate Server

    Client-->>User: "수료증이 제출되었습니다.<br/>관리자 승인을 기다려주세요."

    %% 6. 조회 불가 안내
    rect rgb(255, 240, 240)
        Note over User,Client: ⚠️ 업로드 후 본인은 이미지 조회 불가<br/>관리자만 조회 가능
    end
```

## ORGANIZATION 재직증명서 업로드 (US-3)

```mermaid
sequenceDiagram
    autonumber

    actor Org as 기관 담당자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as DB<br/>(PostgreSQL)
    participant S3 as S3 Private<br/>(AWS)

    %% 1. 기관 정보 수정 페이지
    Org->>Client: 마이페이지 > 기관 정보 수정
    Client-->>Org: 기관 정보 수정 폼 표시

    %% 2. 재직증명서 파일 선택
    Org->>Client: 재직증명서/사업자등록증 파일 선택
    Note over Client: 파일 검증<br/>- 타입: JPEG, PNG, PDF<br/>- 크기: < 25MB

    %% 3. Presigned PUT URL 발급
    Client->>Server: POST /api/v1/storage/presigned/upload<br/>{ category: "members", fileName: "cert.pdf" }<br/>Authorization: Bearer {token}
    activate Server

    Note over Server: Private Bucket 선택<br/>key 생성: members/{date}/{uuid}.pdf

    Server->>S3: S3Presigner.presignPutObject()
    activate S3
    S3-->>Server: Presigned PUT URL
    deactivate S3

    Server-->>Client: { uploadUrl: "https://...", key: "members/..." }
    deactivate Server

    %% 4. S3 직접 업로드
    Client->>S3: PUT {uploadUrl}<br/>[파일 바이너리]
    activate S3
    S3-->>Client: 200 OK
    deactivate S3

    %% 5. 기관 정보 저장
    Client->>Server: PATCH /api/v1/mypage/organization<br/>{ certificateKey: "members/...", ... }
    activate Server

    Server->>DB: Organization 업데이트
    activate DB
    DB-->>Server: OK
    deactivate DB

    Server-->>Client: 200 OK
    deactivate Server

    Client-->>Org: "기관 정보가 저장되었습니다."

    %% 6. 조회 불가 안내
    rect rgb(255, 240, 240)
        Note over Org,Client: ⚠️ 업로드 후 본인은 이미지 조회 불가<br/>관리자만 조회 가능
    end
```

## 참고사항

- Private 파일은 반드시 Private Bucket에 업로드
- 업로드한 본인도 조회할 수 없음 (관리자만 가능)
- 수료증은 OCR 검증 후 PENDING 상태로 저장
- 재직증명서/사업자등록증은 기관 정보에 key만 저장
