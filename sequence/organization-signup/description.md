# 기관 회원가입 리팩토링 - 시퀀스 설명

## 필수 정보

### 1. 참여자 (Participants/Actors)

| 참여자 | 설명 | 기술 스택 |
|--------|------|-----------|
| 사용자 (User) | 기관 담당자 | 브라우저 |
| 프론트엔드 (Frontend) | 웹 클라이언트 | Next.js + Nginx |
| 백엔드 (Backend) | API 서버 | Spring + Spring Security |
| S3 | 이미지 저장소 | AWS S3 |
| DB (Database) | 데이터 저장소 | PostgreSQL |
| Mail Server | 이메일 발송 | SMTP |

### 2. 시나리오/흐름 설명

- 기관 검색 프로세스
- 기존 기관 선택 회원가입 프로세스
- 신규 기관 회원가입 프로세스
- 관리자 승인 프로세스 (이메일 발송 포함)
- 관리자 반려 프로세스 (이메일 발송 포함)

> **Note**: 이메일 인증 과정은 기존 `signup_login_description.md` 참조

---

### 3. 메시지 흐름 순서

#### 3-1. 기관 검색 흐름

```
1. 사용자 → 프론트엔드: 기관명 검색어 입력
2. 프론트엔드 → 백엔드: 기관 검색 요청 (GET /api/v1/auth/organizations/search?keyword=한국)
3. 백엔드 → DB: 기관명 LIKE 검색 조회
4. DB → 백엔드: 검색 결과 반환
5. 백엔드 → 프론트엔드: 200 OK (기관 목록: id, name)
6. 프론트엔드 → 사용자: 검색 결과 드롭다운 표시
```

#### 3-2. 기존 기관 선택 회원가입 흐름

```
1. 사용자 → 프론트엔드: 기관 검색 후 기존 기관 선택
2. 사용자 → 프론트엔드: 회원가입 폼 제출 (이메일, 비밀번호, 재직증명서 이미지, organizationId)
3. 프론트엔드 → 백엔드: 기관 회원가입 API 요청 (POST /api/v1/auth/signup/organization)
4. 백엔드 → DB: 이메일 중복 확인
5. DB → 백엔드: 조회 결과 반환
6. [조건] 이메일 중복 시:
   - 백엔드 → 프론트엔드: 409 Conflict (이메일 중복)
   - 프론트엔드 → 사용자: 에러 메시지 표시
   - 흐름 종료
7. 백엔드 → DB: 해당 기관에 이미 연결된 회원 존재 여부 확인
8. DB → 백엔드: 조회 결과 반환
9. [조건] 이미 연결된 회원 존재 시:
   - 백엔드 → 프론트엔드: 409 Conflict (이미 다른 사용자가 연결된 기관)
   - 프론트엔드 → 사용자: 에러 메시지 표시
   - 흐름 종료
10. 백엔드 → S3: 재직증명서 이미지 업로드
11. S3 → 백엔드: 이미지 URL 반환
12. 백엔드 → DB: 기관 정보 조회
13. DB → 백엔드: 기관 정보 반환
14. 백엔드 → DB: 재직증명서 URL 업데이트
15. 백엔드 → DB: Member 생성 (Role=ORGANIZATION, orgId=선택한 기관 ID)
16. DB → 백엔드: 저장 완료
17. 백엔드 → 프론트엔드: 201 Created (회원가입 성공, 승인 대기 상태)
18. 프론트엔드 → 사용자: "관리자 승인 후 이용 가능" 안내 표시
```

#### 3-3. 신규 기관 회원가입 흐름

```
1. 사용자 → 프론트엔드: 회원가입 폼 제출 (이메일, 비밀번호, 기관명, 재직증명서 이미지)
   - organizationId 미전송 (신규 기관)
2. 프론트엔드 → 백엔드: 기관 회원가입 API 요청 (POST /api/v1/auth/signup/organization)
3. 백엔드 → DB: 이메일 중복 확인
4. DB → 백엔드: 조회 결과 반환
5. [조건] 이메일 중복 시:
   - 백엔드 → 프론트엔드: 409 Conflict (이메일 중복)
   - 흐름 종료
6. 백엔드 → S3: 재직증명서 이미지 업로드
7. S3 → 백엔드: 이미지 URL 반환
8. 백엔드 → DB: Member 생성 (Role=ORGANIZATION)
9. DB → 백엔드: Member 저장 완료
10. 백엔드 → DB: Organization 생성 (userId=Member.id, status=PENDING)
11. DB → 백엔드: Organization 저장 완료
12. 백엔드 → DB: Member.orgId = Organization.id 업데이트
13. DB → 백엔드: 업데이트 완료
14. 백엔드 → 프론트엔드: 201 Created (회원가입 성공, 승인 대기 상태)
15. 프론트엔드 → 사용자: "관리자 승인 후 이용 가능" 안내 표시
```

#### 3-4. 관리자 승인 흐름

