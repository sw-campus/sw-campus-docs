# S3 Key 기반 아키텍처 마이그레이션 - PRD

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-22 |
| 상태 | Draft |
| 버전 | 0.4 |

---

## 1. 개요

### 1.1 배경

현재 시스템은 S3에 업로드된 이미지의 **full URL**을 DB에 저장하고 있습니다.

```
예: https://bucket.s3.ap-northeast-2.amazonaws.com/lectures/2024/01/01/uuid.jpg
```

이 방식은 다음과 같은 문제가 있습니다:

1. **Private/Public 파일 구분 불가**: 수료증, 재직증명서 등 민감한 이미지도 public URL로 저장되어 URL을 알면 누구나 접근 가능
2. **보안 취약점**: URL 유출 시 영구적으로 접근 가능
3. **유연성 부족**: 버킷 이름이나 리전 변경 시 모든 DB 레코드 수정 필요

### 1.2 목적

S3 **key만 DB에 저장**하고, 이미지 접근 시 **Presigned GET URL**을 발급받아 사용하는 방식으로 변경합니다.

```
DB 저장값: lectures/2024/01/01/uuid.jpg (key만)
실제 접근: Presigned URL (15분 만료)
```

**기대 효과**:
- Private 파일에 대한 접근 권한 제어 가능 (관리자 전용 조회)
- URL 유출되어도 만료 시간 후 접근 불가
- 버킷/리전 변경에 유연하게 대응

### 1.3 범위

**포함**:
- Backend: Presigned GET URL 발급 API 구현
- Backend: DB 데이터 마이그레이션 (URL → Key)
- Backend: Private 파일 접근 권한 체크 (관리자 전용 조회)
- Backend: Private Bucket 업로드 API (USER, ORGANIZATION용)
- Frontend: S3Image 컴포넌트 및 usePresignedUrl hook 구현
- Frontend: 기존 Image 컴포넌트 → S3Image 변경 (side effect 최소화)

**제외**:
- CDN 설정 변경
- S3 버킷 정책 변경
- 일반 사용자/기관의 Private 파일 조회 기능

---

## 2. 사용자 스토리

### 2.1 주요 사용자

| 사용자 | 역할 | 업로드 권한 | 조회 권한 |
|--------|------|-------------|-----------|
| USER | 일반 사용자 | Public: O / **Private: O** (수료증) | Public: O / Private: **X** |
| ORGANIZATION | 기관 담당자 | Public: O (로고, 시설) / **Private: O** (재직증명서) | Public: O / Private: **X** |
| ADMIN | 관리자 | Public: O / Private: O | **Public: O / Private: O** |

### 2.2 사용자 스토리

#### US-1: Public 이미지 조회
- **사용자**: 모든 사용자 (비로그인 포함)
- **행동**: 강의 상세 페이지에서 썸네일, 시설 이미지를 본다
- **목적**: 강의 정보를 시각적으로 확인하기 위해

#### US-2: Private 이미지 업로드 (USER)
- **사용자**: 일반 사용자
- **행동**: 수료증 인증을 위해 수료증 이미지를 업로드한다
- **목적**: 수강 완료를 증명하기 위해
- **제약**: 업로드 후 본인도 이미지를 직접 조회할 수 없음

#### US-3: Private 이미지 업로드 (ORGANIZATION)
- **사용자**: 기관 담당자
- **행동**: 기관 인증을 위해 재직증명서/사업자등록증을 업로드한다
- **목적**: 기관의 신뢰성을 증명하기 위해
- **제약**: 업로드 후 본인도 이미지를 직접 조회할 수 없음

#### US-4: Private 이미지 조회 (ADMIN)
- **사용자**: 관리자
- **행동**: 관리자 페이지에서 회원/기관이 제출한 수료증/재직증명서 이미지를 확인한다
- **목적**: 문서의 진위 여부를 확인하고 승인/거절하기 위해

---

## 3. 기능 요구사항

### 3.1 필수 기능 (Must Have)

