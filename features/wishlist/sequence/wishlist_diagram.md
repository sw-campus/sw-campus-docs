# LECTURE 스크랩 (찜) Sequence Diagrams

## 1. 스크랩 추가/삭제 (토글)

**접근 경로:**
- 강의 목록 페이지 → 스크랩 버튼 (하트 아이콘)
- 강의 상세 페이지 → 스크랩 버튼 (하트 아이콘)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant Redis as Redis
    participant DB as Database

    User->>Frontend: 스크랩 버튼 클릭 (토글)
    Frontend->>Backend: POST /api/wishlists/toggle<br/>?lectureId={id}
    Backend->>DB: 기존 스크랩 여부 조회<br/>(userId + lectureId)
    DB-->>Backend: 조회 결과 반환

    alt 스크랩 되어있지 않음 (추가)
        Backend->>DB: 현재 스크랩 개수 조회
        DB-->>Backend: 스크랩 개수 반환

        alt 스크랩 개수 < 10
            Backend->>DB: 스크랩 추가<br/>(wishlist INSERT)
            DB-->>Backend: 저장 완료
            Backend->>Redis: 캐시 삭제<br/>(wishlist:{userId})
            Backend-->>Frontend: 201 Created<br/>(스크랩 추가 성공)
            Frontend-->>User: 하트 아이콘 활성화<br/>(채워진 하트)
        else 스크랩 개수 >= 10
            Backend-->>Frontend: 400 Bad Request<br/>(스크랩 개수 초과)
            Frontend-->>User: 알럿 표시<br/>("스크랩은 최대 10개까지 가능합니다")
        end

    else 이미 스크랩됨 (삭제)
        Backend->>DB: 스크랩 삭제<br/>(wishlist DELETE)
        DB-->>Backend: 삭제 완료
        Backend->>Redis: 캐시 삭제<br/>(wishlist:{userId})
        Backend-->>Frontend: 200 OK<br/>(스크랩 삭제 성공)
        Frontend-->>User: 하트 아이콘 비활성화<br/>(빈 하트)
    end
```

---

## 2. 스크랩 목록 조회 (메인페이지)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant Redis as Redis
    participant DB as Database

    User->>Frontend: 메인페이지 접속
    Frontend->>Backend: GET /api/wishlists
    Backend->>Redis: 캐시 조회<br/>(wishlist:{userId})

    alt 캐시 Hit
        Redis-->>Backend: 캐시된 스크랩 목록 반환
        Backend-->>Frontend: 200 OK<br/>(스크랩 목록 데이터)
    else 캐시 Miss
        Redis-->>Backend: 캐시 없음
        Backend->>DB: 스크랩 목록 조회<br/>(userId, 스크랩 순서 정렬)
        DB-->>Backend: 스크랩 목록 반환<br/>(최대 10개)
        Backend->>Redis: 캐시 저장<br/>(wishlist:{userId}, TTL: 10분)
        Backend-->>Frontend: 200 OK<br/>(스크랩 목록 데이터)
    end

    Frontend-->>User: 스크랩 목록<br/>슬라이드로 표시
```

---

## 3. 스크랩 목록 조회 (마이페이지)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant Redis as Redis
    participant DB as Database

    User->>Frontend: 마이페이지 →<br/>"찜한 강의" 메뉴 클릭
    Frontend->>Backend: GET /api/wishlists
    Backend->>Redis: 캐시 조회<br/>(wishlist:{userId})

    alt 캐시 Hit
        Redis-->>Backend: 캐시된 스크랩 목록 반환
        Backend-->>Frontend: 200 OK<br/>(스크랩 목록 데이터)
    else 캐시 Miss
        Redis-->>Backend: 캐시 없음
        Backend->>DB: 스크랩 목록 조회<br/>(userId, 스크랩 순서 정렬)
        DB-->>Backend: 스크랩 목록 반환<br/>(최대 10개)
        Backend->>Redis: 캐시 저장<br/>(wishlist:{userId}, TTL: 10분)
        Backend-->>Frontend: 200 OK<br/>(스크랩 목록 데이터)
    end

    Frontend-->>User: 스크랩 목록 전체 표시
```

---

## 4. 전체 스크랩 흐름 요약

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant Redis as Redis
    participant DB as Database

    rect rgb(255, 230, 200)
        Note over User, DB: 스크랩 추가
        User->>Frontend: 스크랩 버튼 클릭<br/>(빈 하트)
        Frontend->>Backend: POST /api/wishlists/toggle
        Backend->>DB: 스크랩 여부 확인
        Backend->>DB: 개수 확인 (< 10)
        Backend->>DB: 스크랩 추가
        Backend->>Redis: 캐시 삭제
        Backend-->>Frontend: 201 Created
        Frontend-->>User: 채워진 하트로 변경
    end

    rect rgb(230, 200, 200)
        Note over User, DB: 스크랩 삭제
        User->>Frontend: 스크랩 버튼 클릭<br/>(채워진 하트)
        Frontend->>Backend: POST /api/wishlists/toggle
        Backend->>DB: 스크랩 여부 확인
        Backend->>DB: 스크랩 삭제
        Backend->>Redis: 캐시 삭제
        Backend-->>Frontend: 200 OK
        Frontend-->>User: 빈 하트로 변경
    end

    rect rgb(200, 230, 200)
        Note over User, DB: 메인페이지 조회 (캐시 Hit)
        User->>Frontend: 메인페이지 접속
        Frontend->>Backend: GET /api/wishlists
        Backend->>Redis: 캐시 조회
        Redis-->>Backend: 캐시된 목록 반환
        Backend-->>Frontend: 스크랩 목록 (최대 10개)
        Frontend-->>User: 슬라이드로 표시
    end

    rect rgb(200, 220, 240)
        Note over User, DB: 마이페이지 조회 (캐시 Miss)
        User->>Frontend: 마이페이지 접속
        Frontend->>Backend: GET /api/wishlists
        Backend->>Redis: 캐시 조회
        Redis-->>Backend: 캐시 없음
        Backend->>DB: 스크랩 목록 조회
        Backend->>Redis: 캐시 저장 (TTL: 10분)
        Backend-->>Frontend: 스크랩 목록 (최대 10개)
        Frontend-->>User: 전체 목록 표시
    end
```
