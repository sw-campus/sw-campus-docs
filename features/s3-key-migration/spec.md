# S3 Key 기반 아키텍처 마이그레이션 Spec

## 설계 결정

### 왜 S3 URL 대신 Key만 저장하는가?

보안 및 유연성 향상.

| 방식 | 장점 | 단점 |
|------|------|------|
| Full URL | 직접 접근 가능 | 영구 노출, 버킷 변경 시 마이그레이션 필요 |
| Key only | 접근 제어 가능, 만료 시간 설정 | Presigned URL 발급 필요 |

Private 파일(수료증, 재직증명서)은 관리자만 조회 가능해야 함.
Key 저장 + Presigned URL 방식으로 접근 제어 구현.

### 왜 Public/Private 버킷을 이원화했는가?

접근 정책 독립 관리.

| 버킷 | 용도 | 접근 정책 |
|------|------|----------|
| Public | 강의/기관/강사 이미지 | 모두 접근 가능 |
| Private | 수료증, 재직증명서 | 관리자만 Presigned URL 발급 가능 |

S3 버킷 정책으로 Network Level 접근 차단.
Application Level에서 Presigned URL로 제한적 접근 허용.

### 왜 Presigned URL 만료 시간이 15분인가?

보안과 사용성의 균형.

```
15분 < 일반적인 사용자 세션 시간
- URL 노출 시 피해 제한
- React Query staleTime(5분) < 만료 시간(15분) → 캐시 안전성
- 자동 갱신으로 UX 문제 해결
```

### 왜 Private 파일은 업로드한 본인도 조회 불가한가?

보안 및 감시 체계.

- 수료증/재직증명서는 "검증 대상"
- 업로드자가 조회 가능 → 공개 용도로 악용 가능
- 관리자만 조회 → 내부 검증 프로세스 강제

### 왜 배치 API 최대 크기가 50개인가?

성능과 보안의 균형.

```
메모리: 50개 Presigned URL ≈ 15KB 응답
보안: 대량 요청으로 DoS 위험 방지
권한 체크 루프: 50번은 무시할 수준
```

10개는 너무 적고, 100개+는 불필요.

### 왜 S3Presigner를 사용하는가?

네트워크 최적화.

```java
// S3Client: S3와 네트워크 통신 필요
// S3Presigner: 로컬에서 서명만 생성 (AWS 호출 없음)
```

100ms 이상 빠름 (네트워크 왕복 제거).

### 왜 Private Key 판별을 Prefix 매칭으로 했는가?

런타임 유연성.

```java
PRIVATE_PREFIXES = {"certificates/", "employment-certificates/", "members/"}

// O(1) 해시 조회로 빠른 판별
// 새로운 private 카테고리 추가 시 코드 변경만으로 대응
```

DB 쿼리 없이 Key 문자열만으로 판별 가능.

### 왜 카테고리별 업로드 권한을 세분화했는가?

역할별 책임 분리.

| Category | ADMIN | ORGANIZATION | USER |
|----------|:-----:|:------------:|:----:|
| banners | O | X | X |
| lectures | O | O | X |
| certificates | O | O | O |

ADMIN: 모든 카테고리
ORGANIZATION: 자신 기관 정보
USER: 본인 정보(수료증)만 업로드

---

## 구현 노트

### 2025-12-22 - Private 파일 S3 Key 저장 방식 구현 [Server][Client]

- Server PR: #200
- Client PR: #68
- 배경: Private 파일 접근 제어 필요
- 변경:
  - **Server**
    - `StorageController` 추가: Presigned GET/PUT URL API
    - `PresignedUrlService` 인터페이스 + `S3PresignedUrlService` 구현
    - `uploadPrivate()`: S3 Key만 반환
    - 카테고리별 업로드 권한 체크 로직
  - **Client**
    - `S3Image` 컴포넌트: Presigned URL로 이미지 표시
    - `usePresignedUrl`, `usePresignedUrls` 훅
    - 기존 URL 데이터 호환성 유지 (URL이면 직접 사용)
- 특이사항:
  - `next/image` 대신 `<img>` 태그 사용 (동적 S3 도메인)
  - staleTime(5분) < URL 만료 시간(15분)으로 캐시 안전성

### 2025-12-22 - DB 마이그레이션 [Server]

- 변경: URL → Key 변환 Flyway 스크립트
- 영향 테이블:
  - `certificates.image_url`
  - `organizations.certificate_url`
  - `lectures.lecture_image_url` (Public, 하위호환성)
