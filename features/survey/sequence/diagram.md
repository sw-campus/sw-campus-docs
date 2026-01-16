# 설문조사 (Survey) - Sequence Diagram

## 1. 사용자 설문 흐름

### 1.1 기초 설문 작성 (Step 1)

```mermaid
sequenceDiagram
    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as PostgreSQL

    User->>Client: 마이페이지 > 설문조사 탭 클릭
    Client->>Server: GET /api/v1/survey/questions?type=BASIC
    Server->>DB: SELECT * FROM survey_question_sets<br/>WHERE type='BASIC' AND status='PUBLISHED'
    DB-->>Server: 기초 설문 세트 + 문항
    Server-->>Client: QuestionSetResponse (5문항)
    Client->>User: 기초 설문 폼 표시

    User->>Client: 5문항 응답 후 "저장" 클릭
    Client->>Server: POST /api/v1/members/me/survey/basic<br/>{major, programmingExperience, ...}
    Server->>DB: UPSERT member_surveys<br/>SET basic_survey = $jsonb
    DB-->>Server: OK
    Server-->>Client: 200 OK
    Client->>User: Step 2로 이동 또는 완료
```

### 1.2 성향 테스트 응시 (Step 2)

```mermaid
sequenceDiagram
    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as PostgreSQL

    User->>Client: Step 2 진입

    alt 건너뛰기 선택
        User->>Client: "건너뛰기" 클릭
        Client->>User: 결과 화면 (기본 추천만 가능 안내)
    else 진행 선택
        Client->>Server: GET /api/v1/survey/questions?type=APTITUDE
        Server->>DB: SELECT * FROM survey_question_sets<br/>WHERE type='APTITUDE' AND status='PUBLISHED'
        DB-->>Server: 성향 테스트 세트 + 문항 (15개)
        Server-->>Client: QuestionSetResponse (Part1/2/3)
        Client->>User: Part 1 표시 (4문항)

        User->>Client: Part 1 응답
        Client->>Client: localStorage에 Part 1 임시 저장
        Client->>User: Part 2 표시 (4문항)

        User->>Client: Part 2 응답
        Client->>Client: localStorage에 Part 2 임시 저장
        Client->>User: Part 3 표시 (7문항)

        User->>Client: Part 3 응답 후 "제출" 클릭
        Client->>Client: localStorage 임시 데이터 삭제
        Client->>Server: POST /api/v1/members/me/survey/aptitude-test<br/>{part1Answers, part2Answers, part3Answers}

        Server->>Server: 점수 계산<br/>Part1: 정답 체크 (10점/문항)<br/>Part2: 선택 점수 (0/5/10점)<br/>Part3: F/B/D 카운트

        Server->>DB: UPDATE member_surveys<br/>SET aptitude_test = $jsonb,<br/>    results = $jsonb,<br/>    aptitude_score = $score,<br/>    aptitude_grade = $grade,<br/>    recommended_job = $job,<br/>    completed_at = NOW()
        DB-->>Server: OK
        Server-->>Client: SurveyResultsResponse
        Client->>User: 결과 화면 표시
    end
```

### 1.3 결과 확인 (Step 3)

```mermaid
sequenceDiagram
    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant DB as PostgreSQL

    User->>Client: 결과 화면 진입
    Client->>Server: GET /api/v1/members/me/survey
    Server->>DB: SELECT * FROM member_surveys<br/>WHERE member_id = $memberId
    DB-->>Server: member_surveys row

    Server-->>Client: SurveyResponse<br/>{basicSurvey, aptitudeTest, results, status}

    alt 성향 테스트 완료
        Client->>User: 추천 직무 표시<br/>"AI 정밀 추천 가능" 안내
        Note over Client: 적성 점수/등급은<br/>사용자에게 노출하지 않음
    else 기초 설문만 완료
        Client->>User: 기초 설문 결과 표시<br/>"AI 기본 추천 가능" 안내<br/>"성향 테스트 진행" 유도
    end
```

---

## 2. 어드민 문항 관리 흐름

### 2.1 문항 세트 생성 및 문항 추가