| ID | 기능 | 설명 | 우선순위 |
|----|------|------|:--------:|
| FR-1 | Presigned GET URL 발급 API | S3 key를 받아 Presigned GET URL 반환 | P0 |
| FR-2 | 배치 Presigned URL API | 여러 key를 한 번에 받아 URL Map 반환 | P0 |
| FR-3 | S3Image 컴포넌트 | key를 받아 Presigned URL로 이미지 표시 | P0 |
| FR-4 | usePresignedUrl Hook | React Query 기반 Presigned URL 캐싱 | P0 |
| FR-5 | DB 마이그레이션 | 기존 full URL → key로 변환 | P0 |
| FR-6 | Public 파일 접근 | 인증 없이 Presigned GET URL 발급 | P0 |
| FR-7 | Private 파일 조회 | **관리자만** Presigned GET URL 발급 | P0 |
| FR-8 | Private 파일 업로드 | USER/ORGANIZATION이 Private Bucket에 업로드 | P0 |

### 3.2 선택 기능 (Nice to Have)

| ID | 기능 | 설명 | 우선순위 |
|----|------|------|:--------:|
| FR-N1 | 이미지 프리페칭 | 목록 페이지에서 배치 API로 미리 URL 발급 | P2 |
| FR-N2 | 만료 전 자동 갱신 | URL 만료 1분 전 자동 refetch | P2 |

---

## 4. 비기능 요구사항

| 항목 | 요구사항 |
|------|----------|
| 성능 | 단일 Presigned URL 발급 < 100ms, 배치(10개) < 300ms |
| 보안 | Private 파일 조회는 **관리자만** 가능, 업로드자 본인도 조회 불가 |
| 캐싱 | React Query staleTime 5분, Presigned URL 만료 15분 |
| 확장성 | 배치 API는 최대 50개 key 처리 가능 |
| **하위호환성** | **Public 이미지 표시 기능은 기존과 동일하게 동작해야 함 (side effect 없음)** |

---

## 5. 화면 흐름

### 5.1 Public 이미지 조회 - 모든 사용자

```
[강의 목록 페이지]
    │
    ├─ API 응답: { lectureImageKey: "lectures/..." }
    │
    └─ S3Image 컴포넌트
         │
         ├─ usePresignedUrl("lectures/...")
         │     │
         │     └─ GET /api/v1/storage/presigned/url?key=lectures/...
         │           │
         │           └─ Response: { url: "https://...", expiresIn: 900 }
         │
         └─ <Image src={presignedUrl} />
```

### 5.2 Private 이미지 업로드 - USER/ORGANIZATION

```
[수료증 제출 페이지] 또는 [기관 정보 등록 페이지]
    │
    ├─ 파일 선택
    │
    └─ S3ImageUpload 컴포넌트
         │
         ├─ POST /api/v1/storage/presigned/upload (Private Bucket)
         │     │
         │     └─ Response: { uploadUrl: "https://...", key: "certificates/..." }
         │
         ├─ PUT {uploadUrl} (S3 직접 업로드)
         │
         └─ 업로드 완료 → key를 서버에 저장
              │
              └─ ⚠️ 업로드 후 본인은 이미지 조회 불가
```

### 5.3 Private 이미지 조회 - 관리자 전용

```
[관리자 페이지 - 수료증/기관 관리]
    │
    ├─ API 응답: { imageKey: "certificates/..." }
    │
    └─ S3Image 컴포넌트
         │
         ├─ usePresignedUrl("certificates/...")
         │     │
         │     └─ GET /api/v1/storage/presigned/url?key=certificates/...
         │           │   (Authorization: Bearer {adminToken})
         │           │
         │           ├─ 권한 체크: ROLE_ADMIN 확인
         │           │
         │           └─ Response: { url: "https://...", expiresIn: 900 }
         │
         └─ <Image src={presignedUrl} />
```

---

## 6. 제약사항 및 가정

### 6.1 제약사항

- S3 버킷에 CORS 설정이 되어 있어야 함
- AWS SDK v2 사용 (현재 프로젝트 의존성)
- Presigned URL 만료 시간은 S3 정책에 따라 최대 7일까지만 가능
- **Private 파일 조회는 관리자만 가능** (업로드한 본인도 조회 불가)

