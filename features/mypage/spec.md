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

### 설문조사 (2025-01-15 분리)

> 설문조사 설계 결정은 [features/survey/spec.md](../survey/spec.md)로 이동되었습니다.
>
> **분리 사유**: 성향 테스트 15문항 추가, 어드민 문항 관리 기능, 버전 관리 등
> 기능 규모가 커져 별도 문서로 관리

---

## 구현 노트

### 2025-12-12 - 설문조사 초기 구현 [Server][Client] (Deprecated)

> 설문조사 기능이 리팩토링되어 [features/survey/](../survey/)로 이동되었습니다.
> 구현 노트는 survey/spec.md에서 관리됩니다.

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
