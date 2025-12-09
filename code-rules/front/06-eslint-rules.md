# 06. ESLint 규칙

> TypeScript 및 JavaScript 코드 품질 규칙

---

## 1. 규칙 개요

### 1.1 기본 설정

```javascript
// eslint.config.mjs
import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

const eslintConfig = [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
  {
    rules: {
      // TypeScript
      "@typescript-eslint/no-explicit-any": "warn",        // any 경고
      "@typescript-eslint/no-unused-vars": ["error", {     // 미사용 변수
        argsIgnorePattern: "^_",                           // _ prefix 허용
        varsIgnorePattern: "^_",
      }],
      
      // JavaScript
      "no-console": ["error", {                            // console.log 금지
        allow: ["warn", "error"],                          // warn, error 허용
      }],
      "prefer-const": "error",                             // const 우선
      "no-var": "error",                                   // var 금지
      "eqeqeq": ["error", "always"],                       // === 필수
      
      // Next.js
      "@next/next/no-html-link-for-pages": "off",          // <a> 허용
    },
  },
];

export default eslintConfig;
```

---

## 2. TypeScript 규칙

### 2.1 any 타입 사용

```typescript
// ⚠️ 경고 (허용되지만 지양)
const fetchData = async (): Promise<any> => {
  const result = await api.get('/test');
  return result;
};

// ✅ 권장: 타입 명시
interface User {
  id: string;
  name: string;
}

const fetchData = async (): Promise<User[]> => {
  const { data } = await api.get<User[]>('/users');
  return data;
};
```

**규칙:**
- `any` 사용 시 **경고**만 표시 (에러 아님)
- 가능하면 구체적인 타입 사용 권장
- 외부 라이브러리 타입 문제 등 불가피한 경우 허용

### 2.2 미사용 변수

```typescript
// ❌ 에러: 사용하지 않는 변수
const unused = 'value';

// ✅ 허용: _ prefix 사용
const _unused = 'value';

// ✅ 허용: 함수 매개변수에 _ prefix
const handleClick = (_event: MouseEvent) => {
  // event를 사용하지 않지만 시그니처 유지 필요
};

// ✅ 허용: 구조 분해에서 제외
const { used, ...rest } = obj;  // rest 사용 안 해도 OK
```

---

## 3. JavaScript 규칙

### 3.1 console 사용

```typescript
// ❌ 에러: console.log 금지
console.log('debug');
console.log('데이터:', data);

// ✅ 허용: warn, error
console.warn('경고 메시지');
console.error('에러 발생:', error);

// ✅ 권장: 디버깅 시 사용 후 제거
// 또는 로깅 라이브러리 사용
```

### 3.2 변수 선언

```typescript
// ❌ 에러: var 금지 (완전 금지)
var x = 10;

// ❌ 에러: 재할당 없는 let
let y = 20;
console.warn(y);  // y가 변경되지 않음

// ✅ const 사용 (재할당 없을 때)
const y = 20;

// ✅ let 사용 (재할당 필요할 때)
let count = 0;
count += 1;
```

### 3.3 비교 연산자

```typescript
// ❌ 에러: 느슨한 비교
if (a == '1') { }
if (b != null) { }

// ✅ 엄격한 비교 필수
if (a === '1') { }
if (b !== null) { }

// ✅ nullish 체크
if (b != null) { }  // null과 undefined 동시 체크는 예외
```

---

## 4. Next.js 규칙

### 4.1 링크 규칙

```tsx
// ✅ 허용: <a> 태그 사용 가능 (App Router)
<a href="/about">About</a>

// ✅ 권장: <Link> 컴포넌트
import Link from 'next/link';

<Link href="/about">About</Link>
```

**참고:** Next.js App Router에서는 `<a>` 태그 사용이 허용됩니다. 다만 클라이언트 사이드 네비게이션을 위해 `<Link>` 사용을 권장합니다.

---

## 5. 규칙 요약표

| 규칙 | 레벨 | 설명 |
|------|------|------|
| `@typescript-eslint/no-explicit-any` | warn | any 사용 경고 (허용) |
| `@typescript-eslint/no-unused-vars` | error | 미사용 변수 금지 (_ prefix 예외) |
| `no-console` | error | console.log 금지 (warn, error 허용) |
| `prefer-const` | error | const 우선 사용 |
| `no-var` | error | var 완전 금지 |
| `eqeqeq` | error | === 필수 |
| `@next/next/no-html-link-for-pages` | off | `<a>` 태그 허용 |

---

## 6. 허용/금지 예시 모음

### 6.1 허용되는 코드

```typescript
// any 경고는 있지만 허용
const fetchData = async () => {
  const result: any = await api.get('/test');
  return result;
};

// _ prefix로 미사용 변수 허용
const handleClick = (_event: MouseEvent) => { 
  doSomething();
};

// console.warn, console.error 허용
console.warn('주의: 데이터가 없습니다');
console.error('오류:', error);

// <a> 태그 허용
<a href="/external" target="_blank">External Link</a>
```

### 6.2 금지되는 코드

```typescript
// ❌ let 불필요 사용
let x = 10;  // 재할당 없으면 const로

// ❌ var 금지
var y = 3;

// ❌ console.log 금지
console.log('debug');

// ❌ 느슨한 비교 금지
if (a == '1') { }

// ❌ 미사용 변수 (prefix 없음)
const unused = 'value';
```

---

## 7. IDE 설정

### 7.1 VS Code 설정

```json
// .vscode/settings.json
{
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact"
  ]
}
```

### 7.2 저장 시 자동 수정

위 설정으로 파일 저장 시 자동으로:
- const/let 변환
- 사용하지 않는 import 제거
- 기타 자동 수정 가능한 규칙 적용

---

## 8. ESLint 체크리스트

```
□ any 사용 최소화 (경고 확인)
□ 미사용 변수에 _ prefix 추가 또는 제거
□ console.log 제거 (warn, error만 사용)
□ const 사용 (재할당 없을 때)
□ var 사용 없음
□ === / !== 사용 (== / != 금지)
□ ESLint 경고/에러 0개 확인
```
