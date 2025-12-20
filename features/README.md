# Features Documentation v2.0

기능별 문서를 관리하는 폴더입니다.

---

## 폴더 구조

### 기본 구조 (단일 파일)

```
features/
├── README.md                    # 이 파일 (가이드 및 기능 목록)
│
├── {feature-name}/              # 기능별 폴더
│   ├── prd.md                   # Product Requirements Document
│   ├── sequence/                # 시퀀스 다이어그램 (폴더)
│   │   ├── description.md       # 흐름 설명
│   │   └── diagram.md           # Mermaid 다이어그램
│   ├── tech-spec.md             # Technical Specification
│   └── report.md                # Implementation Report
│
└── {another-feature}/
    └── ...
```

### 세분화된 구조 (폴더로 확장)

문서가 커지거나 세분화가 필요한 경우, **PRD를 제외한** 문서들은 폴더로 확장할 수 있습니다.

```
features/
├── README.md
│
└── {feature-name}/
    ├── prd.md                   # PRD는 항상 단일 파일 유지
    │
    ├── sequence/                # 시퀀스 (항상 폴더)
    │   ├── description.md       # 흐름 설명
    │   └── diagram.md           # Mermaid 다이어그램
    │
    ├── tech-spec/               # Tech Spec 폴더로 확장
    │   ├── README.md            # Tech Spec 개요 및 목차
    │   ├── api.md               # API 설계
    │   ├── database.md          # DB 스키마
    │   ├── security.md          # 보안 설계
    │   └── error-codes.md       # 에러 코드 정의
    │
    └── report/                  # Report 폴더로 확장
        ├── README.md            # 전체 보고서 개요
        ├── milestone-1.md       # 마일스톤별 구현 보고서
        ├── milestone-2.md
        └── milestone-3.md
```

### 구조 선택 기준

| 상황 | 권장 구조 |
|------|----------|
| 소규모 기능, 단순한 설계 | 단일 파일 (`tech-spec.md`, `report.md`) |
| 대규모 기능, 복잡한 설계 | 폴더 확장 (`tech-spec/`, `report/`) |
| 여러 마일스톤으로 나뉘는 경우 | `report/` 폴더 확장 |
| API, DB, 보안 등 영역이 많은 경우 | `tech-spec/` 폴더 확장 |

---

## 문서 작성 순서

각 기능은 아래 순서로 문서를 작성합니다:

| 순서 | 문서 | 설명 |
|:----:|------|------|
| 1 | `prd.md` | **Product Requirements Document** - 비즈니스 요구사항, 사용자 스토리, 기능 범위 정의 |
| 2 | `sequence/` | **Sequence Diagram** - 참여자, 메시지 흐름, Mermaid 다이어그램 |
| 3 | `tech-spec.md` | **Technical Specification** - API 설계, DB 스키마, 에러 코드 |
| 4 | `report.md` | **Implementation Report** - 구현 결과, 테스트 결과, 변경 사항 |

> **Note**: `plan.md`는 AI 협업 시 실시간으로 계획-실행이 이루어지므로 선택적으로 사용합니다.
> 대규모 프로젝트나 다인 협업 시에만 별도 작성을 권장합니다.

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

### Tech Spec (tech-spec.md)
- **"어떻게(How)"** 만들 것인가
- API 엔드포인트 설계
- 데이터베이스 스키마
- 에러 코드 정의
- 보안 고려사항

### Report (report.md)
- **"결과(Result)"** 보고
- 구현 현황
- 테스트 결과
- Tech Spec 대비 변경 사항
- 배포 정보

---

## 워크플로우

```
PRD → Sequence → Tech Spec → [구현] → Report
       ↑
       흐름을 먼저 정의하면
       API 설계가 자연스럽게 도출됨
```

---

## 기능 목록

| 기능 | 설명 | 상태 |
|------|------|------|
| [auth](./auth/) | 회원가입, 로그인, 로그아웃, 토큰 관리 | 🚧 진행중 |
| [organization-signup](./organization-signup/) | 기관 회원가입 리팩토링 (기존 기관 선택, 승인/반려 워크플로우) | 🚀 배포됨 |
| [review](./review/) | 후기 작성, 수정, 삭제, 수료증 인증, 관리자 승인 | 🚧 진행중 |
| [survey](./survey/) | 사용자 설문조사 (LLM 추천용 데이터 수집) | ✅ 완료 |
| [data-migration](./data-migration/) | 초기 데이터 구축 및 마이그레이션 (CSV to SQL) | 🚧 진행중 |
| [lecture](./lecture/) | 강의 관리 (등록, 수정, 검색) | 📝 예정 |
| [compare](./compare/) | 강의 비교 기능 | 📝 예정 |
| [wishlist](./wishlist/) | 찜 목록 관리 | 📝 예정 |
| [mypage](./mypage/) | 마이페이지 (프로필, 수강 내역) | 📝 예정 |
| [admin](./admin/) | 관리자 기능 (회원 관리, 승인 관리) | 🚧 진행중 |

### 상태 범례
- 📝 예정: 문서 작성 예정
- 🚧 진행중: 문서 작성 중
- ✅ 완료: 문서 작성 완료
- 🚀 배포됨: 기능 구현 및 배포 완료
