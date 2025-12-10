# 관리자 - 2단계 후기 검토 Sequence Diagrams

> ※ 사용자의 후기 작성 흐름은 기존 review 시퀀스 참고
> ※ 사용자는 OCR 통과 후 바로 후기 작성 가능 (관리자 사후 검토 방식)
> ※ **관리자는 2단계로 검토**: 1단계 수료증 → 2단계 후기 내용

## 1. 대기 중인 후기 목록 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: 후기 관리 메뉴 클릭
    AdminFE->>Backend: GET /api/v1/admin/reviews<br/>?status=PENDING
    Backend->>DB: 대기 중인 후기 목록 조회<br/>(수료증 또는 후기 PENDING)
    DB-->>Backend: 후기 목록 반환<br/>(작성자, 강의, 수료증 상태 포함)
    Backend-->>AdminFE: 200 OK<br/>(후기 목록 데이터)
    AdminFE-->>Admin: 대기 중인 후기 목록 표시<br/>(수료증/후기 승인 상태 구분)
```

---

## 2. [1단계 모달] 수료증 확인 및 승인

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant S3 as S3
    participant DB as Database

    Admin->>AdminFE: 후기 항목 클릭<br/>(수료증 미승인 상태)
    AdminFE->>Backend: GET /api/v1/admin/certificates/{certificateId}
    Backend->>DB: 수료증 정보 조회
    DB-->>Backend: 수료증 정보 반환<br/>(강의명, 수료증 URL)
    Backend-->>AdminFE: 200 OK<br/>(수료증 데이터)
    AdminFE->>S3: 수료증 이미지 요청
    S3-->>AdminFE: 이미지 반환
    AdminFE-->>Admin: [1단계 모달]<br/>강의명 + 수료증 이미지 표시

    Admin->>AdminFE: "수료증 승인" 버튼 클릭
    AdminFE->>Backend: PATCH /api/v1/admin/certificates/{certificateId}/approve
    Backend->>DB: 수료증 승인 상태 업데이트<br/>(approvalStatus: APPROVED)
    DB-->>Backend: 업데이트 완료
    Backend-->>AdminFE: 200 OK<br/>(승인 완료)
    AdminFE-->>Admin: [1단계 모달] 닫기<br/>→ [2단계 모달] 자동 표시
```

---

## 3. [1단계 모달] 수료증 반려

> **수료증 반려 시**: 반려 이메일 발송, 2단계(후기 검토)로 진행하지 않음

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant Email as 이메일 서버
    participant DB as Database

    Note over Admin, AdminFE: [1단계 모달] 수료증 확인 중

    Admin->>AdminFE: "수료증 반려" 버튼 클릭
    AdminFE->>Admin: 반려 확인 모달 표시
    Admin->>AdminFE: 반려 확인
    AdminFE->>Backend: PATCH /api/v1/admin/certificates/{certificateId}/reject
    Backend->>DB: 수료증 상태 변경<br/>(approvalStatus: REJECTED)
    Backend->>Email: 수료증 반려 이메일 발송
    DB-->>Backend: 처리 완료
    Backend-->>AdminFE: 200 OK<br/>(반려 완료)
    AdminFE-->>Admin: 반려 완료 메시지 표시<br/>목록 새로고침

    Note over Admin, DB: 수료증 반려됨<br/>2단계(후기 검토) 진행 안 함
```

---

## 4. [2단계 모달] 후기 내용 확인 및 승인

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Note over Admin, AdminFE: 수료증 승인 후 자동으로 2단계 모달 표시

    AdminFE->>Backend: GET /api/v1/admin/reviews/{reviewId}
    Backend->>DB: 후기 상세 정보 조회
    DB-->>Backend: 후기 데이터 반환<br/>(내용, 별점, 세부 점수)
    Backend-->>AdminFE: 200 OK<br/>(후기 상세 데이터)
    AdminFE-->>Admin: [2단계 모달]<br/>후기 내용 표시

    Admin->>AdminFE: "후기 승인" 버튼 클릭
    AdminFE->>Backend: PATCH /api/v1/admin/reviews/{reviewId}/approve
    Backend->>DB: 후기 승인 상태 업데이트<br/>(approvalStatus: APPROVED)
    DB-->>Backend: 업데이트 완료
    Backend-->>AdminFE: 200 OK<br/>(승인 완료)
    AdminFE-->>Admin: 승인 완료 메시지 표시<br/>목록 새로고침

    Note over Admin, DB: 후기 승인 완료 → 일반 사용자에게 노출됨
```

---

## 5. [2단계 모달] 후기 반려

> **후기 반려**: 수료증은 이미 승인된 상태, 후기 반려 이메일 발송

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant Email as 이메일 서버
    participant DB as Database

    Note over Admin, AdminFE: [2단계 모달] 후기 내용 확인 중<br/>(수료증은 이미 승인됨)

    Admin->>AdminFE: "후기 반려" 버튼 클릭
    AdminFE->>Admin: 반려 확인 모달 표시
    Admin->>AdminFE: 반려 확인
    AdminFE->>Backend: PATCH /api/v1/admin/reviews/{reviewId}/reject
    Backend->>DB: 후기 상태 변경<br/>(approvalStatus: REJECTED)
    Backend->>Email: 후기 반려 이메일 발송
    DB-->>Backend: 처리 완료
    Backend-->>AdminFE: 200 OK<br/>(반려 완료)
    AdminFE-->>Admin: 반려 완료 메시지 표시<br/>목록 새로고침

    Note over Admin, DB: 수료증은 APPROVED 유지<br/>후기만 REJECTED + 반려 이메일 발송
