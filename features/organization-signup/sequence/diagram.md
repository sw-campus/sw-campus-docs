# 기관 회원가입 리팩토링 - 시퀀스 다이어그램

## 1. 기관 검색 흐름

```mermaid
sequenceDiagram
    participant U as 사용자
    participant F as 프론트엔드
    participant B as 백엔드
    participant DB as Database

    U->>F: 기관명 검색어 입력
    F->>B: GET /api/v1/auth/organizations/search?keyword=한국
    B->>DB: 기관명 LIKE 검색
    DB-->>B: 검색 결과 반환
    B-->>F: 200 OK (기관 목록)
    F-->>U: 검색 결과 드롭다운 표시
```

---

## 2. 기존 기관 선택 회원가입 흐름

```mermaid
sequenceDiagram
    participant U as 사용자
    participant F as 프론트엔드
    participant B as 백엔드
    participant S3 as S3
    participant DB as Database

    U->>F: 기존 기관 선택 + 회원가입 폼 제출
    F->>B: POST /api/v1/auth/signup/organization<br/>(organizationId 포함)

    B->>DB: 이메일 중복 확인
    DB-->>B: 조회 결과

    alt 이메일 중복
        B-->>F: 409 Conflict
        F-->>U: 에러 메시지 표시
    end

    B->>DB: 기관에 연결된 회원 존재 여부 확인
    DB-->>B: 조회 결과

    alt 이미 연결된 회원 존재
        B-->>F: 409 Conflict (중복 가입 불가)
        F-->>U: 에러 메시지 표시
    end

    B->>S3: 재직증명서 이미지 업로드
    S3-->>B: 이미지 URL 반환

    B->>DB: 기관 조회
    DB-->>B: 기관 정보 반환

    B->>DB: 재직증명서 URL 업데이트
    B->>DB: Member 생성 (orgId=선택 기관)
    DB-->>B: 저장 완료

    B-->>F: 201 Created (승인 대기)
    F-->>U: "관리자 승인 후 이용 가능" 안내
```

---

## 3. 신규 기관 회원가입 흐름

```mermaid
sequenceDiagram
    participant U as 사용자
    participant F as 프론트엔드
    participant B as 백엔드
    participant S3 as S3
    participant DB as Database

    U->>F: 신규 기관 회원가입 폼 제출
    F->>B: POST /api/v1/auth/signup/organization<br/>(organizationId 없음)

    B->>DB: 이메일 중복 확인
    DB-->>B: 조회 결과

    alt 이메일 중복
        B-->>F: 409 Conflict
        F-->>U: 에러 메시지 표시
    end

    B->>S3: 재직증명서 이미지 업로드
    S3-->>B: 이미지 URL 반환

    B->>DB: Member 생성 (Role=ORGANIZATION)
    DB-->>B: Member 저장 완료

    B->>DB: Organization 생성 (PENDING)
    DB-->>B: Organization 저장 완료

    B->>DB: Member.orgId 업데이트
    DB-->>B: 업데이트 완료

    B-->>F: 201 Created (승인 대기)
    F-->>U: "관리자 승인 후 이용 가능" 안내
```

---

## 4. 관리자 승인 흐름

```mermaid
sequenceDiagram
    participant A as 관리자
    participant F as 프론트엔드
    participant B as 백엔드
    participant DB as Database
    participant M as Mail Server

    A->>F: "승인" 버튼 클릭
    F->>B: PATCH /api/v1/admin/organizations/{orgId}/approve

    B->>DB: 기관에 연결된 Member 조회
    DB-->>B: Member 정보 반환

    B->>DB: Organization.userId = Member.id 업데이트
    B->>DB: Organization.approvalStatus = APPROVED
    DB-->>B: 업데이트 완료

    B->>M: 승인 이메일 발송 요청
    M-->>B: 발송 완료

    B-->>F: 200 OK (승인 완료)
    F-->>A: 승인 완료 메시지 표시

    Note over M: 이메일 내용:<br/>기관 회원 가입이 승인되었습니다.<br/>이제 모든 기능을 이용하실 수 있습니다.
```

---

## 5. 관리자 반려 흐름

```mermaid
sequenceDiagram
    participant A as 관리자
    participant F as 프론트엔드
    participant B as 백엔드
    participant DB as Database
    participant M as Mail Server

    A->>F: "반려" 버튼 클릭
    F->>B: PATCH /api/v1/admin/organizations/{orgId}/reject

    B->>DB: 기관에 연결된 Member 조회
    DB-->>B: Member 정보 반환

    B->>DB: ADMIN 역할 회원 조회
    DB-->>B: Admin 정보 반환

    B->>DB: Member 삭제
    Note right of DB: Organization은<br/>PENDING 상태 유지
    DB-->>B: 삭제 완료

    B->>M: 반려 이메일 발송 요청<br/>(관리자 연락처 포함)
    M-->>B: 발송 완료

    B-->>F: 200 OK (반려 완료, 관리자 연락처)
    F-->>A: 반려 완료 메시지 표시

    Note over M: 이메일 내용:<br/>기관 회원 가입이 반려되었습니다.<br/>문의: admin@swcampus.com
```

---

## 6. PENDING 상태 기능 제한 흐름

```mermaid
sequenceDiagram
    participant U as 기관 사용자 (PENDING)
    participant F as 프론트엔드
    participant B as 백엔드
    participant DB as Database

    U->>F: 강의 등록 시도
    F->>B: POST /api/v1/lectures

    B->>DB: 사용자의 기관 조회
    DB-->>B: Organization (status=PENDING)

    B->>B: getApprovedOrganizationByUserId()
    Note right of B: APPROVED가 아니면<br/>OrganizationNotApprovedException

    B-->>F: 403 Forbidden<br/>"승인 대기 중인 기관입니다"
    F-->>U: 에러 메시지 표시
```

---

## 7. 전체 흐름 개요

```mermaid
flowchart TB
    subgraph 회원가입
        A[이메일 인증] --> B{기관 선택}
        B -->|기존 기관| C[기관 검색/선택]
        B -->|신규 기관| D[기관명 입력]
        C --> E[회원가입 완료<br/>PENDING]
        D --> E
    end

    subgraph 관리자_승인
        E --> F[관리자 검토]
        F -->|승인| G[APPROVED<br/>+ 승인 이메일]
        F -->|반려| H[Member 삭제<br/>+ 반려 이메일]
    end

    subgraph 기능_이용
        G --> I[강의 등록 가능]
        G --> J[기관 정보 수정 가능]
        H --> K[재가입 가능<br/>동일 기관 선택]
    end

    style E fill:#fff3cd
    style G fill:#d4edda
    style H fill:#f8d7da
```

---

## 8. 데이터 상태 변화

```mermaid
stateDiagram-v2
    [*] --> 회원가입요청

    state 회원가입요청 {
        [*] --> Member생성
        Member생성 --> Organization연결: orgId 설정
    }

    회원가입요청 --> PENDING: 가입 완료

    PENDING --> APPROVED: 관리자 승인
    PENDING --> Member삭제: 관리자 반려

    APPROVED --> [*]: 정상 이용

    Member삭제 --> 재가입가능: Organization 유지
    재가입가능 --> 회원가입요청: 동일 기관 선택 가능

    note right of PENDING
        - 로그인 가능
        - 강의 등록 불가
        - 기관 정보 수정 불가
    end note

    note right of APPROVED
        - 모든 기능 이용 가능
        - Organization.userId 매핑 완료
    end note
```
