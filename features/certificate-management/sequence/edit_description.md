# 수료증 이미지 수정 - 시퀀스 설명

## 개요

PENDING 또는 REJECTED 상태의 수료증 이미지를 새로운 이미지로 교체하는 흐름입니다.

## 참여자 (Actors)

| Actor | 설명 |
|-------|------|
| User | 일반 사용자 |
| Client | 프론트엔드 (Next.js) |
| Server | 백엔드 API 서버 (Spring Boot) |
| DB | PostgreSQL 데이터베이스 |
| S3 | AWS S3 파일 스토리지 |

## 흐름 설명

### 1. 수정 버튼 활성화 확인
- PENDING/REJECTED 상태에서만 수정 버튼 표시
- APPROVED 상태는 수정 버튼 숨김

### 2. 이미지 선택
- 사용자가 수정 버튼 클릭
- 파일 선택 다이얼로그 표시
- 이미지 미리보기 제공

### 3. 이미지 업로드
- 서버로 새 이미지 전송 (Multipart)
- 소유권 검증 수행
- 상태 검증 수행 (PENDING/REJECTED만 허용)

### 4. 기존 이미지 삭제 및 새 이미지 저장
- S3에서 기존 이미지 삭제
- S3에 새 이미지 업로드
- DB에 새 이미지 URL 저장
- 수료증 상태를 PENDING으로 초기화

### 5. 결과 표시
- 업로드 성공 메시지 표시
- 목록 새로고침하여 변경 반영

## 예외 처리

| 조건 | 처리 |
|------|------|
| 인증되지 않은 사용자 | 401 Unauthorized |
| 본인 수료증이 아닌 경우 | 403 Forbidden |
| APPROVED 상태 수정 시도 | 403 Forbidden |
| 수료증을 찾을 수 없음 | 404 Not Found |
| 파일 형식 오류 | 400 Bad Request |
| S3 업로드 실패 | 500 Internal Server Error |

## 관련 API

| Method | Endpoint | 설명 |
|--------|----------|------|
| PATCH | /api/v1/certificates/{certificateId}/image | 수료증 이미지 수정 (Multipart) |
