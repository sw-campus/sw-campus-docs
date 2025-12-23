# Private 이미지 업로드 - 시퀀스 설명

## 개요

수료증, 재직증명서 등 민감한 이미지를 Private Bucket에 업로드하는 흐름입니다.
USER와 ORGANIZATION 모두 업로드할 수 있지만, **업로드 후 본인도 조회할 수 없습니다**.

> **관련 사용자 스토리**: US-2 (Private 이미지 업로드 - USER), US-3 (Private 이미지 업로드 - ORGANIZATION)

## 참여자 (Actors)

| Actor | 설명 |
|-------|------|
| User | 일반 사용자 (수료증 업로드) |
| Organization | 기관 담당자 (재직증명서/사업자등록증 업로드) |
| Client | Next.js 프론트엔드 |
| Server | Spring Boot API 서버 |
| DB | PostgreSQL 데이터베이스 |
| S3 | AWS S3 Private Bucket |

## 흐름 설명

### 1. 파일 선택
- 사용자가 수료증/재직증명서 업로드 페이지 접속
- 파일 선택 UI에서 이미지 파일 선택
- Client가 파일 검증 (타입, 크기)

### 2. Presigned PUT URL 발급
- Client가 Storage API 호출하여 업로드용 Presigned URL 요청
- Server가 Private Bucket용 Presigned PUT URL 생성
- key 형식: `certificates/{yyyy/MM/dd}/{uuid}.{ext}` 또는 `members/{...}`

### 3. S3 직접 업로드
- Client가 Presigned PUT URL로 S3에 직접 파일 업로드
- 업로드 진행률 표시 (멀티파트 업로드 시)

### 4. 업로드 완료 처리
- Client가 서버에 업로드 완료 알림 (key 전달)
- Server가 DB에 key 저장 (certificates 또는 organizations 테이블)
- **업로드 후 본인은 이미지를 조회할 수 없음**

## 업로드 권한

| 사용자 | 업로드 대상 | 저장 경로 |
|--------|------------|-----------|
| USER | 수료증 | `certificates/{date}/{uuid}.jpg` |
| ORGANIZATION | 재직증명서/사업자등록증 | `members/{date}/{uuid}.jpg` |

## 예외 처리

| 조건 | 처리 |
|------|------|
| 파일 크기 초과 (25MB) | 클라이언트에서 에러 표시 |
| 지원하지 않는 파일 형식 | 클라이언트에서 에러 표시 |
| 인증 토큰 없음/만료 | 401 에러, 로그인 페이지로 이동 |
| S3 업로드 실패 | 재시도 옵션 제공 |
| Presigned URL 만료 | 새 URL 발급 후 재시도 |

## 관련 API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| POST | /api/v1/storage/presigned/upload | Presigned PUT URL 발급 | O |
| POST | /api/v1/certificates/verify | 수료증 업로드 완료 및 OCR 검증 | O |
| PATCH | /api/v1/mypage/organization | 기관 정보 (재직증명서) 업로드 | O |

## 보안 고려사항

1. **Private Bucket**: 수료증/재직증명서는 Private Bucket에만 저장
2. **업로드 후 조회 불가**: 업로드한 본인도 이미지 조회 불가 (관리자만 가능)
3. **Presigned URL 만료**: PUT URL도 짧은 만료 시간 설정 (15분)
4. **파일 검증**: 서버에서 Content-Type 검증
