# 07. 성능 최적화

> React/Next.js 애플리케이션 성능 최적화 규칙 (Vercel Best Practices 기반)

---

## 1. Waterfall 제거 (CRITICAL)

### 1.1 Promise.all()로 병렬 실행

독립적인 async 작업은 순차 실행하지 말고 **병렬로 실행**합니다.

```typescript
// ❌ 잘못된 예: 순차 실행 (Waterfall)
export async function getLectureDetail(id: number) {
  const lecture = await axiosInstance.get(`/lectures/${id}`);
  const reviews = await axiosInstance.get(`/lectures/${id}/reviews`);
  const instructor = await axiosInstance.get(`/lectures/${id}/instructor`);
  // 총 소요시간: A + B + C (3번의 네트워크 왕복)
  return { lecture, reviews, instructor };
}

// ✅ 올바른 예: 병렬 실행
export async function getLectureDetail(id: number) {
  const [lecture, reviews, instructor] = await Promise.all([
    axiosInstance.get(`/lectures/${id}`),
    axiosInstance.get(`/lectures/${id}/reviews`),
    axiosInstance.get(`/lectures/${id}/instructor`),
  ]);
  // 총 소요시간: max(A, B, C) (1번의 네트워크 왕복)
  return { lecture, reviews, instructor };
}
```

**성능 개선**: 2-10배 향상 가능

---

### 1.2 await 지연 (Defer Await)

결과가 필요한 시점까지 `await`를 미룹니다.

```typescript
// ❌ 잘못된 예: 불필요한 blocking
export async function getResource(id: string, userId: string) {
  const user = await fetchUser(userId);  // 여기서 기다림

  if (!id) {
    return { error: 'ID required' };  // user 데이터 불필요했음
  }

  const resource = await fetchResource(id);
  return { user, resource };
}

// ✅ 올바른 예: 필요한 시점에 await
export async function getResource(id: string, userId: string) {
  if (!id) {
    return { error: 'ID required' };  // 빠른 반환
  }

  // 둘 다 필요한 시점에 병렬 실행
  const [user, resource] = await Promise.all([
    fetchUser(userId),
    fetchResource(id),
  ]);

  return { user, resource };
}
```

**규칙:**
- ✅ 조건 체크를 먼저 수행
- ✅ early return 후 데이터 페칭
- ✅ 독립적인 페칭은 `Promise.all()` 사용

---

## 2. 번들 최적화 (CRITICAL)

### 2.1 Barrel Import 금지

Barrel file(`index.ts`)에서 import하면 사용하지 않는 모듈까지 로드됩니다.

```typescript
// ❌ 잘못된 예: Barrel import (전체 모듈 로드)
import { Check, X, Menu } from 'lucide-react';
// → 1,583개 모듈 로드, ~2.8초 추가

import { Button, TextField } from '@mui/material';
// → 2,225개 모듈 로드, ~4.2초 추가

// ✅ 올바른 예: 직접 경로 import
import Check from 'lucide-react/dist/esm/icons/check';
import X from 'lucide-react/dist/esm/icons/x';
import Menu from 'lucide-react/dist/esm/icons/menu';

import Button from '@mui/material/Button';
import TextField from '@mui/material/TextField';
```

**Next.js 13.5+ 설정** (권장):

```javascript
// next.config.js
const nextConfig = {
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      '@radix-ui/react-icons',
      'date-fns',
      'lodash',
    ],
  },
};
```

이 설정으로 barrel import를 사용해도 자동으로 직접 import로 변환됩니다.

**영향받는 라이브러리:**
- `lucide-react`
- `@radix-ui/react-*`
- `@mui/material`
- `lodash`
- `date-fns`

---

### 2.2 Dynamic Import (next/dynamic)

무거운 컴포넌트는 **lazy-load**합니다.

```typescript
// ❌ 잘못된 예: 정적 import (초기 번들에 포함)
import { MonacoEditor } from '@/features/editor/components/MonacoEditor';
import { PDFViewer } from '@/features/document/components/PDFViewer';
import { ChartComponent } from '@/features/analytics/components/Chart';

// ✅ 올바른 예: Dynamic import (필요 시 로드)
import dynamic from 'next/dynamic';

const MonacoEditor = dynamic(
  () => import('@/features/editor/components/MonacoEditor'),
  { ssr: false }  // 클라이언트에서만 로드
);

const PDFViewer = dynamic(
  () => import('@/features/document/components/PDFViewer'),
  {
    ssr: false,
    loading: () => <Skeleton className="h-[600px]" />
  }
);

const ChartComponent = dynamic(
  () => import('@/features/analytics/components/Chart'),
  { ssr: false }
);
```

**Dynamic import가 필요한 경우:**
| 컴포넌트 | 이유 |
|----------|------|
| 에디터 (Monaco, CodeMirror) | 번들 사이즈 큼 (300KB+) |
| PDF 뷰어 | 브라우저 API 필요, 사이즈 큼 |
| 차트 라이브러리 | D3, Chart.js 등 무거움 |
| 지도 (Google Maps, Kakao) | 외부 스크립트 의존 |
| 리치 텍스트 에디터 | Quill, TipTap 등 |