```
1. 관리자 → 프론트엔드: 기관 상세보기 → "승인" 버튼 클릭
2. 프론트엔드 → 백엔드: 기관 승인 API 요청 (PATCH /api/v1/admin/organizations/{orgId}/approve)
3. 백엔드 → DB: 해당 기관에 연결된 Member 조회
4. DB → 백엔드: Member 정보 반환
5. 백엔드 → DB: Organization.userId = Member.id 업데이트 (소유권 이전)
6. 백엔드 → DB: Organization.approvalStatus = APPROVED 업데이트
7. DB → 백엔드: 업데이트 완료
8. 백엔드 → Mail Server: 승인 이메일 발송 요청
9. Mail Server → 백엔드: 발송 완료
10. 백엔드 → 프론트엔드: 200 OK (승인 완료)
11. 프론트엔드 → 관리자: 승인 완료 메시지 표시
```

**승인 이메일 내용**
```
제목: [SW Campus] 기관 회원 가입이 승인되었습니다

{기관명} 담당자님께,

귀하의 기관 회원 가입 신청이 승인되었습니다.
이제 SW Campus의 모든 기능을 이용하실 수 있습니다.

[로그인하기] 버튼 포함
```

#### 3-5. 관리자 반려 흐름

```
1. 관리자 → 프론트엔드: 기관 상세보기 → "반려" 버튼 클릭
2. 프론트엔드 → 백엔드: 기관 반려 API 요청 (PATCH /api/v1/admin/organizations/{orgId}/reject)
3. 백엔드 → DB: 해당 기관에 연결된 Member 조회
4. DB → 백엔드: Member 정보 반환
5. 백엔드 → DB: ADMIN 역할 회원 조회 (관리자 연락처 제공용)
6. DB → 백엔드: Admin 정보 반환
7. 백엔드 → DB: Member 삭제 (Organization은 PENDING 상태 유지)
8. DB → 백엔드: 삭제 완료
9. 백엔드 → Mail Server: 반려 이메일 발송 요청 (관리자 연락처 포함)
10. Mail Server → 백엔드: 발송 완료
11. 백엔드 → 프론트엔드: 200 OK (반려 완료, 관리자 연락처 포함)
12. 프론트엔드 → 관리자: 반려 완료 메시지 표시
```

**반려 이메일 내용**
```
제목: [SW Campus] 기관 회원 가입이 반려되었습니다

{기관명} 담당자님께,

귀하의 기관 회원 가입 신청이 반려되었습니다.

문의사항이 있으시면 아래 연락처로 문의해 주세요.
- 이메일: {관리자 이메일}
- 전화번호: {관리자 전화번호}
```

---

## 선택 정보

### 4. 조건부 흐름 (alt/opt)

| 시나리오 | 분기 조건 |
|----------|-----------|
| 기존 기관 선택 | organizationId 전송 여부 |
| 중복 가입 체크 | 이미 연결된 회원 존재 여부 |
| 이메일 중복 | 이메일 사용 가능 / 중복 |

### 5. 반복 (loop)
- 없음

### 6. 병렬 처리 (par)
- 없음

### 7. 비동기 호출
- 이메일 발송 (내부적으로 비동기 처리 가능)

### 8. 노트/주석
- 기존 시드 데이터 271개 기관은 PENDING 상태
- 기관은 삭제되지 않음 (반려 시 Member만 삭제)
- 동일 기관에 다중 사용자 연결 불가

---

## 추가 기술 정보

### 기관 승인 상태

| 상태 | 설명 | 강의 등록 | 기관 정보 수정 |
|------|------|----------|----------------|
| PENDING | 승인 대기 | X | X |
| APPROVED | 승인 완료 | O | O |
| REJECTED | 승인 거부 | X | X |

### API 엔드포인트

| 기능 | Method | Endpoint | 인증 |
|------|--------|----------|------|
| 기관 검색 | GET | /api/v1/auth/organizations/search | 불필요 |
| 기관 회원가입 | POST | /api/v1/auth/signup/organization | 불필요 |
| 기관 승인 | PATCH | /api/v1/admin/organizations/{orgId}/approve | ADMIN |
| 기관 반려 | PATCH | /api/v1/admin/organizations/{orgId}/reject | ADMIN |

### 에러 케이스

| HTTP Status | 설명 | 발생 조건 |
|-------------|------|-----------|
| 400 Bad Request | 잘못된 요청 | 필수 필드 누락, 유효성 검증 실패 |
| 401 Unauthorized | 인증 필요 | 비로그인 (관리자 API) |
| 403 Forbidden | 권한 없음 | 관리자가 아닌 사용자 |
| 404 Not Found | 기관 없음 | 존재하지 않는 organizationId |
| 409 Conflict | 중복 | 이메일 중복 또는 이미 연결된 기관 |

### 데이터 모델 관계

```
Member (기관 담당자)
├── id
├── email
├── role = ORGANIZATION
└── orgId → Organization.id

Organization
├── id
├── userId → Member.id (승인 시 매핑)
├── name
├── approvalStatus (PENDING/APPROVED/REJECTED)
└── certificateUrl (재직증명서)
```

### PENDING 상태에서 기능 제한 구현

```java
// OrganizationService.java
public Organization getApprovedOrganizationByUserId(Long userId) {
    Organization organization = getOrganizationByUserId(userId);
    if (organization.getApprovalStatus() != ApprovalStatus.APPROVED) {
        throw new OrganizationNotApprovedException();
    }
    return organization;
}
```

사용처:
- `LectureController.createLecture()` - 강의 등록
- `LectureController.updateLecture()` - 강의 수정
- `MypageController.updateOrganization()` - 기관 정보 수정
