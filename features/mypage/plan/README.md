# 마이페이지 (Mypage) - Implementation Plan Overview

> Backend API 구현 계획 개요

## 문서 정보

| 항목 | 내용 |
|------|------|
| 작성일 | 2025-12-15 |
| 상태 | Draft |
| 버전 | 0.2 |
| 관련 문서 | [PRD](../prd.md), [Tech Spec](../tech-spec.md) |

---

## 1. 개요

본 문서는 마이페이지 기능의 백엔드 API 구현을 위한 전체 계획을 조망합니다. 상세한 마일스톤별 계획은 하위 문서를 참조하십시오.

## 2. 구현 원칙

1.  **Role 기반 접근 제어**: `USER`와 `ORGANIZATION`의 권한을 철저히 분리하여 구현합니다.
2.  **확장성 고려**: 특히 기관 정보 수정(Organization Update) 기능은 추후 관리자 승인 프로세스 도입 등 고도화를 대비하여 유연한 구조로 설계합니다.
3.  **기존 로직 재사용**: 인증, 파일 업로드 등 공통 기능은 기존 모듈을 최대한 활용합니다.

## 3. 마일스톤 (Milestones)

전체 구현은 3개의 Phase로 진행됩니다.

| Phase | 주제 | 주요 목표 | 예상 기간 | 상세 문서 |
|:---:|---|---|:---:|:---:|
| **1** | **기본 구조 및 DTO** | API 명세에 따른 DTO 및 Controller 스켈레톤 구현 | 1일 | [Phase 1](./phase01-structure.md) |
| **2** | **도메인 로직 강화** | Service 계층의 비즈니스 로직(상태 변경, Upsert 등) 구현 | 2일 | [Phase 2](./phase02-domain.md) |
| **3** | **통합 및 테스트** | Controller-Service 연결 및 단위/통합 테스트 수행 | 1일 | [Phase 3](./phase03-integration.md) |

## 4. 리스크 및 대응 방안

| 리스크 | 대응 방안 |
|---|---|
| **기존 API 영향** | `ReviewService`와 `LectureService` 수정 시 기존 테스트가 깨질 수 있음. 수정 후 기존 테스트(`ReviewServiceTest`, `LectureServiceTest`)를 반드시 실행하여 회귀 테스트 수행. |
| **Multipart 요청 처리** | `PATCH` 메서드에서 `multipart/form-data` 지원 여부 확인 필요. Spring Boot 버전에 따라 설정이 필요할 수 있음. 문제 발생 시 `POST`로 변경 고려. |
| **동시성 이슈** | 설문조사 Upsert 시 동시에 요청이 들어오면 중복 생성될 수 있음. DB 레벨에서 `member_id`에 Unique Constraint가 걸려있는지 확인 필요. |
