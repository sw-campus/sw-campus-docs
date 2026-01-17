# 08. 보안 규칙 (Client)

## 1. 토큰 저장

### 1.1 Access Token
- **localStorage 저장 금지** (XSS 취약)
- 메모리(Zustand state)에만 유지
- 페이지 새로고침 시 httpOnly refresh cookie로 갱신

```typescript
// ✅ partialize로 accessToken 제외
persist(
  (set) => ({ /* state */ }),
  {
    name: 'auth-storage',
    partialize: (state) => ({
      isLoggedIn: state.isLoggedIn,
      userName: state.userName,
      // accessToken 제외
    }),
  }
)

// ❌ accessToken을 localStorage에 저장
persist((set) => ({ accessToken, ... }))
```

### 1.2 Refresh Token
- httpOnly 쿠키로만 관리 (서버에서 설정)
- 클라이언트에서 직접 접근 불가

---

## 2. HTTP Security Headers

### 2.1 필수 헤더 (next.config.ts)
```typescript
async headers() {
  return [
    {
      source: '/(.*)',
      headers: [
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
      ],
    },
  ]
}
```

| 헤더 | 효과 |
|------|------|
| X-Frame-Options: DENY | 클릭재킹 방지 (iframe 삽입 차단) |
| X-Content-Type-Options: nosniff | MIME 타입 스니핑 방지 |
| Referrer-Policy | 리퍼러 정보 제한 |
| Permissions-Policy | 불필요한 브라우저 API 차단 |

---

## 3. 입력값 검증

### 3.1 비밀번호 정책 (서버와 동일)
```typescript
password: z
  .string()
  .min(8, '비밀번호는 8자 이상이어야 합니다.')
  .regex(/[A-Z]/, '대문자 1개 이상')
  .regex(/[a-z]/, '소문자 1개 이상')
  .regex(/[0-9]/, '숫자 1개 이상')
  .regex(/[!@#$%^&*(),.?":{}|<>]/, '특수문자 1개 이상')
```

### 3.2 클라이언트-서버 일관성
- **중요**: 클라이언트 검증 규칙은 서버와 반드시 일치해야 함
- 서버: `PasswordValidator.java`
- 클라이언트: `authApi.ts` (Zod schema)

---

## 4. 난수 생성

### 4.1 암호학적으로 안전한 난수 필수
```typescript
// ✅ crypto API 사용
const cryptoObj = globalThis.crypto
if (cryptoObj?.randomUUID) {
  state = cryptoObj.randomUUID()
} else if (cryptoObj?.getRandomValues) {
  const array = new Uint8Array(16)
  cryptoObj.getRandomValues(array)
  state = Array.from(array, b => b.toString(16).padStart(2, '0')).join('')
}

// ❌ Math.random() 사용 금지
const state = Math.random().toString(36).slice(2)  // 예측 가능
```

### 4.2 사용 사례
- OAuth state 파라미터
- CSRF 토큰 (필요 시)
- 임시 식별자

---

## 5. API 통신

### 5.1 인증 정보 전송
```typescript
// ✅ withCredentials로 쿠키 포함
const api = axios.create({
  baseURL: env.NEXT_PUBLIC_API_URL,
  withCredentials: true,  // httpOnly 쿠키 전송
})
```

### 5.2 에러 처리
- 401 응답 시 자동 토큰 갱신 로직 구현
- 갱신 실패 시 로그인 페이지로 리다이렉트

---

## 6. 환경 변수

### 6.1 클라이언트 노출 변수
```bash
# ✅ NEXT_PUBLIC_ 접두사 = 브라우저에 노출됨
NEXT_PUBLIC_API_URL=https://api.example.com
NEXT_PUBLIC_GOOGLE_CLIENT_ID=xxx

# ❌ 민감 정보에 NEXT_PUBLIC_ 사용 금지
NEXT_PUBLIC_API_SECRET=xxx  # 절대 금지
```

### 6.2 서버 전용 변수
```bash
# 서버 컴포넌트/API 라우트에서만 접근
GEMINI_API_KEY=xxx
DATABASE_URL=xxx
```

---

## 7. 의존성 보안

### 7.1 정기 점검
```bash
# npm 취약점 스캔
pnpm audit

# 취약점 자동 수정
pnpm audit --fix
```

### 7.2 의존성 업데이트
- 보안 패치는 즉시 적용
- Major 업데이트는 테스트 후 적용

---

## 체크리스트

- [ ] accessToken localStorage 저장 안 함
- [ ] HTTP Security Headers 설정 (next.config.ts)
- [ ] 비밀번호 검증 규칙 서버와 일치
- [ ] 난수 생성에 crypto API 사용
- [ ] 민감 정보에 NEXT_PUBLIC_ 미사용
- [ ] withCredentials: true 설정 (쿠키 인증 시)
- [ ] pnpm audit 정기 실행
