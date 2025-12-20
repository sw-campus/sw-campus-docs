---
name: implement
description: spec.md를 기반으로 구현을 시작합니다. Plan 모드로 진입하여 구현 계획을 수립하고 코드를 작성합니다. spec.md 검토 완료 후 사용하세요.
---

# Implement Skill

spec.md를 분석하여 구현 계획을 수립하고 코드를 작성합니다.

## 사용법

```
/implement {feature-name}
```

**예시**:
```
/implement lecture-registration
/implement payment
```

feature-name을 생략하면 현재 작업 중인 feature를 자동 감지합니다.

## 실행 단계

1. **문서 읽기**:
   - `features/{feature-name}/spec.md` 읽기
   - `features/{feature-name}/prd.md` 읽기 (컨텍스트)
   - `features/{feature-name}/sequence/*.md` 읽기 (흐름 파악)

2. **코드베이스 분석**:
   - 기존 코드 패턴 파악
   - 관련 파일 위치 확인
   - 의존성 분석

3. **Plan 모드 진입**:
   - 구현 계획 수립
   - 파일별 변경사항 정리
   - 사용자 승인 요청

4. **구현 실행**:
   - 계획에 따라 코드 작성
   - 테스트 코드 작성 (필요시)
   - 빌드/테스트 실행

5. **결과 안내**: 구현 완료 후 다음 단계 안내

## 구현 순서 가이드

### Spring Boot (sw-campus-server)

```
1. Domain 모듈 (sw-campus-domain)
   - Domain POJO 생성/수정
   - Repository 인터페이스 정의
   - Service 로직 구현
   - Exception 클래스 추가

2. Infra 모듈 (sw-campus-infra/db-postgres)
   - Entity 생성/수정
   - JpaRepository 구현
   - EntityRepository 구현

3. API 모듈 (sw-campus-api)
   - Request/Response DTO 생성
   - Controller 구현
   - Swagger 문서화

4. 마이그레이션 (필요시)
   - Flyway SQL 파일 추가
```

### Next.js (sw-campus-client)

```
1. Types 정의
   - features/{domain}/types/

2. API 함수
   - features/{domain}/api/

3. Hooks
   - features/{domain}/hooks/

4. Components
   - features/{domain}/components/

5. Pages
   - app/{route}/page.tsx
```

## 다음 단계 안내

구현 완료 후 사용자에게 다음을 안내합니다:

```
✅ 구현 완료

변경된 파일:
- {file1}
- {file2}
- ...

다음 단계:
1. 로컬 테스트 실행
2. PR 생성
3. /done {PR번호} 실행하여 문서 업데이트
```

## 주의사항

- spec.md가 없으면 에러 반환
- 기존 코드 패턴과 일관성 유지
- CLAUDE.md의 코드 규칙 준수
- 테스트 실패 시 수정 후 재실행
