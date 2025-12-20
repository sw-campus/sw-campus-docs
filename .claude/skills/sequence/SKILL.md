---
name: sequence
description: PRD를 기반으로 시퀀스 다이어그램을 생성합니다. features/{feature}/prd.md를 읽고 sequence/ 폴더에 description.md와 diagram.md를 생성합니다. PRD 작성 완료 후 사용하세요.
---

# Sequence Skill

PRD를 분석하여 시퀀스 다이어그램 문서를 자동 생성합니다.

## 사용법

```
/sequence {feature-name}
```

**예시**:
```
/sequence lecture-registration
/sequence payment
```

feature-name을 생략하면 현재 작업 중인 feature를 자동 감지합니다.

## 실행 단계

1. **PRD 읽기**: `features/{feature-name}/prd.md` 파일 읽기
2. **흐름 분석**: PRD의 사용자 스토리와 기능 요구사항 분석
3. **폴더 생성**: `features/{feature-name}/sequence/` 디렉토리 생성
4. **다이어그램 생성**: 주요 흐름별로 description.md와 diagram.md 생성
5. **결과 안내**: 생성된 파일과 다음 단계 안내

## 생성 파일 구조

```
features/{feature-name}/sequence/
├── {flow1}_description.md    # 흐름 설명
├── {flow1}_diagram.md        # Mermaid 시퀀스 다이어그램
├── {flow2}_description.md
└── {flow2}_diagram.md
```

## 다이어그램 작성 규칙

### Actors (참여자)
- **Client**: 프론트엔드 (브라우저/앱)
- **Server**: 백엔드 API 서버
- **DB**: 데이터베이스
- **External**: 외부 서비스 (OAuth, S3, OCR 등)

### Mermaid 시퀀스 다이어그램 형식

[SEQUENCE_TEMPLATE.md](./SEQUENCE_TEMPLATE.md) 참조

## 다음 단계 안내

생성 완료 후 사용자에게 다음을 안내합니다:

```
✅ Sequence diagrams 생성 완료

생성된 파일:
- features/{feature-name}/sequence/{flow}_description.md
- features/{feature-name}/sequence/{flow}_diagram.md

다음 단계:
1. 시퀀스 다이어그램 검토 및 수정
2. /spec 실행하여 기술 명세 생성
```

## 주의사항

- PRD가 없으면 에러 반환
- 기존 sequence/ 폴더가 있으면 덮어쓸지 확인
- 복잡한 기능은 여러 개의 시퀀스로 분리 (예: 사용자 흐름, 관리자 흐름)
