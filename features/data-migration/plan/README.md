# Development Plan: 초기 데이터 구축 및 마이그레이션

## 개요
- **목표**: `tech-spec.md`에 정의된 명세에 따라 레거시 CSV 데이터를 PostgreSQL 데이터베이스로 안전하게 이관한다.
- **전략**: Python 스크립트를 사용하여 데이터를 전처리 및 정규화하고, Flyway 호환 SQL 파일을 생성하여 배포한다.
- **일정**: 3일 (Milestone 당 1일 예상)

## 마일스톤 요약

| ID | 단계 | 설명 | 상태 |
|:--:|:---|:---|:--:|
| **P1** | [환경 구성 및 마스터 데이터 구축](./phase01.md) | Python 환경 설정, Admin/Category/Org/Teacher 등 기초 데이터 생성 | 📝 예정 |
| **P2** | [강좌 및 관계 데이터 구축](./phase02.md) | Lecture 메인 테이블 및 1:N 관계(Step, Qual, Add) 데이터 생성 | 📝 예정 |
| **P3** | [검증 및 최종화](./phase03.md) | 로컬 DB 적재 테스트, 데이터 정합성 검증, PR 작성 | 📝 예정 |

## 의존성 및 리스크
- **의존성**: `sw-campus-infra` 모듈의 DB 스키마(`V1__init_schema.sql`)가 확정되어 있어야 함 (완료됨).
- **리스크**: CSV 데이터의 예외 케이스(인코딩, 포맷 불일치) 발생 가능성 → 방어 로직(`try-except`, 로깅) 필수.
