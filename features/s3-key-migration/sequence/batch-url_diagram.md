# 배치 Presigned URL 조회 - 시퀀스 다이어그램

```mermaid
sequenceDiagram
    autonumber

    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant S3 as S3Presigner<br/>(AWS SDK)
    participant S3Bucket as S3 Bucket

    %% 1. 강의 상세 정보 요청
    User->>Client: 강의 상세 페이지 접속
    Client->>Server: GET /api/v1/lectures/{id}
    activate Server
    Server-->>Client: LectureResponse {<br/>  lectureImageKey,<br/>  orgFacilityKeys[4],<br/>  teachers[].imageKey<br/>}
    deactivate Server

    %% 2. Key 수집 및 배치 요청
    Note over Client: usePresignedUrls hook<br/>모든 key 수집 (6~10개)

    Client->>Server: POST /api/v1/storage/presigned/url/batch<br/>{ keys: ["lectures/...", "organizations/...", ...] }
    activate Server

    %% 3. 각 key에 대해 Presigned URL 생성
    rect rgb(240, 248, 255)
        Note over Server,S3: 배치 처리 (네트워크 호출 없음)
        loop 각 key에 대해
            Note over Server: Public key 확인
            Server->>S3: presignGetObject(key)
            S3-->>Server: Presigned URL
        end
    end

    Server-->>Client: {<br/>  "lectures/...": "https://...?X-Amz-...",<br/>  "organizations/...": "https://...",<br/>  ...<br/>}
    deactivate Server

    Note over Client: React Query 캐시 저장<br/>(각 key별로 분리 저장)

    %% 4. 이미지 병렬 로드
    par 병렬 이미지 로드
        Client->>S3Bucket: GET {lectureImageUrl}
        S3Bucket-->>Client: 썸네일 이미지
    and
        Client->>S3Bucket: GET {facilityUrl1}
        S3Bucket-->>Client: 시설 이미지 1
    and
        Client->>S3Bucket: GET {facilityUrl2}
        S3Bucket-->>Client: 시설 이미지 2
    and
        Client->>S3Bucket: GET {teacherUrl}
        S3Bucket-->>Client: 강사 이미지
    end

    Client-->>User: 모든 이미지 렌더링 완료
```

## 캐시 최적화 흐름

```mermaid
sequenceDiagram
    autonumber

    participant Client as Client
    participant Cache as React Query<br/>Cache
    participant Server as Server

    Note over Client: 배치 요청 전 캐시 확인

    Client->>Cache: 캐시된 key 조회
    Cache-->>Client: 캐시 히트: ["lectures/a.jpg"]<br/>캐시 미스: ["org/b.jpg", "org/c.jpg"]

    alt 모든 key 캐시 히트
        Note over Client: API 호출 생략<br/>캐시된 URL 사용
    else 일부 또는 전체 캐시 미스
        Client->>Server: POST /batch<br/>{ keys: ["org/b.jpg", "org/c.jpg"] }<br/>(캐시 미스만 요청)
        Server-->>Client: { "org/b.jpg": "...", "org/c.jpg": "..." }
        Client->>Cache: 새 URL 캐시 저장
    end

    Note over Client: 모든 URL 확보<br/>이미지 로드 시작
```

## Private key 포함 시 처리

```mermaid
sequenceDiagram
    autonumber

    participant Client as Client
    participant Server as Server

    Note over Client: Public + Private key 혼합 요청

    alt 일반 사용자가 요청
        Client->>Server: POST /batch<br/>{ keys: ["lectures/a.jpg", "certificates/b.jpg"] }<br/>Authorization: Bearer {userToken}
        activate Server
        Note over Server: lectures/a.jpg → Public → OK
        Note over Server: certificates/b.jpg → Private → 권한 없음
        Server-->>Client: {<br/>  "lectures/a.jpg": "https://...",<br/>  "certificates/b.jpg": null<br/>}
        deactivate Server
        Note over Client: Private key는 null로 반환<br/>해당 이미지는 fallback 표시
    else 관리자가 요청
        Client->>Server: POST /batch<br/>{ keys: ["lectures/a.jpg", "certificates/b.jpg"] }<br/>Authorization: Bearer {adminToken}
        activate Server
        Note over Server: 모든 key 접근 가능 (ROLE_ADMIN)
        Server-->>Client: {<br/>  "lectures/a.jpg": "https://...",<br/>  "certificates/b.jpg": "https://..."<br/>}
        deactivate Server
    end
```

## 참고사항

- S3Presigner는 로컬에서 서명만 생성하므로 네트워크 호출 없음 (빠름)
- 배치 API는 N+1 문제 방지를 위해 필수
- Private key는 관리자만 URL 발급 가능, 일반 사용자는 null 반환
- 최대 50개까지 한 번에 요청 가능
