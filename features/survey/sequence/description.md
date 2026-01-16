# 설문조사 (Survey) - Sequence Description

## 1. 사용자 설문 흐름

### 1.1 기초 설문 작성 (Step 1)

**참여자**
- User: 일반 사용자
- Client: 프론트엔드 (Next.js)
- Server: 백엔드 (Spring Boot)
- DB: PostgreSQL

**흐름**
1. 사용자가 마이페이지 > 설문조사 탭 클릭
2. Client가 활성 기초 설문 문항 조회 요청 (`GET /api/v1/survey/questions?type=BASIC`)
3. Server가 PUBLISHED 상태인 기초 설문 세트 반환
4. 사용자가 5문항에 응답 후 "저장" 클릭
5. Client가 기초 설문 응답 제출 (`POST /api/v1/members/me/survey/basic`)
6. Server가 응답을 `member_surveys.basic_survey` (JSONB)에 저장
7. 저장 성공 시 Step 2로 이동 또는 완료

**조건 분기**
- 기존 응답이 있는 경우: 기존 데이터 덮어쓰기 (Upsert)
- 프로그래밍 경험 "있음" 선택 시: 부트캠프 과정명 입력 필드 표시
- 희망 직무 "기타" 선택 시: 직접 입력 필드 표시

---

### 1.2 성향 테스트 응시 (Step 2)

**흐름**
1. 사용자가 Step 2 (성향 테스트) 진입 또는 "건너뛰기" 선택
2. "건너뛰기" 선택 시: 결과 화면으로 이동 (기본 추천만 가능 안내)
3. 진행 선택 시: Client가 성향 테스트 문항 조회 (`GET /api/v1/survey/questions?type=APTITUDE`)
4. Server가 PUBLISHED 상태인 성향 테스트 세트 반환 (15문항)
5. 사용자가 Part 1 → Part 2 → Part 3 순서로 응답
   - 각 Part 응답은 localStorage에 임시 저장 (중간 이탈 대비)
   - 새로고침/재진입 시 localStorage에서 복구
6. 전체 응답 완료 후 "제출" 클릭
7. Client가 성향 테스트 응답 제출 (`POST /api/v1/members/me/survey/aptitude-test`)
8. Server가 점수 계산 수행:
   - Part 1: 정답 여부로 점수 계산 (문항당 10점)
   - Part 2: 선택에 따라 점수 부여 (0/5/10점)
   - Part 3: F/B/D 카운트
9. Server가 결과 저장:
   - `member_surveys.aptitude_test` (JSONB): 응답 데이터
   - `member_surveys.results` (JSONB): 계산된 결과
   - `member_surveys.aptitude_score`, `aptitude_grade`, `recommended_job`: 인덱싱용 컬럼
   - `member_surveys.completed_at`: 완료 시각
10. 결과 화면으로 이동

---

### 1.3 결과 확인 (Step 3)

**흐름**
1. Client가 전체 설문 결과 조회 (`GET /api/v1/members/me/survey`)
2. Server가 응답:
   - `basicSurvey`: 기초 설문 응답
   - `aptitudeTest`: 성향 테스트 응답 (없으면 null)
   - `results`: 계산된 결과 (없으면 null)
   - `status`: 완료 상태 플래그
3. Client가 결과 화면 렌더링:
   - 추천 직무 표시 (적성 점수/등급은 사용자에게 노출하지 않음)
   - AI 추천 기능 사용 가능 여부 안내

---

## 2. 어드민 문항 관리 흐름

### 2.1 문항 세트 생성 및 문항 추가

**참여자**
- Admin: 관리자
- Client: 어드민 페이지
- Server: 백엔드
- DB: PostgreSQL

