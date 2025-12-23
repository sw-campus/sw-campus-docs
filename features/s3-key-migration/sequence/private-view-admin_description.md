# Private 이미지 조회 (관리자) - 시퀀스 설명

## 개요

수료증, 재직증명서 등 민감한 이미지를 조회하는 흐름입니다.
**관리자만** Presigned GET URL을 발급받을 수 있으며, 업로드한 본인도 조회할 수 없습니다.

> **관련 사용자 스토리**: US-4 (Private 이미지 조회 - ADMIN)

## 참여자 (Actors)

| Actor | 설명 |
|-------|------|
| Admin | 관리자 (ROLE_ADMIN) |
| Client | Next.js 프론트엔드 (관리자 페이지) |
| Server | Spring Boot API 서버 |
| DB | PostgreSQL 데이터베이스 |
| S3 | AWS S3 Private Bucket |

## 흐름 설명

### 1. 수료증/기관 목록 요청
- 관리자가 관리자 페이지 접속
- Client가 수료증 또는 기관 목록 API 호출 (관리자 인증 필요)
- Server가 PENDING 상태의 항목 목록 조회
- Response에 S3 key 반환

### 2. S3Image 컴포넌트 렌더링
- Client가 `imageKey`를 `S3Image` 컴포넌트에 전달
- `usePresignedUrl` hook이 캐시 확인

### 3. Presigned URL 발급 (관리자 권한 체크)
- Client가 Storage API 호출 (Authorization 헤더 포함)
- Server가 key prefix로 Private 파일 판별 (`certificates/*`, `members/*`)
- Server가 관리자 권한 확인 (ROLE_ADMIN)
- 권한 있으면 Presigned GET URL 발급

### 4. 이미지 로드 및 승인/거절
- Client가 Presigned URL로 S3에서 이미지 로드
- 관리자가 이미지 확인 후 승인/거절 처리

## 권한 체크 로직

```java
public boolean canAccessPrivate(String key, boolean isAdmin) {
    // Private 파일은 관리자만 접근 가능
    if (isPrivateKey(key)) {
        return isAdmin;  // ROLE_ADMIN 확인
    }
    return false;
}

private boolean isPrivateKey(String key) {
    return key.startsWith("certificates/") || key.startsWith("members/");
}
```

## 예외 처리

| 조건 | HTTP 상태 | 처리 |
|------|:---------:|------|
| 인증 토큰 없음 | 401 | 로그인 페이지로 리다이렉트 |
| 토큰 만료 | 401 | 토큰 갱신 후 재시도 |
| 관리자 아님 | 403 | "관리자만 접근 가능합니다" 메시지 |
| 존재하지 않는 key | 404 | fallback 이미지 표시 |

## 관련 API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| GET | /api/v1/storage/presigned/url | Presigned URL 발급 | O (ADMIN) |
| GET | /api/v1/admin/certificates | 수료증 목록 | O (ADMIN) |
| GET | /api/v1/admin/organizations | 기관 목록 | O (ADMIN) |
| PATCH | /api/v1/admin/certificates/{id}/approve | 수료증 승인 | O (ADMIN) |
| PATCH | /api/v1/admin/certificates/{id}/reject | 수료증 거절 | O (ADMIN) |

## 보안 고려사항

1. **관리자 전용 접근**: Private 파일은 ROLE_ADMIN만 조회 가능
2. **업로드자 조회 불가**: 수료증을 업로드한 USER도 조회 불가
3. **Presigned URL 만료**: 15분으로 제한하여 URL 유출 피해 최소화
4. **HTTPS 전용**: Presigned URL은 HTTPS로만 생성
