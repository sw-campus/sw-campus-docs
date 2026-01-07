# 05. 예외 처리 규칙

> 일관된 예외 처리로 디버깅과 클라이언트 대응을 용이하게 합니다.

---

## Single Source of Truth

| 정보 유형 | Truth 위치 | 비고 |
|-----------|-----------|------|
| 에러 코드 목록 | `ErrorCode.java` | 컴파일러가 강제 |
| 에러 응답 형식 | `ErrorResponse.java` | 코드가 Truth |
| 예외 핸들러 | `GlobalExceptionHandler.java` | 코드가 Truth |

> 이 문서에는 **패턴**과 **설계 결정**만 기록합니다.

---

## 예외 구조

```
sw-campus-server/
├── sw-campus-api/
│   └── exception/
│       ├── GlobalExceptionHandler.java    # 전역 예외 핸들러
│       └── ErrorResponse.java             # 에러 응답 DTO
│
├── sw-campus-domain/
│   └── {도메인}/
│       └── exception/
│           └── {Domain}NotFoundException.java  # 도메인별 예외
│
└── sw-campus-shared/
    └── error/
        ├── ErrorCode.java                 # 에러 코드 정의
        └── BusinessException.java         # 비즈니스 예외 기본 클래스
```

---

## 설계 결정

### 왜 ErrorCode enum인가?

- **타입 안전성**: 문자열 에러 코드의 오타 방지
- **중앙 관리**: 모든 에러 코드를 한 곳에서 확인/관리
- **일관성**: HTTP 상태, 코드, 메시지를 묶어서 관리

### 왜 BusinessException 단일 기본 클래스인가?

- **핸들러 단순화**: `GlobalExceptionHandler`에서 단일 핸들러로 처리
- **일관된 응답**: 모든 비즈니스 예외가 동일한 응답 구조

### 왜 shared/error 모듈인가?

- **의존성 방향**: `domain → shared ← api` 구조 유지
- **재사용**: 모든 모듈에서 ErrorCode, BusinessException 사용 가능

### 에러 코드 접두사 규칙

| 접두사 | 도메인 |
|--------|--------|
| C | Common (공통) |
| M | Member (회원) |
| A | Auth (인증) |
| O | Organization (기관) |
| T | cerTificate (수료증) |
| R | Review (후기) |
| B | Basket/Cart (장바구니) |
| S | Survey (설문) |
| F | File/Storage (파일) |
| L | Lecture (강의) |

> 전체 에러 코드 목록: `ErrorCode.java` 참조

---

## 패턴

### 도메인 예외 정의

```java
// BusinessException을 상속하고 ErrorCode를 전달
public class MemberNotFoundException extends BusinessException {

    public MemberNotFoundException() {
        super(ErrorCode.MEMBER_NOT_FOUND);
    }

    // 상세 메시지가 필요한 경우
    public MemberNotFoundException(Long id) {
        super(ErrorCode.MEMBER_NOT_FOUND,
              String.format("회원을 찾을 수 없습니다. ID: %d", id));
    }
}
```

### Service에서 예외 사용

```java
public Member getMember(Long id) {
    return memberRepository.findById(id)
            .orElseThrow(() -> new MemberNotFoundException(id));
}
```

---

## 금지 사항

### 1. 무분별한 try-catch 금지

```java
// ❌ 예외를 삼키지 말 것
try {
    return memberRepository.findById(id).orElseThrow();
} catch (Exception e) {
    return null;
}

// ✅ 명시적 예외 던지기
return memberRepository.findById(id)
        .orElseThrow(() -> new MemberNotFoundException(id));
```

### 2. 일반 Exception 던지기 금지

```java
// ❌ 구체적이지 않은 예외
throw new RuntimeException("회원을 찾을 수 없습니다");

// ✅ 도메인 예외 사용
throw new MemberNotFoundException(memberId);
```

### 3. 에러 메시지에 민감 정보 포함 금지

```java
// ❌ 비밀번호 노출
throw new BusinessException(ErrorCode.INVALID_CREDENTIALS,
    "비밀번호가 틀렸습니다: " + inputPassword);

// ✅ 일반적인 메시지
throw new BusinessException(ErrorCode.INVALID_CREDENTIALS,
    "이메일 또는 비밀번호가 올바르지 않습니다");
```

---

## 체크리스트

- [ ] 도메인별 예외 클래스가 `BusinessException`을 상속하는가?
- [ ] `ErrorCode`에 에러 코드가 정의되어 있는가?
- [ ] 일반 Exception 대신 구체적인 예외를 던지는가?
- [ ] 에러 메시지에 민감 정보가 없는가?