**흐름**
1. 관리자가 어드민 > 설문 관리 페이지 진입
2. "새 설문 세트 만들기" 클릭
3. 세트 정보 입력 (이름, 설명, 타입: BASIC/APTITUDE)
4. Client가 세트 생성 요청 (`POST /api/v1/admin/survey/question-sets`)
5. Server가 DRAFT 상태로 세트 생성
6. 관리자가 "문항 추가" 클릭
7. 문항 정보 입력:
   - 문항 텍스트
   - 타입 (TEXT/RADIO/CHECKBOX/RANGE/CONDITIONAL)
   - 필수 여부
   - Part (PART1/PART2/PART3 - 성향 테스트용)
8. 선택지 추가 (RADIO/CHECKBOX 타입):
   - 선택지 텍스트
   - 점수 (Part 2용)
   - 직무 유형 (Part 3용: F/B/D)
   - 정답 여부 (Part 1용)
9. Client가 문항 생성 요청 (`POST /api/v1/admin/survey/question-sets/{id}/questions`)
10. 반복하여 모든 문항 추가

---

### 2.2 문항 세트 발행

**흐름**
1. 관리자가 문항 작성 완료 후 "미리보기" 클릭
2. 미리보기에서 문항 확인
3. 관리자가 "발행" 클릭
4. Client가 발행 요청 (`POST /api/v1/admin/survey/question-sets/{id}/publish`)
5. Server 처리:
   - 기존 PUBLISHED 세트 → ARCHIVED로 상태 변경
   - 현재 세트 → PUBLISHED로 상태 변경
   - `published_at` 시각 기록
6. 발행 완료 알림

**제약**
- DRAFT 상태에서만 발행 가능
- 발행된 세트는 수정 불가 (새 버전 생성 필요)

---

### 2.3 새 버전 생성

**흐름**
1. 관리자가 기존 세트 선택
2. "새 버전으로 복제" 클릭
3. Client가 복제 요청 (`POST /api/v1/admin/survey/question-sets/{id}/clone`)
4. Server 처리:
   - 기존 세트의 모든 문항/선택지 복사
   - 버전 번호 증가
   - DRAFT 상태로 생성
5. 복제된 세트에서 수정 작업 진행
6. 수정 완료 후 발행

---

## 3. AI 추천 연동 흐름

### 3.1 기본 추천 (기초 설문만 완료)

**흐름**
1. 사용자가 AI 추천 요청
2. Server가 `member_surveys` 조회
3. `basic_survey IS NOT NULL` 확인
4. 기초 설문 데이터 기반 추천:
   - 희망 직무
   - 선호 수업 방식
   - 예산 범위
5. 기본 추천 결과 반환

### 3.2 정밀 추천 (성향 테스트까지 완료)

**흐름**
1. 사용자가 AI 추천 요청
2. Server가 `member_surveys` 조회
3. `aptitude_test IS NOT NULL` 확인
4. 기초 설문 + 성향 테스트 결과 기반 추천:
   - 희망 직무 + 추천 직무 교차 분석
   - 적성 등급에 따른 난이도 조절
   - 선호 수업 방식
   - 예산 범위
5. 정밀 추천 결과 반환

---

## 4. 점수 계산 로직

### 4.1 Part 1 점수 계산

```
for each question in Part1:
    if user_answer == correct_answer:
        score += 10
    else:
        score += 0
```

### 4.2 Part 2 점수 계산

```
for each question in Part2:
    selected_option = get_selected_option(user_answer)
    score += selected_option.score  // 0, 5, or 10
```

### 4.3 Part 3 직무 유형 계산

```
counts = { F: 0, B: 0, D: 0 }
for each question in Part3:
    selected_option = get_selected_option(user_answer)
    counts[selected_option.job_type] += 1

max_count = max(counts.values())
if count_of_max > 1:
    recommended_job = FULLSTACK
else:
    recommended_job = key_with_max_count
```

### 4.4 등급 결정

```
total_score = part1_score + part2_score  // 0-80

if total_score >= 61: grade = TALENTED
else if total_score >= 41: grade = DILIGENT
else if total_score >= 21: grade = EXPLORING
else: grade = RECONSIDER
```
