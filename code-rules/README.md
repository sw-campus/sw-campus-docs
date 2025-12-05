# SW Campus Server - Code Rules

> 이 문서는 SW Campus Server 프로젝트의 코드 규칙을 정의합니다.  
> 모든 팀원은 이 규칙을 **준수**해야 합니다.

---

## 🎯 목적

1. **코드 품질 유지** - 일관된 코드 스타일로 가독성 향상
2. **아키텍처 일관성** - Multi Module + Layer Architecture 원칙 준수
3. **온보딩 효율화** - 신규 팀원이 빠르게 프로젝트에 적응

---

## 📚 문서 목록

| 번호 | 문서 | 설명 |
|:----:| ---- | ---- |
| 01 | [모듈 구조](./01-module-structure.md) | api, domain, infra, shared 모듈 역할 및 패키지 구조 |
| 02 | [네이밍 컨벤션](./02-naming-convention.md) | 클래스, 메서드, 변수 네이밍 규칙 |
| 03 | [의존성 규칙](./03-dependency-rules.md) | 모듈 간 의존성 방향 및 build.gradle 설정 |
| 04 | [API 설계](./04-api-design.md) | REST API URL, HTTP Method, Status Code 규칙 |
| 05 | [예외 처리](./05-exception-handling.md) | 예외 계층 구조, 에러 코드, 전역 핸들러 |
| 06 | [설계 원칙](./06-design-principles.md) | YAGNI, 중복 허용, 예광탄, 테스트 전략 |

---

## ⚠️ 규칙 준수

- 코드 리뷰에서 체크
- 위반 시 수정 후 머지

---

## 🤖 AI 협업

AI와 협업 시 [00-index.md](./00-index.md)를 컨텍스트로 제공하면,  
AI가 작업에 필요한 규칙 문서를 스스로 참조합니다.

---

## 📅 버전 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0.0 | 2025-12-01 | 최초 작성 |
| 1.1.0 | 2025-12-05 | 설계 원칙 추가, AI 협업용 인덱스 추가 |