---

### 2.3 서드파티 라이브러리 지연 로드

Analytics, 로깅 등 **사용자 인터랙션을 차단하지 않는** 라이브러리는 hydration 후 로드합니다.

```typescript
// ❌ 잘못된 예: 정적 import (초기 번들에 포함)
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';

// ✅ 올바른 예: Dynamic import
import dynamic from 'next/dynamic';

const Analytics = dynamic(
  () => import('@vercel/analytics/react').then(m => m.Analytics),
  { ssr: false }
);

const SpeedInsights = dynamic(
  () => import('@vercel/speed-insights/next').then(m => m.SpeedInsights),
  { ssr: false }
);

// layout.tsx에서 사용
export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
```

**지연 로드 대상:**
- Analytics (Google Analytics, Vercel Analytics)
- Error tracking (Sentry)
- Chat widgets (Intercom, ChannelTalk)
- A/B testing tools

---

## 3. 서버 컴포넌트 성능 (HIGH)

### 3.1 컴포넌트 병렬 데이터 페칭

서버 컴포넌트 트리에서 **데이터 페칭을 병렬화**합니다.

```typescript
// ❌ 잘못된 예: 부모가 자식 페칭을 blocking
// app/lecture/[id]/page.tsx
export default async function LecturePage({ params }: Props) {
  const lecture = await fetchLecture(params.id);  // 먼저 완료되어야

  return (
    <div>
      <LectureHeader lecture={lecture} />
      <LectureReviews lectureId={params.id} />  {/* 그 다음 시작 */}
    </div>
  );
}

// ✅ 올바른 예: 독립 컴포넌트로 분리하여 병렬 실행
// app/lecture/[id]/page.tsx
export default function LecturePage({ params }: Props) {
  return (
    <div>
      <Suspense fallback={<HeaderSkeleton />}>
        <LectureHeader lectureId={params.id} />
      </Suspense>
      <Suspense fallback={<ReviewsSkeleton />}>
        <LectureReviews lectureId={params.id} />
      </Suspense>
    </div>
  );
}

// components/LectureHeader.tsx (서버 컴포넌트)
async function LectureHeader({ lectureId }: { lectureId: string }) {
  const lecture = await fetchLecture(lectureId);  // 독립적으로 실행
  return <header>{lecture.title}</header>;
}

// components/LectureReviews.tsx (서버 컴포넌트)
async function LectureReviews({ lectureId }: { lectureId: string }) {
  const reviews = await fetchReviews(lectureId);  // 독립적으로 실행
  return <section>{/* reviews */}</section>;
}
```

---

### 3.2 RSC 직렬화 최소화

서버→클라이언트 경계에서 **필요한 데이터만 전달**합니다.

```typescript
// ❌ 잘못된 예: 전체 객체 전달 (50개 필드)
// 서버 컴포넌트
async function UserPage() {
  const user = await fetchUser();  // 50개 필드
  return <UserProfile user={user} />;  // 전체 직렬화
}

// 클라이언트 컴포넌트
'use client';
function UserProfile({ user }: { user: User }) {
  return <div>{user.name}</div>;  // name만 사용
}

// ✅ 올바른 예: 필요한 필드만 전달
// 서버 컴포넌트
async function UserPage() {
  const user = await fetchUser();
  return (
    <UserProfile
      name={user.name}
      avatar={user.avatar}
    />
  );
}

// 클라이언트 컴포넌트
'use client';
function UserProfile({ name, avatar }: { name: string; avatar: string }) {
  return <div>{name}</div>;
}
```

**규칙:**
- ✅ 클라이언트 컴포넌트에 primitive props 전달
- ✅ 서버에서 데이터 가공 후 전달
- ❌ 전체 객체/배열 그대로 전달 금지

---

## 4. Suspense 경계 전략 (HIGH)

데이터 로딩을 기다리지 않고 **정적 UI를 먼저 표시**합니다.

```typescript
// ❌ 잘못된 예: 전체 페이지가 데이터 로딩 대기
export default async function LecturePage({ params }: Props) {
  const lecture = await fetchLecture(params.id);
  const reviews = await fetchReviews(params.id);

  return (
    <div>
      <Header />
      <LectureContent lecture={lecture} />
      <Reviews reviews={reviews} />
      <Footer />
    </div>
  );
}

// ✅ 올바른 예: Suspense로 점진적 로딩
import { Suspense } from 'react';

export default function LecturePage({ params }: Props) {
  return (
    <div>
      <Header />  {/* 즉시 표시 */}

      <Suspense fallback={<LectureContentSkeleton />}>
        <LectureContent lectureId={params.id} />
      </Suspense>

      <Suspense fallback={<ReviewsSkeleton />}>
        <Reviews lectureId={params.id} />
      </Suspense>

      <Footer />  {/* 즉시 표시 */}
    </div>
  );
}
```

