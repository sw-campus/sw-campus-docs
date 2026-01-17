# Code Rules Index

> **AI 협업용 핵심 규칙 문서**
> 이 문서를 컨텍스트로 제공하면 AI가 프로젝트 규칙을 준수하며 코드를 작성합니다.

---

## 핵심 철학

> **이 원칙들은 모든 코드 작성의 기반입니다. 항상 기억하세요.**

### 1. YAGNI (You Aren't Gonna Need It)
```
❌ "나중에 쓸 것 같아서" 미리 만든 코드
❌ "확장성을 위해" 미리 추가한 추상화
✅ 현재 요구사항에 필요한 코드만 작성
✅ 실제로 필요해지면 그때 추가
```

### 2. 잘못된 추상화보다 중복이 낫다
```
레이어 경계의 중복 = 허용 (api/domain/infra 각각의 DTO)
모듈 경계의 중복 = 허용
동일 모듈 내 중복 = 3번째 발생 시 리팩토링
```

### 3. 예광탄 개발
```
새 기능 → 핵심 유스케이스 하나 선택
         → 전체 레이어 관통 구현 (Controller → Service → Repository)
         → 동작 확인 후 나머지 확장
```

### 4. 깨진 창문 금지
```
❌ 주석 처리된 코드 방치
❌ TODO 없는 임시 코드
❌ 네이밍 컨벤션 위반
❌ 사용하지 않는 import, 변수
✅ 발견 즉시 수정 또는 이슈 등록
```

### 5. 우연에 맡기는 프로그래밍 금지
```
❌ "일단 돌아가니까 커밋"
❌ "이유는 모르겠지만 이렇게 하면 됨"
✅ 왜 동작하는지 설명할 수 있어야 함
✅ 복붙 코드는 반드시 이해 후 사용
```

---

## Server (Spring Boot) 핵심 규칙

### 아키텍처: Multi Module + Layer

```
의존성 방향: api → domain ← infra

sw-campus-server/
├── sw-campus-api/        # Controller, Request/Response DTO
├── sw-campus-domain/     # Service, Repository 인터페이스, Domain POJO
├── sw-campus-infra/      # JPA Entity, Repository 구현체
│   ├── analytics/        # 통계/분석
│   ├── db-postgres/      # PostgreSQL (JPA)
│   ├── db-redis/         # Redis
│   ├── oauth/            # OAuth 클라이언트
│   ├── ocr/              # OCR 클라이언트
│   └── s3/               # AWS S3
└── sw-campus-shared/     # 공통 (Logging, ErrorCode)
```

**절대 위반 금지:**
| 규칙 | 이유 |
|------|------|
| api에서 infra 직접 import 금지 | runtimeOnly 의존, 컴파일 에러 발생해야 함 |
| domain에서 api/infra 의존 금지 | domain은 순수해야 함 |
| infra에서 api 의존 금지 | 순환 의존성 위험 |
| Controller에 비즈니스 로직 금지 | Service로 위임 |

### 네이밍 컨벤션

| 위치 | 패턴 | 예시 |
|------|------|------|
| Controller | `{Domain}Controller` | `UserController` |
| Service | `{Domain}Service` | `UserService` |
| Repository (interface) | `{Domain}Repository` | `UserRepository` |
| Repository (impl) | `{Domain}EntityRepository` | `UserEntityRepository` |
| Entity | `{Domain}Entity` | `UserEntity` |
| Request DTO | `{Action}{Domain}Request` | `CreateUserRequest` |
| Response DTO | `{Domain}Response` | `UserResponse` |
| Exception | `{Domain}{Reason}Exception` | `UserNotFoundException` |

### REST API 설계

```
URL: 소문자, 복수형, 케밥케이스
예: /api/v1/users, /api/v1/user-profiles

GET    → 조회 (200)
POST   → 생성 (201)
PUT    → 전체 수정 (200)
PATCH  → 부분 수정 (200)
DELETE → 삭제 (204)
```

### Swagger 필수 규칙

