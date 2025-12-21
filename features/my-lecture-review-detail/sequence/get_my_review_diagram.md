# 내 강의 후기 상세 조회 - 시퀀스 다이어그램

```mermaid
sequenceDiagram
    autonumber

    actor User as 사용자
    participant Client as Client
    participant Server as Server
    participant DB as DB

    %% 수강 완료 강의 목록에서 강의 선택
    Note over User,Client: 수강 완료 강의 목록에서 강의 선택

    User->>Client: 강의 선택 (후기 상세 보기)
    Client->>Server: GET /api/v1/reviews/my?lectureId={lectureId}
    activate Server

    Note over Server: JWT에서 memberId 추출

    Server->>DB: 후기 조회 (memberId, lectureId)
    activate DB
    DB-->>Server: Review + ReviewDetails
    deactivate DB

    alt 후기 존재
        Server-->>Client: 200 OK (후기 상세 + detailScores)
        deactivate Server
        Client-->>User: 후기 상세 정보 표시
    else 후기 없음
        Server-->>Client: 404 Not Found
        Client-->>User: 후기 없음 안내
    end
```

## 응답 예시

### 성공 (200 OK)

```json
{
  "review_id": 1,
  "lecture_id": 10,
  "nickname": "수강생A",
  "comment": "전체적으로 만족스러운 강의였습니다.",
  "average_score": 4.3,
  "approval_status": "APPROVED",
  "detail_scores": [
    { "category": "TEACHER", "score": 4.5, "comment": "강사님이 좋았습니다" },
    { "category": "CURRICULUM", "score": 4.0, "comment": "커리큘럼이 체계적입니다" },
    { "category": "MANAGEMENT", "score": 4.5, "comment": "행정 서비스가 좋았습니다" },
    { "category": "FACILITY", "score": 3.5, "comment": "시설은 보통입니다" },
    { "category": "PROJECT", "score": 5.0, "comment": "프로젝트가 유익했습니다" }
  ],
  "created_at": "2025-12-21T10:00:00",
  "updated_at": "2025-12-21T10:00:00"
}
```

### 실패 (404 Not Found)

```json
{
  "code": "REVIEW_NOT_FOUND",
  "message": "해당 강의에 대한 후기가 없습니다."
}
```
