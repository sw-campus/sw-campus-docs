# 마이페이지 (Mypage) Sequence Diagrams

## 1. 내 정보 관리 (Profile Management)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자 (User/Org)
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant DB as Database

    Note over User, DB: 1.1 내 정보 조회
    User->>Frontend: 마이페이지 접속
    Frontend->>Backend: GET /api/v1/mypage/profile
    Backend->>DB: 회원 정보 조회 (Member)
    
    alt Role == USER
        Backend->>DB: 설문조사 존재 여부 확인 (MemberSurvey)
    end

    DB-->>Backend: 조회 결과 반환
    Backend-->>Frontend: 200 OK (ProfileResponse)
    Frontend-->>User: 프로필 정보 표시

    Note over User, DB: 1.2 내 정보 수정
    User->>Frontend: 정보 수정 후 "저장" 클릭
    Frontend->>Backend: PATCH /api/v1/mypage/profile
    Backend->>DB: 회원 정보 업데이트
    DB-->>Backend: 업데이트 완료
    Backend-->>Frontend: 200 OK
    Frontend-->>User: "수정되었습니다" 메시지 표시
```

---

## 2. 내 후기 관리 (User Review Management)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자 (USER)
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant DB as Database

    Note over User, DB: 2.1 내 후기 목록 조회
    User->>Frontend: "내 후기" 탭 클릭
    Frontend->>Backend: GET /api/v1/mypage/reviews?page=0&size=10
    Backend->>DB: 작성한 후기 목록 조회 (Review)
    DB-->>Backend: 후기 목록 반환
    Backend-->>Frontend: 200 OK (Page<MyReviewListResponse>)
    Frontend-->>User: 후기 목록 표시 (상태 포함)

    Note over User, DB: 2.2 반려된 후기 수정
    User->>Frontend: 반려된 후기 "수정" 버튼 클릭
    Frontend->>User: 수정 폼 표시
    User->>Frontend: 내용 수정 후 "재승인 요청" 클릭
    Frontend->>Backend: PUT /api/v1/reviews/{reviewId} (기존 API 재사용)
    
    Backend->>DB: 후기 조회 및 권한/상태 확인
    DB-->>Backend: Review Entity
    
    alt 본인 아님 OR 상태 != REJECTED
        Backend-->>Frontend: 403 Forbidden / 400 Bad Request
    else 수정 가능
        Backend->>DB: 후기 내용 업데이트 & 상태 변경 (REJECTED -> PENDING)
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 200 OK
        Frontend-->>User: "수정되어 승인 대기 상태로 변경되었습니다"
    end
```

---

## 3. 설문조사 관리 (User Survey Management)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자 (USER)
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant DB as Database

    Note over User, DB: 3.1 설문조사 조회
    User->>Frontend: "설문조사" 탭 클릭
    Frontend->>Backend: GET /api/v1/mypage/survey
    Backend->>DB: 설문조사 데이터 조회 (MemberSurvey)
    DB-->>Backend: 결과 반환 (없으면 null)
    
    alt 데이터 없음
        Backend-->>Frontend: 200 OK (exists: false)
        Frontend-->>User: 빈 설문 폼 표시
    else 데이터 있음
        Backend-->>Frontend: 200 OK (exists: true, data...)
        Frontend-->>User: 작성된 설문 내용 표시
    end

    Note over User, DB: 3.2 설문조사 저장 (Upsert)
    User->>Frontend: 설문 작성/수정 후 "저장" 클릭
    Frontend->>Backend: PUT /api/v1/mypage/survey
    Backend->>DB: 설문조사 데이터 조회
    
    alt 데이터 존재 (Update)
        Backend->>DB: 기존 데이터 업데이트
    else 데이터 없음 (Insert)
        Backend->>DB: 신규 데이터 생성
    end
    
    DB-->>Backend: 저장 완료
    Backend-->>Frontend: 200 OK
    Frontend-->>User: "저장되었습니다"
```

---

## 4. 내 강의 관리 (Organization Lecture Management)

```mermaid
sequenceDiagram
    autonumber
    participant Org as 기관 담당자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant DB as Database

    Note over Org, DB: 4.1 내 강의 목록 조회
    Org->>Frontend: "강의 관리" 탭 클릭
    Frontend->>Backend: GET /api/v1/mypage/lectures
    Backend->>DB: 등록한 강의 목록 조회 (Lecture)
    DB-->>Backend: 강의 목록 반환
    Backend-->>Frontend: 200 OK (Page<MyLectureListResponse>)
    Frontend-->>Org: 강의 목록 표시 (상태 포함)

    Note over Org, DB: 4.2 반려된 강의 수정
    Org->>Frontend: 반려된 강의 "수정" 버튼 클릭
    Frontend->>Org: 수정 폼 표시
    Org->>Frontend: 내용 수정 후 "재승인 요청" 클릭
    Frontend->>Backend: PUT /api/v1/lectures/{lectureId} (기존 API 재사용)
    
    Backend->>DB: 강의 조회 및 권한/상태 확인
    DB-->>Backend: Lecture Entity
    
    alt 소유자 아님 OR 상태 != REJECTED
        Backend-->>Frontend: 403 Forbidden / 400 Bad Request
    else 수정 가능
        Backend->>DB: 강의 정보 업데이트 & 상태 변경 (REJECTED -> PENDING)
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 200 OK
        Frontend-->>Org: "수정되어 승인 대기 상태로 변경되었습니다"
    end
```
