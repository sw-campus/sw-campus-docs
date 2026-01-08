# Redis 캐시 역직렬화 에러

## 에러 발생 원인: 동시성 문제 (Race Condition)

빠른 시간 내에 장바구니 추가/삭제를 반복하면 발생할 수 있습니다:

1. `getCartList` 호출 → Redis GET 시작
2. `addCart` 호출 → `deleteCart`로 캐시 삭제
3. `getCartList`의 역직렬화 중 데이터 변경 → 에러 발생

## 무시해도 되는 이유

### 1. 자동 복구 로직

```java
try {

} catch (Exception e) {
    log.warn("Corrupted cart cache for userId: {}, deleting and will be regenerated", userId);
    deleteCart(userId);  // 손상된 캐시 삭제
    return null;         // null 반환 → DB에서 데이터조회 → 캐시 재생성
}
```

에러 발생 시:

1. 손상된 캐시 **자동 삭제**
2. `null` 반환 → DB에서 데이터 조회
3. 올바른 형식으로 **캐시 재생성**

### 2. 기능적 영향 없음

- 캐시 미스 시 DB fallback 존재
- 사용자는 정상적으로 서비스 이용 가능
- 다음 요청부터는 올바른 캐시 사용

### 3. 일시적 현상

동시성으로 인한 에러는 순간적으로 발생하며, 자동 복구됩니다.

## 결론

| 항목           | 상태                     |
| -------------- | ------------------------ |
| 사용자 영향    | ❌ 없음                  |
| 데이터 손실    | ❌ 없음 (DB에 원본 존재) |
| 자동 복구      | ✅ 처리됨                |
| 추가 조치 필요 | ❌ 불필요                |

**WARN 로그가 가끔 발생하는 것은 정상이며, 별도의 조치가 필요하지 않습니다.**
