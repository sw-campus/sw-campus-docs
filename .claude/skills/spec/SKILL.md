---
name: spec
description: PRD와 시퀀스 다이어그램을 기반으로 spec.md 기술 명세를 생성합니다. API 설계, DB 스키마, 에러 코드를 포함한 설계 문서를 작성합니다. 시퀀스 다이어그램 완료 후 사용하세요.
---

# Spec Skill

PRD와 시퀀스 다이어그램을 분석하여 기술 명세(spec.md)를 자동 생성합니다.

## 사용법

```
/spec {feature-name}
```

**예시**:
```
/spec lecture-registration
/spec payment
```

feature-name을 생략하면 현재 작업 중인 feature를 자동 감지합니다.

## 실행 단계

1. **문서 읽기**:
   - `features/{feature-name}/prd.md` 읽기
   - `features/{feature-name}/sequence/*.md` 읽기
2. **설계 분석**: 기능 요구사항과 시퀀스를 기반으로 API/DB 설계
3. **spec.md 생성**: 기술 명세 문서 생성
4. **README 업데이트**: `features/README.md` 상태를 🚧 진행중으로 변경
5. **결과 안내**: 생성된 파일과 다음 단계 안내

## 생성 파일

```
features/{feature-name}/spec.md
```

## spec.md 구조

[SPEC_TEMPLATE.md](./SPEC_TEMPLATE.md) 참조

## 설계 규칙

### API 설계
- RESTful 원칙 준수
- 기존 API 패턴 참조 (`/api/v1/...`)
- 인증 필요 여부 명시

### DB 스키마
- 기존 테이블과의 관계 고려
- PostgreSQL 타입 사용
- 인덱스 필요 여부 검토

### 에러 코드
- 도메인별 prefix 사용 (AUTH, REVIEW, LECTURE 등)
- HTTP 상태 코드 매핑

## 다음 단계 안내

생성 완료 후 사용자에게 다음을 안내합니다:

```
✅ spec.md 생성 완료

생성된 파일:
- features/{feature-name}/spec.md

다음 단계:
1. spec.md 검토 및 수정
2. /implement 실행하여 구현 시작
```

## 주의사항

- PRD와 sequence가 없으면 에러 반환
- 기존 spec.md가 있으면 덮어쓸지 확인
- 기존 코드베이스의 패턴을 참조하여 일관성 유지
