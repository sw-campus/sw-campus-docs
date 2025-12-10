# 강의 후기 Sequence Diagrams

## 0. 닉네임 확인 (후기 작성 진입 시)

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 후기 작성 버튼 클릭
    
    Note over Frontend: JWT 토큰에서<br/>hasNickname 플래그 확인

    alt 닉네임 미설정 (hasNickname: false)
        Frontend->>User: 닉네임 설정 필요 안내<br/>(회원 상세 페이지로 이동 유도)
        User->>Frontend: 회원 상세 페이지로 이동
        User->>Frontend: 닉네임 입력
        Frontend->>Backend: PATCH /api/members/me/nickname<br/>{nickname: "새닉네임"}
        Backend->>DB: 닉네임 업데이트
        DB-->>Backend: 업데이트 완료
        Backend-->>Frontend: 200 OK<br/>+ 새 토큰 발급 (hasNickname: true)
        
        Note over Frontend: 새 토큰 저장
        
        Frontend-->>User: 닉네임 설정 완료<br/>후기 작성 페이지로 이동
    else 닉네임 이미 설정됨 (hasNickname: true)
        Note over Frontend: 수료증 인증 흐름으로 진행
    end
```

---

## 1. 수료증 인증

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(넷스트)
    participant Backend as 백엔드<br/>(Spring)
    participant S3 as S3
    participant OCR as OCR 서버
    participant DB as Database

    User->>Frontend: 후기 작성 버튼 클릭
    Frontend->>Backend: GET /api/certificates/check<br/>?lectureId={id}
    Backend->>DB: 수료증 인증 조회<br/>(userId + lectureId)
    DB-->>Backend: 인증 여부 반환

    alt 수료증 미인증
        Backend-->>Frontend: 미인증 응답
        Frontend->>User: 수료증 인증 모달 표시
        User->>Frontend: 수료증 이미지 업로드
        Frontend->>Backend: POST /api/certificates/verify<br/>(이미지 포함)
        Backend->>S3: 수료증 이미지 업로드
        S3-->>Backend: 이미지 URL 반환
        Backend->>OCR: 이미지 OCR 분석 요청
        OCR-->>Backend: OCR 결과 반환 (강의명 등)
        
        Note over Backend: 강의명 매칭 검증

        alt 인증 성공
            Backend->>DB: 수료증 인증 정보 저장<br/>(certified: true, imageUrl)
            DB-->>Backend: 저장 완료
            Backend-->>Frontend: 인증 성공 응답
            Frontend-->>User: 후기 작성 폼 표시
        else 인증 실패 (OCR 실패 / 강의명 불일치)
            Backend->>S3: 업로드된 이미지 삭제
            Backend-->>Frontend: 400 Bad Request
            Frontend-->>User: 에러 메시지 표시<br/>("해당 강의의 수료증이 아닙니다")
        end

    else 수료증 이미 인증됨
        Backend-->>Frontend: 인증 완료 응답
        Frontend-->>User: 후기 작성 폼 표시
    end
```

---

## 2. 후기 작성

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 후기 작성 버튼 클릭
    Frontend->>Backend: GET /api/reviews/check<br/>?lectureId={id}
    Backend->>DB: 기존 후기 존재 여부 조회<br/>(userId + lectureId)
    DB-->>Backend: 조회 결과 반환

    alt 이미 후기 작성됨
        Backend-->>Frontend: 409 Conflict
        Frontend-->>User: 알럿 표시<br/>("이미 작성한 후기입니다")
    else 후기 작성 가능
        Backend-->>Frontend: 작성 가능 응답
        Frontend-->>User: 후기 작성 폼 표시
        User->>Frontend: 후기 내용 입력 및 제출<br/>(별점, 후기 콘텐츠, nickname)
        Frontend->>Backend: POST /api/reviews
        Backend->>DB: 후기 저장
        DB-->>Backend: 저장 완료
        Backend-->>Frontend: 201 Created
        Frontend-->>User: 성공 메시지 표시<br/>강의 상세 페이지로 이동
    end
