# 수료증 OCR 다단계 강의명 매칭 검증 Spec

## 개요

수료증 OCR 검증 시 강의명 매칭을 다단계로 수행하여 유사 문자 불일치 문제를 해결한다.
기존 `CertificateService.validateLectureName()` 메서드를 개선하여 4단계(0~3차) 매칭을 수행한다.

---

## API

### 기존 API (변경 없음)

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|:----:|
| POST | `/api/v1/certificates/verify` | 수료증 검증 및 인증 | O |

API 인터페이스는 변경 없음. 내부 매칭 로직만 개선.

---

## DB 스키마

**변경 없음**

기존 `certificate` 테이블 그대로 사용.

---

## 의존성 추가

### Apache Commons Text

```groovy
// sw-campus-domain/build.gradle
dependencies {
    implementation 'org.apache.commons:commons-text:1.11.0'
}
```

**사용 목적**: Jaro-Winkler 유사도 알고리즘 (`JaroWinklerSimilarity`)

---

## 구현 설계

### 클래스 구조

```
sw-campus-domain/src/main/java/com/swcampus/domain/certificate/
├── CertificateService.java          # 기존 서비스 (매칭 로직 위임)
└── LectureNameMatcher.java           # 새로운 매칭 유틸리티 (신규)
```

### LectureNameMatcher 클래스

```java
package com.swcampus.domain.certificate;

/**
 * 강의명 다단계 매칭 유틸리티
 */
@Slf4j
@Component
public class LectureNameMatcher {

    private static final double SIMILARITY_THRESHOLD = 0.8;

    /**
     * 다단계 매칭 수행
     * @return true if matched, false otherwise
     */
    public boolean match(String lectureName, List<String> ocrLines) {
        // 0단계: OCR 유효성 검사
        // 1차: 정확한 매칭
        // 2차: 유사 문자 정규화 매칭
        // 3차: 유사도 매칭 (Jaro-Winkler >= 0.8)
    }
}
```

### 메서드 설계

| 메서드 | 설명 | 반환 |
|--------|------|------|
| `match(lectureName, ocrLines)` | 다단계 매칭 진입점 | boolean |
| `isValidOcrResult(ocrText, lectureName)` | 0단계: OCR 유효성 검사 | boolean |
| `exactMatch(ocrText, lectureName)` | 1차: 정확한 매칭 | boolean |
| `normalizedMatch(ocrText, lectureName)` | 2차: 유사 문자 정규화 매칭 | boolean |
| `similarityMatch(ocrText, lectureName)` | 3차: Jaro-Winkler 유사도 매칭 | boolean |
| `normalizeHomoglyphs(text)` | 유사 문자 정규화 | String |

### 유사 문자 정규화 맵

```java
private static final Map<Character, Character> HOMOGLYPH_MAP = Map.of(
    '×', 'x',   // U+00D7 → x
    '—', '-',   // U+2014 → -
    '–', '-',   // U+2013 → -
    ''', '\'',  // U+2018 → '
    ''', '\'',  // U+2019 → '
    '"', '"',   // U+201C → "
    '"', '"'    // U+201D → "
);
```

---

## 에러 코드

| 코드 | HTTP | 설명 |
|------|:----:|------|
| CERT002 | 400 | 해당 강의의 수료증이 아닙니다 (0~3차 모두 실패) |
| CERT003 | 409 | 이미 인증된 수료증입니다 |

**참고**: 기존 예외 클래스 재사용
- `CertificateLectureMismatchException` (기존) - 0~3차 실패 통합

---

## 로깅

### 로그 포맷

```
[수료증 검증] 0단계 유효성: ocrLength={}, lectureNameLength={}, valid={}
[수료증 검증] 1차 정확한 매칭: matched={}
[수료증 검증] 2차 정규화 매칭: matched={}
[수료증 검증] 3차 유사도 매칭: similarity={}, threshold={}, matched={}
[수료증 검증] 최종 결과: lectureName='{}', matchedStep={}
```

### matchedStep 값

| 값 | 의미 |
|----|------|
| 0 | 0단계에서 실패 (유효성 검사 실패) |
| 1 | 1차에서 성공 |
| 2 | 2차에서 성공 |
| 3 | 3차에서 성공 |
| -1 | 모든 단계 실패 |

---

## 테스트 케이스

### 단위 테스트 (LectureNameMatcherTest)

| 테스트 | 입력 | 기대 결과 |
|--------|------|-----------|
| 0단계 실패 - OCR 비어있음 | `ocrLines = []` | false |
| 0단계 실패 - 길이 부족 | `ocrText.length < lectureName.length * 0.5` | false |
| 1차 성공 - 정확한 매칭 | `"[구름] 자바 스프링"` contains `"[구름] 자바 스프링"` | true (1차) |
| 2차 성공 - 유사 문자 | `"[구름 × 인프런]"` vs `"[구름 x 인프런]"` | true (2차) |
| 3차 성공 - 유사도 80%+ | `"자바 스프링 기초 과정"` vs `"자바 스프링 기초"` | true (3차) |
| 최종 실패 - 전혀 다른 강의 | `"파이썬 기초"` vs `"자바 스프링"` | false |

---

## 구현 노트

### 2025-12-27 - 수료증 OCR 다단계 강의명 매칭 검증 구현

- **PR**: [#247](https://github.com/sw-campus/sw-campus-server/pull/247)
- **주요 변경**:
  - `LectureNameMatcher` 클래스 추가 (다단계 매칭 유틸리티)
  - 0단계: OCR 유효성 검사 (길이 50% 이상)
  - 1차: 정확한 매칭 (공백/대소문자 무시)
  - 2차: 유사 문자 정규화 (×→x, —→- 등)
  - 3차: Jaro-Winkler 유사도 (≥80%)
  - Apache Commons Text 의존성 추가
  - `CertificateService`에서 `LectureNameMatcher` 사용
- **특이사항**:
  - `CertificateOcrInvalidException` 제거 - 모든 실패를 `CertificateLectureMismatchException`으로 통합
  - 클라이언트에 일관된 에러 메시지 제공 ("해당 강의의 수료증이 아닙니다")

---

## 체크리스트

- [x] Apache Commons Text 의존성 추가
- [x] LectureNameMatcher 클래스 구현
- [x] CertificateService에서 LectureNameMatcher 사용
- [x] 단위 테스트 작성
- [x] 로컬 테스트 확인
