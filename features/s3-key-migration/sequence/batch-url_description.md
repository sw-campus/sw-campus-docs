# 배치 Presigned URL 조회 - 시퀀스 설명

## 개요

여러 이미지의 Presigned URL을 한 번에 발급받는 흐름입니다.
강의 상세 페이지의 시설 이미지(4개), 강의 목록 페이지의 썸네일 등
여러 이미지를 효율적으로 로드할 때 사용합니다.

> **관련 기능 요구사항**: FR-2 (배치 Presigned URL API)

## 참여자 (Actors)

| Actor | 설명 |
|-------|------|
| User | 웹사이트 방문자 |
| Client | Next.js 프론트엔드 |
| Server | Spring Boot API 서버 |
| S3 | AWS S3 스토리지 |

## 흐름 설명

### 1. 강의 상세 정보 요청
- 사용자가 강의 상세 페이지 접속
- Server가 강의 정보 반환 (여러 imageKey 포함)
  - `lectureImageKey`: 썸네일
  - `orgFacilityKeys`: 시설 이미지 4개
  - `teachers[].imageKey`: 강사 이미지들

### 2. 배치 URL 요청
- Client가 모든 key를 수집
- 한 번의 API 호출로 모든 Presigned URL 요청
- Server가 각 key에 대해 Presigned URL 생성
- Map 형태로 반환: `{ key1: url1, key2: url2, ... }`

### 3. 이미지 병렬 로드
- Client가 각 Presigned URL로 S3에 병렬 요청
- 모든 이미지 동시 로드

## 배치 요청 최적화

### usePresignedUrls Hook 사용

```typescript
// 강의 상세 페이지
const { data: lecture } = useLectureDetail(id)

const allKeys = useMemo(() => [
  lecture?.lectureImageKey,
  ...(lecture?.orgFacilityKeys || []),
  ...(lecture?.teachers?.map(t => t.imageKey) || [])
].filter(Boolean), [lecture])

const { data: urlMap } = usePresignedUrls(allKeys)

// urlMap = { "lectures/...": "https://...", "organizations/...": "https://...", ... }
```

### 요청 최적화 전략

| 전략 | 설명 |
|------|------|
| 디바운싱 | key 수집 후 일정 시간 대기하여 한 번에 요청 |
| 청크 분할 | 50개 초과 시 여러 배치로 분할 |
| 캐시 활용 | 이미 캐시된 key는 배치에서 제외 |

## 예외 처리

| 조건 | 처리 |
|------|------|
| 일부 key가 Private | 관리자 아니면 해당 key 제외하고 반환 |
| 일부 key 존재 안함 | 해당 key만 제외하고 나머지 URL 반환 |
| 빈 배열 요청 | 빈 Map 반환 (에러 아님) |
| 50개 초과 요청 | 400 Bad Request |

## 관련 API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| POST | /api/v1/storage/presigned/url/batch | 배치 Presigned URL 발급 | △ |

※ 인증 △: Public key만 있으면 불필요, Private key 포함 시 필수 (관리자만 가능)

## Request/Response 예시

### Request

```json
POST /api/v1/storage/presigned/url/batch
Content-Type: application/json

{
  "keys": [
    "lectures/2024/01/01/thumb.jpg",
    "organizations/2024/01/02/facility1.jpg",
    "organizations/2024/01/02/facility2.jpg",
    "teachers/2024/01/03/profile.jpg"
  ]
}
```

### Response

```json
{
  "lectures/2024/01/01/thumb.jpg": "https://bucket.s3.../lectures/...?X-Amz-...",
  "organizations/2024/01/02/facility1.jpg": "https://bucket.s3.../organizations/...?X-Amz-...",
  "organizations/2024/01/02/facility2.jpg": "https://bucket.s3.../organizations/...?X-Amz-...",
  "teachers/2024/01/03/profile.jpg": "https://bucket.s3.../teachers/...?X-Amz-..."
}
```

## 성능 고려사항

| 항목 | 목표 | 비고 |
|------|------|------|
| 배치 API 응답 시간 | < 300ms (10개 기준) | S3Presigner는 네트워크 호출 없음 |
| 최대 배치 크기 | 50개 | 메모리/응답 크기 제한 |
| 병렬 S3 요청 | 브라우저 제한 (6개) | HTTP/2에서는 더 많이 가능 |