```

---

## 6. 후기 블라인드 처리 (승인된 후기 대상)

> **블라인드**: 후기가 목록에 **표시됨** (UI 처리는 프론트엔드에서 결정)
> (반려(REJECTED)는 목록에 아예 표시되지 않음)

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자
    participant AdminFE as 관리자 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>AdminFE: "블라인드" 버튼 클릭
    AdminFE->>Admin: 블라인드 확인 모달 표시
    Admin->>AdminFE: 블라인드 확인
    AdminFE->>Backend: PATCH /api/v1/admin/reviews/{reviewId}/blind<br/>{blurred: true}
    Backend->>DB: 블라인드 상태 업데이트<br/>(blurred: true)
    DB-->>Backend: 업데이트 완료
    Backend-->>AdminFE: 200 OK<br/>(블라인드 완료)
    AdminFE-->>Admin: 블라인드 완료 메시지 표시<br/>목록 새로고침

    Note over Admin, DB: 블라인드 해제 시 blurred: false로 요청
```

---

## 7. 전체 2단계 검토 흐름 요약

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
        Backend->>DB: 수료증 저장 (PENDING)<br/>후기 저장 (PENDING)
        Frontend-->>User: 작성 완료<br/>("승인 후 노출")
    end

    rect rgb(200, 230, 200)
        Note over Admin, DB: 관리자 후기 목록 조회
        Admin->>AdminFE: 후기 관리 메뉴
        AdminFE->>Backend: GET /api/v1/admin/reviews
        Backend->>DB: 대기 중인 후기 조회
        Backend-->>AdminFE: 후기 목록
        AdminFE-->>Admin: 목록 표시<br/>(수료증/후기 상태 구분)
    end

    rect rgb(200, 220, 240)
        Note over Admin, S3: [1단계 모달] 수료증 확인
        Admin->>AdminFE: 후기 항목 클릭
        AdminFE->>Backend: GET /api/v1/admin/certificates/{id}
        Backend->>DB: 수료증 정보 조회
        Backend-->>AdminFE: 강의명 + 수료증 URL
        AdminFE->>S3: 수료증 이미지 요청
        S3-->>AdminFE: 이미지 반환
        AdminFE-->>Admin: [1단계 모달] 수료증 표시
    end

    alt 수료증 승인
        rect rgb(200, 255, 200)
            Note over Admin, DB: 1단계 승인 → 2단계 자동 진행
            Admin->>AdminFE: "수료증 승인" 클릭
            AdminFE->>Backend: PATCH .../certificates/{id}/approve
            Backend->>DB: 수료증 APPROVED
            Backend-->>AdminFE: 200 OK
            AdminFE-->>Admin: [2단계 모달] 자동 표시
        end

        rect rgb(200, 220, 240)
            Note over Admin, DB: [2단계 모달] 후기 내용 확인
            AdminFE->>Backend: GET /api/v1/admin/reviews/{id}
            Backend->>DB: 후기 상세 조회
            Backend-->>AdminFE: 후기 데이터
            AdminFE-->>Admin: [2단계 모달] 후기 표시
        end

        alt 후기 승인
            rect rgb(200, 255, 200)
                Admin->>AdminFE: "후기 승인" 클릭
                AdminFE->>Backend: PATCH .../reviews/{id}/approve
                Backend->>DB: 후기 APPROVED
                Backend-->>AdminFE: 200 OK
                AdminFE-->>Admin: 승인 완료
            end
        else 후기 반려
            rect rgb(255, 200, 200)
                Admin->>AdminFE: "후기 반려" 클릭
                AdminFE->>Backend: PATCH .../reviews/{id}/reject
                Backend->>DB: 후기 REJECTED
                Note over Backend: 후기 반려 이메일 발송
                Backend-->>AdminFE: 200 OK
                AdminFE-->>Admin: 반려 완료
            end
        end
    else 수료증 반려
        rect rgb(255, 200, 200)
            Note over Admin, DB: 1단계 반려 → 반려 이메일 발송<br/>2단계 진행 안 함
            Admin->>AdminFE: "수료증 반려" 클릭
            AdminFE->>Backend: PATCH .../certificates/{id}/reject
            Backend->>DB: 수료증 REJECTED
            Note over Backend: 수료증 반려 이메일 발송
            Backend-->>AdminFE: 200 OK
            AdminFE-->>Admin: 반려 완료
        end
    end

    rect rgb(240, 220, 200)
        Note over Admin, DB: 블라인드 처리 (승인된 후기 대상)
        Admin->>AdminFE: "블라인드" 클릭
        AdminFE->>Backend: PATCH .../reviews/{id}/blind
        Backend->>DB: blurred: true
        Backend-->>AdminFE: 200 OK
        AdminFE-->>Admin: 블라인드 완료
    end
```

---

## 8. 사용자 후기 노출 상태 흐름

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant DB as Database

    Note over User, DB: 후기 작성 직후

    User->>Frontend: 강의 상세 페이지 접속
    Frontend->>Backend: GET /api/v1/lectures/{id}/reviews
    Backend->>DB: 승인된 후기만 조회<br/>(수료증 APPROVED + 후기 APPROVED)
    DB-->>Backend: 승인된 후기 목록
    Backend-->>Frontend: 200 OK
    Frontend-->>User: 승인된 후기만 표시<br/>(본인의 PENDING 후기는 미노출)
```
