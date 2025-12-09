# 01. 프로젝트 구조

> Next.js App Router + Feature-Sliced Architecture 기반 디렉토리 구조

---

## 📁 전체 구조

```
sw-campus-client/
├── src/
│   ├── app/                    # App Router (페이지, 레이아웃)
│   │   ├── globals.css         # 전역 스타일
│   │   ├── layout.tsx          # 루트 레이아웃
│   │   └── page.tsx            # 홈 페이지
│   ├── components/
│   │   ├── layout/             # 전역 레이아웃 (Header, Footer)
│   │   └── ui/                 # shadcn/ui 기반 UI 컴포넌트
│   ├── features/               # 도메인별 기능 (Feature-Sliced)
│   │   └── {domain}/
│   │       ├── components/     # 도메인 UI 컴포넌트
│   │       ├── hooks/          # 도메인 훅 (API, 로직)
│   │       ├── types/          # 도메인 타입
│   │       └── index.ts        # Public API
│   ├── hooks/                  # 공용 Custom Hooks
│   ├── lib/                    # 유틸리티
│   │   ├── axios.ts            # Axios 인스턴스
│   │   ├── env.ts              # 환경변수
│   │   └── utils.ts            # 공통 유틸 함수
│   ├── providers/              # 전역 Provider
│   │   └── query-client-provider.tsx
│   └── store/                  # Zustand 스토어
│       └── {domain}.store.ts
└── ...
```

---

## 📂 레이어별 설명

### 1. App Layer (`src/app/`)

Next.js App Router 기반 페이지 및 레이아웃

```
src/app/
├── globals.css         # 전역 스타일 (TailwindCSS)
├── layout.tsx          # 루트 레이아웃
├── page.tsx            # 홈 페이지
├── {route}/
│   ├── page.tsx        # 라우트 페이지
│   └── layout.tsx      # 라우트 레이아웃 (선택)
└── ...
```

**규칙:**
- ✅ 서버 컴포넌트가 기본
- ✅ 필요 시 `"use client"` 선언
- ❌ 비즈니스 로직/데이터 패칭 금지 (Layout에서)

---

### 2. Components Layer (`src/components/`)

#### 2.1 Layout 컴포넌트

```
src/components/layout/
├── Header.tsx
└── Footer.tsx
```

**규칙:**
- ✅ 전역 공용 레이아웃 컴포넌트
- ✅ 순수 UI만 담당
- ❌ 도메인 로직 금지

#### 2.2 UI 컴포넌트

```
src/components/ui/
├── button.tsx
├── input.tsx
├── card.tsx
└── ...
```

**규칙:**
- ✅ shadcn/ui 기반
- ✅ 재사용 가능한 UI-only 레이어
- ❌ 비즈니스 로직 금지

---

### 3. Features Layer (`src/features/`)

도메인 단위(Feature-Sliced)로 강하게 분리

```
src/features/cart/
├── components/         # Cart UI 컴포넌트
│   ├── CartList.tsx
│   └── CartItem.tsx
├── hooks/              # Cart 관련 훅
│   ├── useCartQuery.ts
│   └── useAddToCart.ts
├── types/              # Cart 타입 정의
│   └── index.ts
└── index.ts            # Public API (export)
```

**규칙:**
- ✅ 도메인 로직은 해당 feature 폴더 내에만 위치
- ✅ `index.ts`를 통한 Public API 노출
- ✅ 공용 로직 발생 시 `hooks/` 또는 `lib/`로 승격
- ❌ feature 간 직접 import 지양

**index.ts 예시:**
```typescript
// src/features/cart/index.ts
export { useCartQuery } from './hooks/useCartQuery';
export { useAddToCart } from './hooks/useAddToCart';
export { CartList } from './components/CartList';
export type { CartItem, CartState } from './types';
```

---

### 4. Shared Layer

#### 4.1 Hooks (`src/hooks/`)

```
src/hooks/
├── useDebounce.ts
├── useBoolean.ts
└── useLocalStorage.ts
```

**규칙:**
- ✅ 특정 도메인에 속하지 않는 공용 훅만 위치
- ❌ 도메인 특화 훅은 `features/{domain}/hooks/`에 위치

#### 4.2 Lib (`src/lib/`)

```
src/lib/
├── axios.ts            # Axios 인스턴스, 인터셉터
├── env.ts              # 환경변수 로딩
└── utils.ts            # 공통 유틸 함수
```

**규칙:**
- ✅ API 호출은 `axios.ts` 인스턴스 사용
- ✅ 환경변수는 `NEXT_PUBLIC_` prefix 활용
- ✅ utils는 Pure function만 존재

#### 4.3 Providers (`src/providers/`)

```
src/providers/
└── query-client-provider.tsx
```

**규칙:**
- ✅ TanStack Query Client 주입
- ✅ 전역 에러핸들링/리트라이 정책 정의

#### 4.4 Store (`src/store/`)

```
src/store/
├── cart.store.ts
└── ui.store.ts
```

**규칙:**
- ✅ 전역 공유가 필요한 UI 상태만 처리
- ✅ localStorage persist 가능
- ❌ 서버 상태(API 응답) 저장 금지
- ❌ 과도한 비즈니스 로직 금지

---

## 📋 파일 위치 결정 가이드

| 파일 유형 | 위치 |
|----------|------|
| 페이지 컴포넌트 | `app/{route}/page.tsx` |
| 레이아웃 | `app/{route}/layout.tsx` |
| 전역 레이아웃 (Header/Footer) | `components/layout/` |
| 재사용 UI 컴포넌트 | `components/ui/` |
| 도메인 컴포넌트 | `features/{domain}/components/` |
| 도메인 훅 (API 호출) | `features/{domain}/hooks/` |
| 도메인 타입 | `features/{domain}/types/` |
| 공용 훅 | `hooks/` |
| 유틸리티 함수 | `lib/utils.ts` |
| Axios 설정 | `lib/axios.ts` |
| Zustand 스토어 | `store/` |
| 전역 Provider | `providers/` |
