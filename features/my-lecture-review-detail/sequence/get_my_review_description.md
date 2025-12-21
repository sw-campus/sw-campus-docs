# 내 강의 후기 상세 조회 - 시퀀스 설명

## 개요

수강 완료한 강의 목록에서 특정 강의를 선택하여 본인이 작성한 후기의 상세 정보를 조회하는 흐름입니다.

## 참여자 (Actors)

| Actor | 설명 |
|-------|------|
| Client | 프론트엔드 (웹/앱) |
| Server | 백엔드 API 서버 |
| DB | PostgreSQL 데이터베이스 |

## 흐름 설명

### 1. 수강 완료 강의 목록 조회
- 사용자가 마이페이지에서 수강 완료 강의 목록을 조회
- 기존 `/api/v1/mypage/completed-lectures` API 사용

### 2. 강의 선택 및 후기 상세 조회 요청
- 사용자가 특정 강의를 선택
- Client가 `GET /api/v1/reviews/my?lectureId={lectureId}` 요청

### 3. 인증 및 권한 검증
- Server가 JWT 토큰에서 memberId 추출
- 본인 확인 (memberId 기반)

### 4. 후기 데이터 조회
- Server가 DB에서 해당 memberId + lectureId로 후기 조회
- Review + ReviewDetail (카테고리별 점수) 함께 조회

### 5. 응답 반환
- 후기가 있으면 상세 정보 반환 (detailScores 포함)
- 후기가 없으면 404 Not Found 반환

## 예외 처리

| 조건 | 처리 |
|------|------|
| 미인증 사용자 | 401 Unauthorized |
| 후기 없음 | 404 Not Found |
| 잘못된 lectureId | 400 Bad Request |

## 관련 API

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | /api/v1/reviews/my | 특정 강의에 대한 내 후기 상세 조회 |