```java
// ⚠️ Multipart 파일 업로드 시 @ModelAttribute 금지!
// ✅ @RequestPart로 각 필드 분리 필수
@PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public ResponseEntity<Response> upload(
    @RequestPart("name") String name,
    @RequestPart("file") MultipartFile file
) { }
```

### 테스트 전략

| 레이어 | 테스트 | 수준 |
|--------|--------|------|
| **Domain** | ✅ 필수 (TDD 권장) | 단위 테스트 |
| API | 선택적 | 통합 테스트 |
| Infra | 선택적 | 통합 테스트 |

### 상세 문서 참조

| 문서 | 참조 시점 |
|------|----------|
| `server/01-module-structure.md` | 새 파일/클래스 생성 |
| `server/02-naming-convention.md` | 네이밍 결정 |
| `server/03-dependency-rules.md` | build.gradle 수정 |
| `server/04-api-design.md` | REST API 설계 |
| `server/05-exception-handling.md` | 예외 처리 |
| `server/06-design-principles.md` | 설계 결정, 코드 리뷰 |
| `server/07-swagger-documentation.md` | API 문서화, 파일 업로드 |
| `server/08-security.md` | 인증/인가, 입력 검증, 에러 처리 |

---

## Front (Next.js) 핵심 규칙

### 아키텍처: App Router + Feature-Sliced

```
sw-campus-client/src/
├── app/                  # 페이지, 레이아웃 (App Router)
├── components/
│   ├── layout/           # Header, Footer
│   ├── providers/        # QueryClientProvider
│   └── ui/               # shadcn/ui 컴포넌트
├── features/{domain}/    # 도메인별 기능
│   ├── api/              # API 함수
│   ├── components/       # 도메인 컴포넌트
│   ├── hooks/            # 도메인 훅
│   ├── types/            # 타입 정의
│   └── index.ts          # Public API
├── hooks/                # 공용 훅
├── lib/                  # axios, env, utils
├── store/                # Zustand 스토어
└── types/                # 공용 타입 정의
```

### 컴포넌트 규칙

```typescript
// 서버 컴포넌트가 기본 (기본값)
export function StaticCard({ title }: Props) {
  return <div>{title}</div>;
}

// 클라이언트 컴포넌트가 필요할 때만 선언
"use client";
import { useState } from 'react';

export function Counter() {
  const [count, setCount] = useState(0);
  // ...
}
```

**"use client" 필요한 경우:**
- useState, useEffect 사용
- onClick, onChange 등 이벤트 핸들러
- 브라우저 API (window, document)

### 상태 관리 분리

| 상태 유형 | 도구 | 예시 |
|----------|------|------|
| **서버 상태** | TanStack Query | API 응답, 캐시 데이터 |
| **클라이언트 상태** | Zustand | UI 상태, 모달, 장바구니 |

```typescript
// ❌ 서버 데이터를 Zustand에 저장 금지
const useStore = create((set) => ({
  users: [],  // API 응답은 TanStack Query로!
}));

// ✅ 서버 상태는 TanStack Query
const { data: users } = useQuery({
  queryKey: ['users'],
  queryFn: () => api.get('/users').then(res => res.data),
});
```

### API 통신 규칙

```typescript
// ✅ 반드시 api 인스턴스 사용
import { api } from '@/lib/axios';
const { data } = await api.get('/users');

// ❌ axios 직접 import 금지
import axios from 'axios';

// ❌ fetch() 사용 금지 (쿠키 인증 누락 위험)
const response = await fetch('/api/users');
```

**에러 처리:**
- 에러 toast는 인터셉터에서만 처리
- 컴포넌트에서 에러 toast 중복 호출 금지

### 스타일링 규칙

```tsx
// ✅ 디자인 토큰 사용
<div className="bg-background text-foreground">
<div className="rounded-md border border-border">

// ❌ 하드코딩 금지
<div className="bg-[#fff3e0]">
<div className="rounded-[8px]">
```

### 성능 최적화 규칙

