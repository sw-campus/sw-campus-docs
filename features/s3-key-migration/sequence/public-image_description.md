# Public 이미지 조회 - 시퀀스 설명

## 개요

강의 썸네일, 배너, 기관 로고 등 공개 이미지를 조회하는 흐름입니다.
인증 없이 누구나 Presigned GET URL을 발급받아 이미지에 접근할 수 있습니다.

> **관련 사용자 스토리**: US-1 (Public 이미지 조회)

## 참여자 (Actors)

| Actor | 설명 |
|-------|------|
| User | 웹사이트 방문자 (비로그인 포함) |
| Client | Next.js 프론트엔드 |
| Server | Spring Boot API 서버 |
| S3 | AWS S3 스토리지 |

## 흐름 설명

### 1. 강의 상세 정보 요청
- 사용자가 강의 상세 페이지에 접속
- Client가 강의 API 호출
- Server가 DB에서 강의 정보 조회 (lectureImageKey 포함)
- Response에 S3 key 반환 (full URL 아님)

### 2. S3Image 컴포넌트 렌더링
- Client가 `lectureImageKey`를 `S3Image` 컴포넌트에 전달
- `usePresignedUrl` hook이 React Query로 캐시 확인

### 3. Presigned URL 발급 (캐시 미스 시)
- Client가 Storage API 호출: `GET /api/v1/storage/presigned/url?key={key}`
- Server가 Public key 확인 후 S3Presigner로 Presigned GET URL 생성 (만료: 15분)
- Client가 URL을 React Query 캐시에 저장 (staleTime: 5분)

### 4. 이미지 로드
- Client가 Presigned URL로 S3에 직접 이미지 요청
- S3가 서명 검증 후 이미지 반환
- `next/image`가 이미지 렌더링

## 예외 처리

| 조건 | 처리 |
|------|------|
| key가 null/undefined | S3Image가 fallback 컴포넌트 렌더링 |
| key가 존재하지 않음 | Server가 404 반환, S3Image가 fallback 표시 |
| Presigned URL 만료 | React Query가 staleTime 이후 자동 refetch |
| S3 접근 오류 | 이미지 로드 실패, 브라우저 기본 처리 |

## 관련 API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| GET | /api/v1/storage/presigned/url | 단일 Presigned URL 발급 | X |
| GET | /api/v1/lectures/{id} | 강의 상세 조회 (imageKey 포함) | X |

## 캐싱 전략

| 레벨 | 대상 | TTL |
|------|------|-----|
| React Query | Presigned URL | staleTime: 5분, gcTime: 10분 |
| Presigned URL | S3 객체 접근 | 만료: 15분 |
| Browser | 이미지 자체 | Cache-Control 헤더 따름 |