**Suspense 배치 규칙:**
| 상황 | Suspense 사용 |
|------|--------------|
| 헤더, 푸터, 네비게이션 | ❌ 즉시 렌더 |
| 메인 콘텐츠 (데이터 의존) | ✅ Suspense 감싸기 |
| 사이드바 (데이터 의존) | ✅ Suspense 감싸기 |
| 댓글, 리뷰 섹션 | ✅ Suspense 감싸기 |

---

## 5. 리렌더 최적화 (HIGH)

### 5.1 함수형 setState 사용

setState에서 이전 상태를 참조할 때 **함수형 업데이트**를 사용합니다.

```typescript
// ❌ 잘못된 예: 직접 상태 참조 (stale closure 위험)
const [items, setItems] = useState<Item[]>([]);

const addItem = useCallback((newItem: Item) => {
  setItems([...items, newItem]);  // items가 오래된 값일 수 있음
}, [items]);  // items 변경 시 함수 재생성

const removeItem = useCallback((id: string) => {
  setItems(items.filter(item => item.id !== id));
}, [items]);

// ✅ 올바른 예: 함수형 업데이트
const [items, setItems] = useState<Item[]>([]);

const addItem = useCallback((newItem: Item) => {
  setItems(prev => [...prev, newItem]);  // 항상 최신 상태
}, []);  // 의존성 없음 - 안정적인 참조

const removeItem = useCallback((id: string) => {
  setItems(prev => prev.filter(item => item.id !== id));
}, []);
```

**장점:**
- 항상 최신 상태 값 사용
- 콜백 함수가 재생성되지 않음
- stale closure 버그 방지

---

### 5.2 Effect 의존성 최적화

객체 대신 **primitive 값**을 의존성으로 사용합니다.

```typescript
// ❌ 잘못된 예: 객체 의존성 (불필요한 재실행)
function UserProfile({ user }: { user: User }) {
  useEffect(() => {
    fetchUserActivity(user.id);
  }, [user]);  // user 객체의 어떤 속성이 변해도 재실행
}

// ✅ 올바른 예: Primitive 의존성
function UserProfile({ user }: { user: User }) {
  const userId = user.id;

  useEffect(() => {
    fetchUserActivity(userId);
  }, [userId]);  // id가 변할 때만 재실행
}

// ✅ 파생 상태로 변환
function ResponsiveComponent() {
  const [width, setWidth] = useState(window.innerWidth);
  const isMobile = width < 768;  // 파생 boolean

  useEffect(() => {
    // isMobile 값이 변할 때만 실행되도록
    if (isMobile) {
      setupMobileLayout();
    } else {
      setupDesktopLayout();
    }
  }, [isMobile]);  // width 대신 파생된 boolean 사용
}
```

---

### 5.3 지연 상태 초기화

비용이 큰 초기화는 **함수로 감싸서** 한 번만 실행되게 합니다.

```typescript
// ❌ 잘못된 예: 매 렌더마다 초기화 함수 실행
const [data, setData] = useState(expensiveComputation(items));
const [settings, setSettings] = useState(JSON.parse(localStorage.getItem('settings') || '{}'));

// ✅ 올바른 예: 함수로 감싸서 최초 1회만 실행
const [data, setData] = useState(() => expensiveComputation(items));
const [settings, setSettings] = useState(() => {
  if (typeof window === 'undefined') return {};
  const stored = localStorage.getItem('settings');
  return stored ? JSON.parse(stored) : {};
});
```

**지연 초기화가 필요한 경우:**
| 상황 | 예시 |
|------|------|
| localStorage 읽기 | `JSON.parse(localStorage.getItem(...))` |
| 복잡한 계산 | 배열 정렬, 필터링, 맵 생성 |
| 큰 데이터 구조 생성 | `new Map()`, `new Set()` with data |
| DOM 측정 | `window.innerWidth` |

---

## 6. 성능 최적화 체크리스트

```
□ Waterfall 제거
  □ 독립적인 API 호출에 Promise.all() 사용
  □ 조건 체크 후 데이터 페칭 (await 지연)

□ 번들 최적화
  □ next.config.js에 optimizePackageImports 설정
  □ 무거운 컴포넌트에 next/dynamic 적용
  □ Analytics 등 서드파티는 ssr: false로 지연 로드

□ 서버 컴포넌트 성능
  □ 독립적인 데이터 페칭 컴포넌트 분리
  □ 클라이언트 컴포넌트에 필요한 props만 전달
  □ Suspense 경계로 점진적 로딩

□ 리렌더 최적화
  □ setState에 함수형 업데이트 사용
  □ useEffect 의존성에 primitive 값 사용
  □ 비용 큰 초기화에 useState(() => ...) 사용
```

---

## 7. 참고 자료

- [Vercel React Best Practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)
- [Next.js App Router Documentation](https://nextjs.org/docs/app)
- [React Server Components](https://react.dev/reference/rsc/server-components)