```

---

## 3. 후기 수정

**접근 경로:**
- 강의 상세 페이지 → 본인 후기의 "수정" 버튼
- 마이페이지 → "내가 작성한 후기" → "수정" 버튼

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드<br/>(Next.js)
    participant Backend as 백엔드<br/>(Spring)
    participant DB as Database

    User->>Frontend: 후기 수정 버튼 클릭
    Frontend->>Backend: GET /api/reviews/{reviewId}
    Backend->>DB: 후기 조회
    DB-->>Backend: 후기 데이터 반환
    Backend-->>Frontend: 200 OK (후기 데이터)
    Frontend-->>User: 후기 수정 폼 표시<br/>(기존 데이터 채워짐)
    
    User->>Frontend: 수정된 내용 제출<br/>(별점, 후기 콘텐츠)
    Frontend->>Backend: PUT /api/reviews/{reviewId}
    Backend->>DB: 후기 업데이트
    DB-->>Backend: 업데이트 완료
    Backend-->>Frontend: 200 OK
    Frontend-->>User: 성공 메시지 표시
```

---

## 4. 사용자 후기 삭제

> **Note**: 사용자는 후기를 삭제할 수 없습니다. 수정만 가능합니다.
> 데이터 삭제는 관리자의 블라인드(BLURRED) 처리로 대체됩니다.

---

## 5. 전체 후기 흐름 요약

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Frontend as 프론트엔드
    participant Backend as 백엔드
    participant S3 as S3
    participant OCR as OCR 서버
    participant DB as Database

    rect rgb(240, 240, 200)
        Note over User, DB: 0. 닉네임 확인
        User->>Frontend: 후기 작성 버튼 클릭
        Note over Frontend: JWT hasNickname 확인
        alt hasNickname: false
            Frontend->>User: 닉네임 설정 페이지로 이동
            User->>Frontend: 닉네임 입력
            Frontend->>Backend: PATCH /api/members/me/nickname
            Backend->>DB: 닉네임 업데이트
            Backend-->>Frontend: 200 OK + 새 토큰 발급
        end
    end

    rect rgb(255, 230, 200)
        Note over User, DB: 1. 수료증 인증
        Frontend->>Backend: 수료증 인증 확인
        Backend->>DB: 인증 여부 조회
        DB-->>Backend: 미인증
        Frontend->>User: 인증 모달 표시
        User->>Frontend: 수료증 이미지 업로드
        Frontend->>Backend: 인증 요청
        Backend->>S3: 이미지 업로드
        S3-->>Backend: 이미지 URL 반환
        Backend->>OCR: OCR 분석
        OCR-->>Backend: 강의명 반환
        Backend->>DB: 인증 정보 저장<br/>(certified, imageUrl)
        Backend-->>Frontend: 인증 성공
    end

    rect rgb(200, 230, 200)
        Note over User, DB: 2. 후기 작성
        Frontend-->>User: 후기 작성 폼 표시
        User->>Frontend: 후기 내용 제출<br/>(전체별점, 상세별점 5개, 내용)
        Frontend->>Backend: POST /api/reviews
        Backend->>DB: 후기 저장 (PENDING)
        Backend-->>Frontend: 201 Created
        Frontend-->>User: 작성 완료
    end

    rect rgb(200, 220, 240)
        Note over User, DB: 3. 후기 수정
        User->>Frontend: 수정 버튼 클릭
        Frontend->>Backend: 후기 조회
        Backend->>DB: 후기 데이터
        Backend-->>Frontend: 후기 반환
        User->>Frontend: 수정 내용 제출
        Frontend->>Backend: PUT /api/reviews/{id}
        Backend->>DB: 업데이트
        Backend-->>Frontend: 200 OK
    end

    Note over User, DB: ※ 사용자는 후기를 삭제할 수 없습니다.<br/>삭제는 관리자 블라인드 처리로 대체됩니다.
```
