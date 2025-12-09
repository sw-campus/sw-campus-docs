# 04. API 통신

> Axios 인스턴스 사용 규칙 및 에러 처리 전략

---

## 1. Axios 인스턴스 설정

### 1.1 기본 인스턴스

```typescript
// src/lib/axios.ts
import axios from 'axios';
import { env } from './env';

export const api = axios.create({
  baseURL: env.NEXT_PUBLIC_API_URL,
  withCredentials: true,  // 쿠키 인증 필수
  headers: {
    'Content-Type': 'application/json',
  },
});
```

### 1.2 핵심 규칙

| 규칙 | 상태 | 설명 |
|------|------|------|
| `api` 인스턴스 사용 | ✅ 필수 | `src/lib/axios.ts`의 인스턴스만 사용 |
| `withCredentials: true` | ✅ 필수 | 쿠키 기반 인증에 필요 |
| axios 직접 import | ❌ 금지 | 새 인스턴스 생성 금지 |
| fetch() 사용 | ❌ 금지 | 쿠키 인증 누락 위험 |
| baseURL 하드코딩 | ❌ 금지 | 환경변수 사용 필수 |

### 1.3 사용 예시

```typescript
// ✅ 올바른 사용
import { api } from '@/lib/axios';

const { data } = await api.get('/users');
await api.post('/users', { name: 'John' });

// ❌ 금지: axios 직접 import
import axios from 'axios';
const response = await axios.get('/api/users');

// ❌ 금지: fetch 사용
const response = await fetch('/api/users');

// ❌ 금지: 새 인스턴스 생성
const customApi = axios.create({ baseURL: 'http://...' });
```

---

## 2. 인터셉터 설정

### 2.1 요청 인터셉터

```typescript
// src/lib/axios.ts
api.interceptors.request.use(
  (config) => {
    // Authorization header는 여기서만 추가
    const token = getAccessToken();  // 토큰 가져오기 로직
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);
```

### 2.2 응답 인터셉터 (에러 처리)

```typescript
// src/lib/axios.ts
import { toast } from 'sonner';

api.interceptors.response.use(
  (response) => response,
  (error) => {
    // 에러 toast는 여기서만 처리
    const message = error.response?.data?.message || '오류가 발생했습니다.';
    
    // 특정 상태 코드별 처리
    switch (error.response?.status) {
      case 401:
        toast.error('로그인이 필요합니다.');
        // 로그인 페이지 리다이렉트 로직
        break;
      case 403:
        toast.error('접근 권한이 없습니다.');
        break;
      case 404:
        toast.error('요청한 리소스를 찾을 수 없습니다.');
        break;
      case 500:
        toast.error('서버 오류가 발생했습니다.');
        break;
      default:
        toast.error(message);
    }

    return Promise.reject(error);
  }
);
```

---

## 3. 에러 처리 규칙

### 3.1 금지 사항

```typescript
// ❌ 컴포넌트에서 toast 중복 호출
function MyComponent() {
  const handleSubmit = async () => {
    try {
      await api.post('/data', formData);
    } catch (error) {
      toast.error('에러 발생!');  // 인터셉터와 중복!
    }
  };
}

// ❌ Hook에서 toast 호출
export function useAddToCart() {
  return useMutation({
    mutationFn: (data) => api.post('/cart', data),
    onError: () => {
      toast.error('장바구니 추가 실패');  // 인터셉터와 중복!
    },
  });
}

// ❌ axios error 메시지 재가공
catch (error) {
  const message = error.response?.data?.message;
  toast.error(`오류: ${message}`);  // 인터셉터가 이미 처리함
}
```

### 3.2 올바른 패턴

```typescript
// ✅ 에러 처리는 인터셉터에 위임
function MyComponent() {
  const mutation = useAddToCart();
  
  const handleSubmit = async () => {
    try {
      await mutation.mutateAsync(formData);
      toast.success('장바구니에 추가되었습니다.');  // 성공 toast만
    } catch (error) {
      // 에러 toast는 인터셉터에서 처리됨
      // 필요시 추가 로직만 작성 (폼 리셋, 상태 변경 등)
    }
  };
}

// ✅ Mutation에서는 성공 처리만
export function useAddToCart() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (data) => api.post('/cart', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cart'] });
      // 성공 toast는 컴포넌트에서 처리
    },
    // onError 불필요 (인터셉터에서 처리)
  });
}
```

---

## 4. 인증/토큰 관리

### 4.1 Authorization Header 규칙

```typescript
// ✅ 인터셉터에서만 Authorization header 추가
api.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ❌ 컴포넌트에서 직접 header 설정
await api.get('/users', {
  headers: { Authorization: `Bearer ${token}` }  // 금지!
});
```

### 4.2 쿠키 기반 인증

- `withCredentials: true` 필수 설정
- 서버에서 `Set-Cookie` 헤더로 토큰 전송
- 브라우저가 자동으로 쿠키 포함하여 요청

---

## 5. API 호출 패턴

### 5.1 GET 요청

```typescript
// Query Hook에서 사용
export function useUsersQuery() {
  return useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const { data } = await api.get<User[]>('/users');
      return data;
    },
  });
}
```

### 5.2 POST/PUT/PATCH 요청

```typescript
// Mutation Hook에서 사용
export function useCreateUser() {
  return useMutation({
    mutationFn: async (userData: CreateUserRequest) => {
      const { data } = await api.post<User>('/users', userData);
      return data;
    },
  });
}
```

### 5.3 DELETE 요청

```typescript
export function useDeleteUser() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: async (userId: string) => {
      await api.delete(`/users/${userId}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

---

## 6. 환경변수 관리

```typescript
// src/lib/env.ts
export const env = {
  NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080',
} as const;
```

```bash
# .env.local
NEXT_PUBLIC_API_URL=http://localhost:8080

# .env.production
NEXT_PUBLIC_API_URL=https://api.production.com
```

---

## 7. API 통신 체크리스트

```
□ api 인스턴스 import 경로: @/lib/axios
□ withCredentials: true 설정 확인
□ axios 직접 import 없음
□ fetch() 사용 없음
□ baseURL 하드코딩 없음
□ 컴포넌트/훅에서 에러 toast 중복 호출 없음
□ Authorization header는 인터셉터에서만 추가
□ 환경변수로 API URL 관리
```
