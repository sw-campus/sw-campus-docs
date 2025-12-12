# 설문조사 시퀀스 다이어그램

## 1. 설문조사 작성

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자<br/>(USER)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 설문조사 페이지 접근
    Frontend->>Backend: GET /api/v1/members/me/survey<br/>(기존 설문 확인)
    Backend->>DB: 설문조사 조회 (user_id)
    DB-->>Backend: 조회 결과 반환

    alt 설문조사 없음 (404)
        Backend-->>Frontend: 404 Not Found
        Frontend-->>User: 빈 설문조사 폼 표시
        
        User->>Frontend: 설문 항목 입력 후 제출
        Frontend->>Backend: POST /api/v1/members/me/survey
        Backend->>DB: 설문조사 저장
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 201 Created + 설문 데이터
        Frontend-->>User: 작성 완료 메시지

    else 설문조사 존재 (200)
        Backend-->>Frontend: 200 OK + 기존 설문 데이터
        Frontend-->>User: 기존 설문으로 폼 표시<br/>(수정 모드)
    end
```

---

## 2. 설문조사 조회 (본인)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자<br/>(USER)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 마이페이지 > 설문조사 클릭
    Frontend->>Backend: GET /api/v1/members/me/survey
    Note over Backend: JWT에서 userId 추출
    Backend->>DB: 설문조사 조회 (user_id)
    DB-->>Backend: 조회 결과 반환

    alt 설문조사 존재
        Backend-->>Frontend: 200 OK + 설문 데이터
        Frontend-->>User: 설문 내용 표시

    else 설문조사 없음
        Backend-->>Frontend: 404 Not Found
        Frontend-->>User: "설문조사를 작성해주세요" 안내
    end
```

---

## 3. 설문조사 수정

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자<br/>(USER)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 설문조사 수정 버튼 클릭
    Frontend-->>User: 수정 가능한 폼 표시<br/>(기존 데이터 로드)
    User->>Frontend: 항목 수정 후 저장 클릭
    Frontend->>Backend: PUT /api/v1/members/me/survey
    Note over Backend: JWT에서 userId 추출
    Backend->>DB: 설문조사 존재 여부 확인
    DB-->>Backend: 조회 결과 반환

    alt 설문조사 존재
        Backend->>DB: 설문조사 업데이트
        DB-->>Backend: 업데이트 완료
        Backend-->>Frontend: 200 OK + 수정된 설문 데이터
        Frontend-->>User: 수정 완료 메시지

    else 설문조사 없음
        Backend-->>Frontend: 404 Not Found
        Frontend-->>User: 에러 메시지 표시
    end
```

---

## 4. 관리자 - 설문조사 목록 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자<br/>(ADMIN)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>Frontend: 관리자 > 설문조사 관리 클릭
    Frontend->>Backend: GET /api/v1/admin/members/surveys<br/>?page=0&size=20
    Note over Backend: JWT에서 Role 확인

    alt ADMIN Role
        Backend->>DB: 전체 설문조사 페이징 조회
        DB-->>Backend: 설문조사 목록 반환
        Backend-->>Frontend: 200 OK + 페이징 설문 목록
        Frontend-->>Admin: 설문조사 목록 테이블 표시

    else ADMIN Role 아님
        Backend-->>Frontend: 403 Forbidden
        Frontend-->>Admin: 권한 없음 메시지
    end
```

---

## 5. 관리자 - 특정 사용자 설문조사 조회

```mermaid
sequenceDiagram
    autonumber
    participant Admin as 관리자<br/>(ADMIN)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    Admin->>Frontend: 목록에서 특정 사용자 클릭
    Frontend->>Backend: GET /api/v1/admin/members/{userId}/survey
    Note over Backend: JWT에서 Role 확인

    alt ADMIN Role
        Backend->>DB: 해당 사용자 설문조사 조회
        DB-->>Backend: 조회 결과 반환

        alt 설문조사 존재
            Backend-->>Frontend: 200 OK + 설문 데이터
            Frontend-->>Admin: 설문 상세 정보 표시

        else 설문조사 없음
            Backend-->>Frontend: 404 Not Found
            Frontend-->>Admin: "설문조사 없음" 메시지
        end

    else ADMIN Role 아님
        Backend-->>Frontend: 403 Forbidden
        Frontend-->>Admin: 권한 없음 메시지
    end
```

---

## 6. LLM 추천 연동 (참고)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자<br/>(USER)
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant AI as AI 서버<br/>(Gemini)

    User->>Frontend: 강의 추천 요청
    Frontend->>Backend: GET /api/v1/members/me/survey
    Backend-->>Frontend: 설문 데이터 반환

    alt 설문조사 존재
        Frontend->>AI: 설문 데이터 + 추천 프롬프트
        AI-->>Frontend: 추천 결과 반환
        Frontend-->>User: 맞춤 강의 추천 표시

    else 설문조사 없음
        Frontend-->>User: "설문조사를 먼저 작성해주세요"
    end
```

---

## 관련 문서

- [설문조사 시퀀스 설명](./survey_description.md)
- [Tech Spec](../../features/survey/tech-spec.md)
- [PRD](../../features/survey/prd.md)
