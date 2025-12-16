# Features Documentation v1.0

기능별 문서를 관리하는 폴더입니다.

---

## 폴더 구조

### 기본 구조 (단일 파일)

```
features/
├── README.md                    # 이 파일 (가이드 및 기능 목록)
│
├── {feature-name}/              # 기능별 폴더
│   ├── prd.md                   # Product Requirements Document (항상 단일 파일)
│   ├── tech-spec.md             # Technical Specification
│   ├── plan.md                  # Development Plan
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
    ├── tech-spec/               # Tech Spec 폴더로 확장
    │   ├── README.md            # Tech Spec 개요 및 목차
    │   ├── api.md               # API 설계
    │   ├── database.md          # DB 스키마
    │   ├── security.md          # 보안 설계
    │   └── error-codes.md       # 에러 코드 정의
    │
    ├── plan/                    # Plan 폴더로 확장
    │   ├── README.md            # 전체 계획 개요
    │   ├── milestone-1.md       # 마일스톤별 상세 계획
    │   ├── milestone-2.md
    │   └── milestone-3.md
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
| 소규모 기능, 단순한 설계 | 단일 파일 (`tech-spec.md`, `plan.md`, `report.md`) |
| 대규모 기능, 복잡한 설계 | 폴더 확장 (`tech-spec/`, `plan/`, `report/`) |
| 여러 마일스톤으로 나뉘는 경우 | `plan/`, `report/` 폴더 확장 |
| API, DB, 보안 등 영역이 많은 경우 | `tech-spec/` 폴더 확장 |

---

## 문서 작성 순서

각 기능은 아래 순서로 문서를 작성합니다:

| 순서 | 문서 | 설명 |
|:----:|------|------|
| 1 | `prd.md` | **Product Requirements Document** - 비즈니스 요구사항, 사용자 스토리, 기능 범위 정의 |
| 2 | `tech-spec.md` | **Technical Specification** - API 설계, DB 스키마, 시퀀스 다이어그램, 에러 코드 |
| 3 | `plan.md` | **Development Plan** - 마일스톤, 태스크 분해, 일정 계획 |
| 4 | `report.md` | **Implementation Report** - 구현 결과, 테스트 결과, 변경 사항, 배포 정보 |

---

## 문서별 역할

### PRD (prd.md)
- **"무엇을(What)"** 만들 것인가
- 비즈니스 배경 및 목적
- 사용자 스토리
- 기능/비기능 요구사항
- 범위(Scope) 정의

### Tech Spec (tech-spec.md)
- **"어떻게(How)"** 만들 것인가
- API 엔드포인트 설계
- 데이터베이스 스키마
- 시퀀스 다이어그램
- 에러 코드 정의
- 보안 고려사항

### Plan (plan.md)
- **"언제(When)"** 만들 것인가
- 마일스톤 정의
- 태스크 분해
- 의존성 관리
- 리스크 식별

### Report (report.md)
- **"결과(Result)"** 보고
- 구현 현황
- 테스트 결과
- Tech Spec 대비 변경 사항
- 배포 정보

---

## 기능 목록

| 기능 | 설명 | 상태 |
|------|------|------|
| [auth](./auth/) | 회원가입, 로그인, 로그아웃, 토큰 관리 | 🚧 진행중 |
| [review](./review/) | 후기 작성, 수정, 삭제, 수료증 인증, 관리자 승인 | 🚧 진행중 |
| [survey](./survey/) | 사용자 설문조사 (LLM 추천용 데이터 수집) | ✅ 완료 |
| [data-migration](./data-migration/) | 초기 데이터 구축 및 마이그레이션 (CSV to SQL) | 🚧 진행중 |

### 상태 범례
- 📝 예정: 문서 작성 예정
- 🚧 진행중: 문서 작성 중
- ✅ 완료: 문서 작성 완료
- 🚀 배포됨: 기능 구현 및 배포 완료
