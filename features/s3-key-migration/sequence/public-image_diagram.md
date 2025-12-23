# Public 이미지 조회 - 시퀀스 다이어그램

```mermaid
sequenceDiagram
    autonumber

    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as DB<br/>(PostgreSQL)
    participant S3 as S3<br/>(AWS)

    %% 1. 강의 상세 정보 요청
    User->>Client: 강의 상세 페이지 접속
    Client->>Server: GET /api/v1/lectures/{id}
    activate Server
    Server->>DB: 강의 정보 조회
    activate DB
    DB-->>Server: Lecture (lectureImageKey)
    deactivate DB
    Server-->>Client: LectureResponse { lectureImageKey: "lectures/..." }
    deactivate Server

    %% 2. S3Image 컴포넌트 렌더링
    Note over Client: S3Image 컴포넌트 렌더링<br/>usePresignedUrl(lectureImageKey)

    %% 3. React Query 캐시 확인
    alt 캐시 히트 (staleTime 5분 이내)
        Note over Client: 캐시된 Presigned URL 사용
    else 캐시 미스 또는 stale
        Client->>Server: GET /api/v1/storage/presigned/url?key=lectures/...
        activate Server
        Note over Server: Public key 확인<br/>(lectures/* = public)
        Server->>S3: S3Presigner.presignGetObject()
        activate S3
        S3-->>Server: Presigned URL 생성
        deactivate S3
        Server-->>Client: { url: "https://...?X-Amz-...", expiresIn: 900 }
        deactivate Server
        Note over Client: React Query 캐시 저장<br/>(staleTime: 5분)
    end

    %% 4. 이미지 로드
    Client->>S3: GET {presignedUrl}
    activate S3
    S3-->>Client: 이미지 바이너리
    deactivate S3

    Client-->>User: 이미지 렌더링
```

## 참고사항

- Public 파일 (`lectures/*`, `organizations/*`, `banners/*`, `teachers/*`)은 인증 없이 접근 가능
- Presigned URL 만료(15분) 전에 React Query staleTime(5분)이 먼저 도래하여 자동 갱신
- S3에 직접 요청하므로 Server 부하 최소화