### 6.2 가정

- 모든 이미지는 이미 S3에 업로드되어 있음
- 기존 DB의 URL 형식이 일관됨 (`https://{bucket}.s3.{region}.amazonaws.com/{key}`)
- 프론트엔드는 Next.js Image 컴포넌트를 사용 중

### 6.3 Side Effect 최소화 원칙

Public Storage 변경 시 다음을 준수합니다:

1. **API 응답 구조 유지**: 필드명만 `*Url` → `*Key`로 변경, 구조는 동일
2. **컴포넌트 인터페이스 호환**: `S3Image`는 `next/image`와 동일한 props 지원
3. **점진적 마이그레이션**: 한 번에 모든 컴포넌트 변경 X, 기능 단위로 변경
4. **Fallback 처리**: key가 없거나 null이면 기존 동작과 동일하게 처리
5. **캐시 무효화 방지**: 새 Presigned URL은 React Query 캐시로 관리

---

## 7. 용어 정의

| 용어 | 정의 |
|------|------|
| S3 Key | S3 버킷 내 객체의 경로 (예: `lectures/2024/01/01/uuid.jpg`) |
| Presigned URL | 임시 인증 정보가 포함된 S3 접근 URL, 만료 시간 있음 |
| Public 파일 | 인증 없이 접근 가능한 파일 (`lectures/*`, `organizations/*`, `banners/*`, `teachers/*`) |
| Private 파일 | **관리자만 조회** 가능한 파일 (`certificates/*`, `members/*`) |
| Public Bucket | 공개 이미지 저장 버킷 |
| Private Bucket | 민감 이미지 저장 버킷 (수료증, 재직증명서 등) |

---

## 8. 영향받는 테이블/필드

### 8.1 Public 파일 (모든 사용자 조회 가능)

| 테이블 | 필드 | 설명 | 업로드 | 조회 |
|--------|------|------|--------|------|
| lectures | lecture_image_url | 강의 대표 이미지 | ORGANIZATION | ALL |
| organizations | org_logo_url | 기관 로고 | ORGANIZATION | ALL |
| organizations | facility_image_url ~ 4 | 시설 이미지 (4개) | ORGANIZATION | ALL |
| teachers | teacher_image_url | 강사 프로필 이미지 | ORGANIZATION | ALL |
| banners | image_url | 배너 이미지 | ADMIN | ALL |

### 8.2 Private 파일 (관리자만 조회 가능)

| 테이블 | 필드 | 설명 | 업로드 | 조회 |
|--------|------|------|--------|------|
| organizations | certificate_url | 사업자등록증 | ORGANIZATION | **ADMIN only** |
| certificates | image_url | 수료증 이미지 | USER | **ADMIN only** |

---

## 9. 권한 매트릭스

### 9.1 업로드 권한

| 파일 유형 | USER | ORGANIZATION | ADMIN |
|-----------|:----:|:------------:|:-----:|
| Public (강의, 기관, 배너) | O | O | O |
| Private (수료증) | **O** | X | O |
| Private (재직증명서/사업자등록증) | X | **O** | O |

### 9.2 조회 권한

| 파일 유형 | USER | ORGANIZATION | ADMIN |
|-----------|:----:|:------------:|:-----:|
| Public (강의, 기관, 배너) | O | O | O |
| Private (수료증) | **X** | X | **O** |
| Private (재직증명서/사업자등록증) | X | **X** | **O** |

> **핵심**: Private 파일은 업로드한 본인도 조회할 수 없으며, 오직 관리자만 조회 가능

---

## 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 0.1 | 2025-12-22 | 초안 작성 |
| 0.2 | 2025-12-22 | US-2 삭제, Private 접근을 관리자 전용으로 변경, Side Effect 최소화 원칙 추가 |
| 0.3 | 2025-12-22 | Private 업로드 스토리 추가 (US-2, US-3), 권한 매트릭스 추가, 업로드자 본인도 조회 불가 명시 |
| 0.4 | 2025-12-22 | USER의 Public 업로드 권한 추가 |
