# 마이페이지 (Mypage) Spec

## 설계 결정

### 마이페이지 기본

#### 왜 역할별로 API를 분리했는가? (USER vs ORGANIZATION)

데이터 모델과 비즈니스 로직이 완전히 다름.

| 역할 | 주요 데이터 | 특성 |
|------|------------|------|
| USER | 프로필, 후기, 설문조사 | 개인 정보 관리 |
| ORGANIZATION | 기관 정보, 강의 목록 | 기관 운영 관리 |

`@PreAuthorize("hasRole('USER')")`, `@PreAuthorize("hasRole('ORGANIZATION')")` 으로 명확하게 분리.

#### 왜 프로필 수정 전 비밀번호 검증을 별도 API로 분리했는가?

1. 클라이언트가 프로필 수정 화면 진입 전에 본인 확인 필요
2. OAuth 사용자와 로컬 사용자 구분 처리 (소셜 로그인은 비밀번호 없으므로 항상 true)
3. 두 번의 요청으로 사용자 의도를 명확히 함

```java
// OAuth 사용자는 비밀번호 검증 스킵
if (member.isSocialUser()) return true;
return passwordEncoder.matches(password, member.getPassword());
```

#### 왜 수강 완료 강의 목록에 canWriteReview 플래그를 포함했는가?

프론트엔드가 각 강의마다 "후기 작성" 버튼 표시 여부를 바로 알 수 있음.

- 백엔드에서 한 번에 계산 후 포함 (N+1 문제 해결)
- Review 조회 결과와 Certificate 목록을 메모리 내에서 join
- 클라이언트는 추가 API 호출 불필요

#### 왜 기관 정보 수정에 MULTIPART_FORM_DATA를 사용했는가?

파일 업로드 4개 (로고, 사업자등록증, 시설이미지 4개)를 동시에 처리해야 함.

```java
@PatchMapping(value = "/organization", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<Void> updateOrganization(
    @RequestPart(name = "organizationName") String organizationName,
    @RequestPart(name = "logo", required = false) MultipartFile logo,
    // ... 4개 시설 이미지
)
```

#### 왜 기관 강의 상세 조회에서 리소스 소유권을 확인하는가?

Spring Security의 `@PreAuthorize("hasRole('ORGANIZATION')")`는 역할만 체크.
다른 기관의 강의를 조회하면 안 되므로 리소스 소유권 추가 확인.

```java
if (!org.getId().equals(lecture.getOrgId())) {
    throw new AccessDeniedException("본인 기관의 강의만 조회할 수 있습니다.");
}
```

---

### 설문조사

#### 왜 사용자당 1개의 설문조사만 허용하는가?

`member_surveys.user_id`를 PK로 설정 (UNIQUE 제약).

- 강의 추천에 최신 설문조사 1개만 필요
- 히스토리 관리 불필요 (현재 상태만 중요)
- 동일 회원이 2번째 작성 시 409 Conflict 반환

#### 왜 설문조사에 Upsert 패턴을 사용했는가?

회원당 설문조사는 최대 1개. 존재 여부와 관계없이 동일한 결과 보장.

```
PUT /api/v1/mypage/survey
- 존재하면 → Update
- 없으면 → Insert
```

POST + PUT 분리 시 클라이언트가 존재 여부를 먼저 확인해야 함. Upsert로 단순화.

#### 왜 희망 직무/자격증을 CSV 문자열로 저장하는가?

```java
@Column(length = 255)
private String wantedJobs;  // "백엔드, 데이터"

@Column(length = 500)
private String licenses;    // "정보처리기사, SQLD, AWS SAA"
```

- 현재 검색/필터 요구사항 없음
- 단순 표시 용도로 충분
- 정규화 테이블 생성 오버헤드 불필요

#### 왜 금액을 BigDecimal로 저장하는가?

```java
@Column(name = "affordable_amount", precision = 15, scale = 2)
private BigDecimal affordableAmount;
```

- 정확한 금액 계산 필요 (부동소수점 오류 방지)
- Java ↔ JavaScript 변환 시 정밀도 유지

#### 왜 Boolean wrapper 타입을 사용하는가?

```java
Boolean bootcampCompleted;   // null, true, false 가능
Boolean hasGovCard;
```

- null = 미응답 상태 표현 가능
- 선택적 질문 지원

---

## 구현 노트

### 2025-12-12 - 설문조사 초기 구현 [Server][Client]

- Server:
  - 설문조사 CRUD (POST/GET/PUT)
  - USER 본인만 작성/수정 가능
  - ADMIN 전체 조회 (수정 불가)
  - 회원 탈퇴 시 CASCADE 삭제
  - 관련: `MemberSurveyService.java`, `MemberSurveyEntity.java`
- Client:
  - `SurveyForm.tsx` - 폼 컴포넌트 (embedded/standalone 모드)
  - Zod + React Hook Form 검증
  - 저장 완료 시 `window.dispatchEvent(new Event('survey:saved'))` 발생

### 2025-12-14 - 마이페이지 초기 구현 [Server][Client]

- Server:
  - 내 정보 조회/수정
  - 수강 완료 강의 목록 (canWriteReview 포함)
  - 설문조사 Upsert
  - 기관 정보 조회/수정 (Multipart)
  - 강의 목록
- Client:
  - ProfileCard - 프로필 조회, 탈퇴
  - PersonalForm - 개인정보 수정 (embedded/standalone 모드)
  - OrgInfoForm - 기관정보 수정 (파일 업로드 포함)
  - 탭 기반 UI (기관: 기관정보/강의관리/내정보)

### 2025-12-14 - 비밀번호 변경 기능 구현 [Server][Client]

- 변경:
  - `PasswordChangeModal` 컴포넌트 추가
  - `PasswordVerifyModal` - 개인정보 수정 전 본인 확인
  - OAuth 사용자는 비밀번호 관련 UI 숨김

### 2025-12-21 - 닉네임 중복 검사 추가 [Server][Client]

- PR: #186
- 변경:
  - 프로필 수정 시 닉네임 중복 검사 (본인 제외)
  - 닉네임 유효성 규칙 적용 (최대 20자, 허용 문자: a-zA-Z0-9가-힣_-)
  - PostgreSQL `LOWER()` 인덱스로 대소문자 무시
