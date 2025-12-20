# 마이페이지 (Mypage) Spec

## 개요

사용자(USER, ORGANIZATION)별 마이페이지 기능 명세입니다. 내 정보 관리, 후기/강의 조회, 설문조사 관리를 포함합니다.

---

## API

### 공통 - 내 정보

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/mypage/profile` | 내 정보 조회 | USER, ORG |
| PATCH | `/api/v1/mypage/profile` | 내 정보 수정 | USER, ORG |

**Profile Response**: email, name, nickname, phone, address, profileImageUrl, provider, role, hasSurvey

**수정 가능 필드**: nickname, phone, address

### 일반 사용자 (USER)

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/mypage/reviews` | 내 후기 목록 | USER |
| GET | `/api/v1/mypage/survey` | 내 설문조사 조회 | USER |
| PUT | `/api/v1/mypage/survey` | 설문조사 수정 (Upsert) | USER |

**후기 목록 Query**: page, size, status (PENDING/APPROVED/REJECTED)

### 기관 담당자 (ORGANIZATION)

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | `/api/v1/mypage/organization` | 기관 정보 조회 | ORG |
| PATCH | `/api/v1/mypage/organization` | 기관 정보 수정 | ORG |
| GET | `/api/v1/mypage/lectures` | 내 강의 목록 | ORG |

**기관 정보**: organizationId, organizationName, representativeName, businessNumber, phone, address, approvalStatus

---

## 비즈니스 로직

### 후기 수정 (REJECTED만 가능)

```java
if (review.getApprovalStatus() != ApprovalStatus.REJECTED) {
    throw new ReviewCannotBeModifiedException();
}
// 수정 후 PENDING으로 변경
```

### 강의 수정 (REJECTED만 가능)

```java
if (lecture.getLectureAuthStatus() != LectureAuthStatus.REJECTED) {
    throw new LectureCannotBeModifiedException();
}
// 수정 후 PENDING으로 변경
```

### 설문조사 Upsert

- 기존 데이터 존재 → Update
- 기존 데이터 없음 → Insert

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| REVIEW_NOT_FOUND | 404 | 후기를 찾을 수 없습니다 |
| REVIEW_CANNOT_BE_MODIFIED | 400 | REJECTED 상태가 아닌 후기 수정 시도 |
| LECTURE_NOT_FOUND | 404 | 강의를 찾을 수 없습니다 |
| LECTURE_CANNOT_BE_MODIFIED | 400 | REJECTED 상태가 아닌 강의 수정 시도 |
| ORGANIZATION_NOT_FOUND | 404 | 기관 정보 조회 실패 |
| ACCESS_DENIED | 403 | 본인 소유가 아닌 리소스 접근 |
| INVALID_ROLE | 403 | 해당 역할에서 사용할 수 없는 기능 |

---

## 구현 노트

### 2025-12-14 - 초기 구현

- 내 정보 조회/수정
- 후기 목록 (상태 필터)
- 설문조사 Upsert
- 기관 정보 조회/수정
- 강의 목록 (상태 필터)