```mermaid
sequenceDiagram
    actor Admin as 관리자
    participant Client as Admin Page
    participant Server as Server<br/>(Spring Boot)
    participant DB as PostgreSQL

    Admin->>Client: 어드민 > 설문 관리 진입
    Admin->>Client: "새 설문 세트 만들기" 클릭

    Client->>Admin: 세트 정보 입력 폼
    Admin->>Client: 이름, 설명, 타입(BASIC/APTITUDE) 입력
    Client->>Server: POST /api/v1/admin/survey/question-sets<br/>{name, description, type}
    Server->>DB: INSERT INTO survey_question_sets<br/>(..., status='DRAFT')
    DB-->>Server: question_set_id
    Server-->>Client: QuestionSetResponse

    loop 문항 추가
        Admin->>Client: "문항 추가" 클릭
        Client->>Admin: 문항 입력 폼
        Admin->>Client: 문항 정보 입력<br/>(텍스트, 타입, 필수여부, Part)

        alt RADIO/CHECKBOX 타입
            loop 선택지 추가
                Admin->>Client: 선택지 입력<br/>(텍스트, 점수, 정답여부, 직무유형)
            end
        end

        Client->>Server: POST /api/v1/admin/survey/question-sets/{id}/questions<br/>{questionText, questionType, options[]}
        Server->>DB: INSERT INTO survey_questions<br/>INSERT INTO survey_options
        DB-->>Server: question_id
        Server-->>Client: QuestionResponse
    end
```

### 2.2 문항 세트 발행

```mermaid
sequenceDiagram
    actor Admin as 관리자
    participant Client as Admin Page
    participant Server as Server<br/>(Spring Boot)
    participant DB as PostgreSQL

    Admin->>Client: "미리보기" 클릭
    Client->>Server: GET /api/v1/admin/survey/question-sets/{id}
    Server-->>Client: QuestionSetDetailResponse
    Client->>Admin: 미리보기 화면

    Admin->>Client: "발행" 클릭
    Client->>Server: POST /api/v1/admin/survey/question-sets/{id}/publish

    Server->>DB: BEGIN TRANSACTION
    Server->>DB: UPDATE survey_question_sets<br/>SET status='ARCHIVED'<br/>WHERE type=$type AND status='PUBLISHED'
    Server->>DB: UPDATE survey_question_sets<br/>SET status='PUBLISHED',<br/>    published_at=NOW()<br/>WHERE question_set_id=$id
    Server->>DB: COMMIT

    DB-->>Server: OK
    Server-->>Client: 200 OK
    Client->>Admin: "발행 완료" 알림
```

### 2.3 새 버전 생성

```mermaid
sequenceDiagram
    actor Admin as 관리자
    participant Client as Admin Page
    participant Server as Server<br/>(Spring Boot)
    participant DB as PostgreSQL

    Admin->>Client: 기존 세트 선택
    Admin->>Client: "새 버전으로 복제" 클릭
    Client->>Server: POST /api/v1/admin/survey/question-sets/{id}/clone

    Server->>DB: SELECT * FROM survey_question_sets<br/>WHERE question_set_id = $id
    DB-->>Server: 기존 세트 정보

    Server->>DB: INSERT INTO survey_question_sets<br/>(..., version = version + 1, status = 'DRAFT')
    DB-->>Server: new_question_set_id

    Server->>DB: SELECT * FROM survey_questions<br/>WHERE question_set_id = $id
    DB-->>Server: 기존 문항들

    loop 문항 복사
        Server->>DB: INSERT INTO survey_questions<br/>(question_set_id = $new_id, ...)
        Server->>DB: INSERT INTO survey_options<br/>(복사된 선택지들)
    end

    Server-->>Client: QuestionSetResponse (새 버전)
    Client->>Admin: 복제된 세트 편집 화면
```

---

## 3. AI 추천 연동 흐름

### 3.1 기본 추천 (기초 설문만 완료)

```mermaid
sequenceDiagram
    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant AI as AI Service
    participant DB as PostgreSQL

    User->>Client: AI 추천 요청
    Client->>Server: GET /api/v1/recommendations

    Server->>DB: SELECT * FROM member_surveys<br/>WHERE member_id = $memberId
    DB-->>Server: member_surveys row

    alt basic_survey IS NULL
        Server-->>Client: 400 설문 작성 필요
        Client->>User: "기초 설문을 먼저 작성해주세요"
    else basic_survey IS NOT NULL AND aptitude_test IS NULL
        Server->>AI: 기본 추천 요청<br/>{desiredJobs, preferredLearningMethod, budget}
        AI-->>Server: 기본 추천 결과
        Server-->>Client: BasicRecommendationResponse
        Client->>User: 기본 추천 결과 표시<br/>"성향 테스트 완료 시 정밀 추천 가능" 안내
    end
```

