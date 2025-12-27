# Features Documentation v3.0

기능별 문서를 관리하는 폴더입니다.

---

## 폴더 구조

```
features/
├── README.md                    # 이 파일 (가이드 및 기능 목록)
│
└── {feature-name}/              # 기능별 폴더
    ├── prd.md                   # 요구사항 (What)
    ├── sequence/                # 흐름 (Flow)
    │   ├── description.md
    │   └── diagram.md
    └── spec.md                  # 설계 + 구현 노트 (How + Result)
```

---

## 문서 작성 순서

```
PRD → Sequence → Spec → [구현] → Spec 업데이트
                              (구현 노트 추가)
```

| 순서 | 문서 | 역할 |
|:----:|------|------|
| 1 | `prd.md` | 요구사항 정의 (What) |
| 2 | `sequence/` | 흐름 정의 (Flow) |
| 3 | `spec.md` | 설계 + 구현 노트 (How + Result) |

---

## 문서별 역할

### PRD (prd.md)
- **"무엇을(What)"** 만들 것인가
- 비즈니스 배경 및 목적
- 사용자 스토리
- 기능/비기능 요구사항
- 범위(Scope) 정의

### Sequence (sequence/)
- **"흐름(Flow)"** 정의
- 참여자(Actors) 정의
- 메시지 흐름 순서
- 조건부 흐름 (alt/opt)
- Mermaid 시퀀스 다이어그램

### Spec (spec.md)
- **"어떻게(How)"** + **"결과(Result)"**
- API 엔드포인트 설계
- 데이터베이스 스키마
- 에러 코드 정의
- 보안 고려사항
- **구현 노트** (변경사항, PR 링크, 특이사항)

---

## spec.md 템플릿

```markdown
# {Feature} Spec

## API

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | /api/v1/... | ... | O/X |

## DB 스키마

| 테이블 | 컬럼 | 타입 | 설명 |
|--------|------|------|------|

## 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|

---

## 구현 노트

### 2025-12-20 - 초기 구현
- PR: #123
- 주요 변경: ...
- 특이사항: ...

### 2025-12-25 - 기능 추가
- PR: #456
- 추가된 API: ...
```

---

## 기능 목록

| 기능 | 설명 | 상태 |
|------|------|------|
| [admin](./admin/) | 관리자 기능 | ✅ 완료 |
| [auth](./auth/) | 회원가입, 로그인, 로그아웃, 토큰 관리 | ✅ 완료 |
| [data-migration](./data-migration/) | 초기 데이터 마이그레이션 | ✅ 완료 |
| [mypage](./mypage/) | 마이페이지 | ✅ 완료 |
| [organization-signup](./organization-signup/) | 기관 회원가입 리팩토링 | ✅ 완료 |
| [review](./review/) | 후기 작성, 수정, 삭제, 수료증 인증 | ✅ 완료 |
| [survey](./survey/) | 사용자 설문조사 | ✅ 완료 |
| [compare](./compare/) | 강의 비교 | 🚧 진행중 |
| [lecture](./lecture/) | 강의 관리 | 🚧 진행중 |
| [wishlist](./wishlist/) | 찜 목록 | 🚧 진행중 |
| [my-lecture-review-detail](./my-lecture-review-detail/) | 내 강의 후기 상세 조회 API | ✅ 완료 |
| [s3-key-migration](./s3-key-migration/) | S3 Key 기반 아키텍처 마이그레이션 | ✅ 완료 |
| [organization-reviews](./organization-reviews/) | 기관별 후기 페이지네이션 | ✅ 완료 |
| [certificate-ocr-matching](./certificate-ocr-matching/) | 수료증 OCR 다단계 강의명 매칭 검증 | ✅ 완료 |

### 상태 범례
- 📝 예정: 문서 없음
- 🚧 진행중: 문서 있으나 spec.md 없음
- ✅ 완료: spec.md 작성 완료

---

## 마이그레이션 안내

> 기존 `tech-spec.md` + `report/` 구조는 `spec.md`로 통합됩니다.
> `plan/` 폴더는 더 이상 사용하지 않습니다 (AI 협업 시 불필요).