```typescript
// ✅ Promise.all()로 병렬 실행 (Waterfall 제거)
const [lecture, reviews] = await Promise.all([
  fetchLecture(id),
  fetchReviews(id),
]);

// ✅ Dynamic import로 무거운 컴포넌트 lazy-load
const MonacoEditor = dynamic(() => import('./MonacoEditor'), { ssr: false });

// ✅ 함수형 setState (stale closure 방지)
setItems(prev => [...prev, newItem]);

// ✅ Primitive 의존성 사용
useEffect(() => { ... }, [userId]);  // user 객체 대신 userId
```

**핵심 규칙:**
- 독립적인 API 호출 → `Promise.all()`
- 무거운 컴포넌트 → `next/dynamic`
- setState에서 이전 상태 참조 → 함수형 업데이트
- useEffect 의존성 → primitive 값 사용

### 상세 문서 참조

| 문서 | 참조 시점 |
|------|----------|
| `front/01-project-structure.md` | 파일 위치 결정 |
| `front/02-component-rules.md` | 컴포넌트 작성 |
| `front/03-state-management.md` | 상태 관리 결정 |
| `front/04-api-communication.md` | API 호출 |
| `front/05-styling-rules.md` | 스타일링 |
| `front/06-eslint-rules.md` | 코드 품질 |
| `front/07-performance-optimization.md` | 성능 최적화 |
| `front/08-security.md` | 토큰 저장, 보안 헤더, 입력 검증 |

---

## 작업별 빠른 참조

### Server 작업

| 작업 | 참조 문서 |
|------|----------|
| 새 도메인 추가 | 01, 02, 03 |
| Controller 작성 | 01, 02, 04, 07 |
| Service 작성 | 01, 02, 06 |
| Repository 작성 | 01, 02, 03 |
| 파일 업로드 API | 04, 07 ⚠️ |
| 예외 처리 | 02, 05 |

### Front 작업

| 작업 | 참조 문서 |
|------|----------|
| 새 페이지 추가 | 01, 02 |
| 새 feature 추가 | 01, 02, 03 |
| API 연동 | 03, 04, 07 |
| 상태 관리 | 03, 07 |
| 스타일링 | 05 |
| 성능 최적화 | 07 |
| 무거운 컴포넌트 추가 | 02, 07 |

---

## AI 지시사항

> **코드 작성 시 반드시 준수할 규칙**

### 1. 코드 작성 전 확인
- [ ] 이 작업에 해당하는 규칙 문서를 읽었는가?
- [ ] 현재 필요한 코드만 작성하는가? (YAGNI)
- [ ] 기존 패턴을 따르고 있는가?

### 2. Server 코드 작성 시
- [ ] Controller는 api 모듈에만
- [ ] Entity는 infra 모듈에만
- [ ] Domain은 순수하게 유지 (외부 의존 없음)
- [ ] 네이밍 컨벤션 준수
- [ ] Multipart API는 @RequestPart 사용

### 3. Front 코드 작성 시
- [ ] "use client"가 정말 필요한가?
- [ ] 서버 상태 → TanStack Query
- [ ] UI 상태 → Zustand
- [ ] api 인스턴스 사용 (axios 직접 import 금지)
- [ ] 디자인 토큰 사용 (하드코딩 금지)
- [ ] 독립적인 API 호출은 Promise.all() 사용
- [ ] 무거운 컴포넌트는 next/dynamic 사용
- [ ] setState에서 이전 상태 참조 시 함수형 업데이트

### 4. 코드 작성 후 확인
- [ ] 깨진 창문이 없는가? (TODO, 주석 코드, 미사용 변수)
- [ ] 왜 동작하는지 설명할 수 있는가?
- [ ] 테스트가 필요한 부분인가? (Domain 레이어)

---

## 규칙 위반 시

규칙을 위반하는 코드를 발견하면:
1. 즉시 수정하거나
2. 수정이 어려우면 이슈로 등록 (`tech-debt` 라벨)
3. TODO 작성 시 기한과 이슈 번호 명시

```java
// ✅ 좋은 TODO
// TODO(2025-01-15): 성능 개선 필요 - #123 이슈 참고

// ❌ 나쁜 TODO
// TODO: 나중에 고치기
```
