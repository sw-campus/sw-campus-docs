# 관리자 - 수료증 승인 Sequence Diagrams

> ※ 사용자의 후기 작성 흐름은 기존 review 시퀀스 참고
> ※ 사용자는 OCR 통과 후 바로 후기 작성 가능 (관리자 사후 검토 방식)
> ※ 관리자는 후기 내용을 확인하지 않고, 수료증 이미지만 확인하여 승인/반려 처리

## 1. 승인 대기 후기 목록 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: 후기 관리 메뉴 클릭
    AdminFE->>Backend: GET /api/admin/reviews<br/>?status=PENDING
    Backend->>DB: 승인 대기 상태<br/>후기 목록 조회
    DB-->>Backend: 후기 목록 반환<br/>(작성자, 강의 정보 포함)
    Backend-->>AdminFE: 200 OK<br/>(후기 목록 데이터)
    AdminFE-->>Admin: 승인 대기 후기 목록 표시
```

---

## 2. 수료증 이미지 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(넷Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant S3 as S3
    participant DB as Database

    Admin->>AdminFE: 수료증 확인 버튼 클릭
    AdminFE->>Backend: GET /api/admin/reviews/{reviewId}/certificate
    Backend->>DB: 수료증 정보 조회
    DB-->>Backend: 수료증 정보 반환<br/>(강의명, 수료증 URL)
    Backend-->>AdminFE: 200 OK<br/>(수료증 데이터)
    AdminFE->>S3: 수료증 이미지 요청
    S3-->>AdminFE: 이미지 반환
    AdminFE-->>Admin: 강의명 +<br/>수료증 이미지 표시
```

---

## 3. 후기 승인

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: "승인" 버튼 클릭
    AdminFE->>Backend: PATCH /api/admin/reviews/{reviewId}/approve
    Backend->>DB: 후기 승인 상태 업데이트<br/>(approvalStatus: APPROVED)
    DB-->>Backend: 업데이트 완료
    Backend-->>AdminFE: 200 OK<br/>(승인 완료)
    AdminFE-->>Admin: 승인 완료 메시지 표시<br/>목록 새로고침
```

---

## 4. 후기 반려 (삭제)

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: "반려" 버튼 클릭
    AdminFE->>Admin: 반려 확인 모달 표시
    Admin->>AdminFE: 반려 확인
    AdminFE->>Backend: DELETE /api/admin/reviews/{reviewId}
    Backend->>DB: 후기 삭제<br/>(또는 REJECTED 상태 변경)
    DB-->>Backend: 처리 완료
    Backend-->>AdminFE: 200 OK<br/>(반려 완료)
    AdminFE-->>Admin: 반려 완료 메시지 표시<br/>목록 새로고침
```

---

## 5. 전체 수료증 검증 흐름 요약

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드
    participant Backend as 백엔드
    participant S3 as S3
    participant DB as Database

    rect rgb(230, 230, 230)
        Note over User, DB: 사용자 후기 작성 (기존 review 시퀀스)
        User->>Frontend: 후기 작성
        Frontend->>Backend: 수료증 OCR 인증
        Backend->>S3: 수료증 이미지 저장
        Backend->>DB: 후기 저장 (PENDING)
        Frontend-->>User: 작성 완료<br/>("승인 후 노출")
    end

    rect rgb(200, 230, 200)
        Note over Admin, DB: 1. 관리자 후기 목록 조회
        Admin->>AdminFE: 후기 관리 메뉴
        AdminFE->>Backend: GET /api/admin/reviews
        Backend->>DB: 승인 대기 후기 조회
        Backend-->>AdminFE: 후기 목록
        AdminFE-->>Admin: 목록 표시
    end

    rect rgb(200, 220, 240)
        Note over Admin, S3: 2. 수료증 이미지 조회
        Admin->>AdminFE: 수료증 확인 클릭
        AdminFE->>Backend: GET /api/admin/reviews/{id}/certificate
        Backend->>DB: 수료증 정보 조회
        Backend-->>AdminFE: 강의명 + 수료증 URL
        AdminFE->>S3: 수료증 이미지 요청
        S3-->>AdminFE: 이미지 반환
        AdminFE-->>Admin: 수료증 표시
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
        AdminFE->>Admin: 반려 확인
        AdminFE->>Backend: DELETE .../reviews/{id}
        Backend->>DB: 후기 삭제/반려
        Backend-->>AdminFE: 200 OK
        AdminFE-->>Admin: 반려 완료
    end
```

---

## 6. 사용자 후기 노출 상태 흐름

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant DB as Database

    Note over User, DB: 후기 작성 직후

    User->>Frontend: 강의 상세 페이지 접속
    Frontend->>Backend: GET /api/lectures/{id}/reviews
    Backend->>DB: 승인된 후기만 조회<br/>(approvalStatus: APPROVED)
    DB-->>Backend: 승인된 후기 목록
    Backend-->>Frontend: 200 OK
    Frontend-->>User: 승인된 후기만 표시<br/>(본인의 PENDING 후기는 미노출)
```