### 3.2 정밀 추천 (성향 테스트까지 완료)

```mermaid
sequenceDiagram
    actor User as 사용자
    participant Client as Client<br/>(Next.js)
    participant Server as Server<br/>(Spring Boot)
    participant AI as AI Service
    participant DB as PostgreSQL

    User->>Client: AI 추천 요청
    Client->>Server: GET /api/v1/recommendations

    Server->>DB: SELECT * FROM member_surveys<br/>WHERE member_id = $memberId
    DB-->>Server: member_surveys row<br/>(aptitude_test IS NOT NULL)

    Server->>AI: 정밀 추천 요청<br/>{desiredJobs, preferredLearningMethod, budget,<br/> aptitudeGrade, recommendedJob}

    Note over AI: 희망 직무 + 추천 직무 교차 분석<br/>적성 등급에 따른 난이도 조절

    AI-->>Server: 정밀 추천 결과
    Server-->>Client: PreciseRecommendationResponse
    Client->>User: 정밀 추천 결과 표시
```

---

## 4. 점수 계산 흐름

### 4.1 성향 테스트 점수 계산 (서버 내부)

```mermaid
sequenceDiagram
    participant Controller as SurveyController
    participant Service as MemberSurveyService
    participant Calculator as SurveyResultCalculator
    participant DB as PostgreSQL

    Controller->>Service: submitAptitudeTest(request)
    Service->>DB: SELECT * FROM survey_question_sets<br/>WHERE type='APTITUDE' AND status='PUBLISHED'
    DB-->>Service: QuestionSet (정답 포함)

    Service->>Calculator: calculate(answers, questionSet)

    Note over Calculator: Part 1 계산
    loop Part 1 문항 (4개)
        Calculator->>Calculator: if answer == correctAnswer<br/>  score += 10
    end

    Note over Calculator: Part 2 계산
    loop Part 2 문항 (4개)
        Calculator->>Calculator: score += selectedOption.score<br/>(0, 5, or 10)
    end

    Note over Calculator: Part 3 계산
    loop Part 3 문항 (7개)
        Calculator->>Calculator: jobCounts[option.jobType]++
    end

    Calculator->>Calculator: totalScore = part1Score + part2Score
    Calculator->>Calculator: grade = determineGrade(totalScore)
    Calculator->>Calculator: recommendedJob = determineJob(jobCounts)

    Calculator-->>Service: SurveyResults<br/>{aptitudeScore, aptitudeGrade,<br/> jobTypeScores, recommendedJob}

    Service->>DB: UPDATE member_surveys<br/>SET results = $jsonb, ...
    Service-->>Controller: SurveyResultsResponse
```

### 4.2 추천 직무 결정 (사용자에게 표시)

```mermaid
flowchart TD
    subgraph 추천 직무 결정
        G[Part3 응답 집계<br/>F/B/D 카운트] --> H{최다 유형}
        H -->|F 최다| I[FRONTEND<br/>프론트엔드]
        H -->|B 최다| J[BACKEND<br/>백엔드]
        H -->|D 최다| K[DATA<br/>데이터/AI]
        H -->|동점| L[FULLSTACK<br/>풀스택]
    end
```

### 4.3 적성 점수 계산 (내부 활용 - AI 추천용)

```mermaid
flowchart TD
    subgraph 내부 점수 계산
        A[totalScore 계산<br/>Part1 + Part2] --> B[0-80점]
        B --> C[AI 강의 추천 시<br/>난이도 조절에 활용]
    end

    style A fill:#f9f9f9,stroke:#999
    style B fill:#f9f9f9,stroke:#999
    style C fill:#f9f9f9,stroke:#999
```

> **Note**: 적성 점수/등급은 사용자에게 노출하지 않습니다. AI 강의 추천 시 난이도 조절에만 내부적으로 활용됩니다.
