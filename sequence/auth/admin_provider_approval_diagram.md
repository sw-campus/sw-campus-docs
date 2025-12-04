# 관리자 - 업체 승인 Sequence Diagrams

> **Note**: 관리자 로그인은 별도 로그인 페이지를 사용합니다. `admin_login_diagram.md` 참조

## 1. 승인 대기 업체 목록 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: 업체 관리 메뉴 클릭
    AdminFE->>Backend: GET /api/admin/providers<br/>?status=PENDING
    Backend->>DB: 승인 대기 상태<br/>업체 목록 조회
    DB-->>Backend: 업체 목록 반환
    Backend-->>AdminFE: 200 OK<br/>(업체 목록 데이터)
    AdminFE-->>Admin: 승인 대기 업체 목록 표시
```

---

## 2. 업체 상세 정보 및 재직증명서 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant S3 as S3
    participant DB as Database

    Admin->>AdminFE: 업체 상세보기 클릭
    AdminFE->>Backend: GET /api/admin/providers/{providerId}
    Backend->>DB: 업체 정보 조회
    DB-->>Backend: 업체 정보 반환<br/>(재직증명서 URL 포함)
    Backend-->>AdminFE: 200 OK<br/>(업체 상세 데이터)
    AdminFE->>S3: 재직증명서 이미지 요청
    S3-->>AdminFE: 이미지 반환
    AdminFE-->>Admin: 업체 상세 정보 +<br/>재직증명서 이미지 표시
```

---

## 3. 업체 승인

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: "승인" 버튼 클릭
    AdminFE->>Backend: PATCH /api/admin/providers/{providerId}/approve
    Backend->>DB: 업체 승인 상태 업데이트<br/>(approvalStatus: APPROVED)
    DB-->>Backend: 업데이트 완료
    Backend-->>AdminFE: 200 OK<br/>(승인 완료)
    AdminFE-->>Admin: 승인 완료 메시지 표시<br/>목록 새로고침
```

---

## 4. 업체 반려

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: "반려" 버튼 클릭
    AdminFE->>Backend: PATCH /api/admin/providers/{providerId}/reject
    Backend->>DB: 업체 반려 상태 업데이트<br/>(approvalStatus: REJECTED)
    DB-->>Backend: 업데이트 완료
    Backend-->>AdminFE: 200 OK<br/>(반려 완료)
    AdminFE-->>Admin: 반려 완료 메시지 표시<br/>목록 새로고침
```

---

## 5. 전체 업체 승인 흐름 요약

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드
    participant Backend as 백엔드
    participant S3 as S3
    participant DB as Database

    rect rgb(200, 230, 200)
        Note over Admin, DB: 1. 승인 대기 목록 조회
        Admin->>AdminFE: 업체 관리 메뉴
        AdminFE->>Backend: GET /api/admin/providers
        Backend->>DB: 승인 대기 업체 조회
        Backend-->>AdminFE: 업체 목록
        AdminFE-->>Admin: 목록 표시
    end

    rect rgb(200, 220, 240)
        Note over Admin, S3: 2. 업체 상세 조회
        Admin->>AdminFE: 상세보기 클릭
        AdminFE->>Backend: GET /api/admin/providers/{id}
        Backend->>DB: 업체 정보 조회
        Backend-->>AdminFE: 업체 상세 + 이미지 URL
        AdminFE->>S3: 재직증명서 이미지 요청
        S3-->>AdminFE: 이미지 반환
        AdminFE-->>Admin: 상세 정보 표시
    end

    rect rgb(200, 255, 200)
        Note over Admin, DB: 3. 승인 처리
        Admin->>AdminFE: "승인" 버튼 클릭
        AdminFE->>Backend: PATCH .../approve
        Backend->>DB: 상태 업데이트 (APPROVED)
        Backend-->>AdminFE: 200 OK
        AdminFE-->>Admin: 승인 완료
    end

    rect rgb(255, 200, 200)
        Note over Admin, DB: 4. 반려 처리
        Admin->>AdminFE: "반려" 버튼 클릭
        AdminFE->>Backend: PATCH .../reject
        Backend->>DB: 상태 업데이트 (REJECTED)
        Backend-->>AdminFE: 200 OK
        AdminFE-->>Admin: 반려 완료
    end
```
