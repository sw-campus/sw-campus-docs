# Phase 02: 수료증 인증 API

> OCR 연동 및 수료증 확인/인증 API 구현

## 목표

- OCR 클라이언트 구현 (sw-campus-ai 연동)
- 수료증 확인 API (이미 인증했는지 체크)
- 수료증 인증 API (이미지 업로드 + OCR 검증)

---

## 1. Infra 모듈 (OCR)

### 1.1 OCR 모듈 구조

```
sw-campus-infra/ocr/
├── build.gradle
└── src/main/java/com/swcampus/infra/ocr/
    ├── OcrClientImpl.java
    └── OcrResponse.java
```

### 1.2 build.gradle

```groovy
dependencies {
    implementation project(':sw-campus-domain')
    implementation 'org.springframework.boot:spring-boot-starter-web'
}
```

### 1.3 Domain 인터페이스

#### OcrClient.java (domain 모듈)
```java
package com.swcampus.domain.ocr;

import java.util.List;

public interface OcrClient {
    
    /**
     * 이미지에서 텍스트를 추출
     *
     * @param imageBytes 이미지 바이트 배열
     * @param fileName 파일명
     * @return 추출된 텍스트 라인 목록
     */
    List<String> extractText(byte[] imageBytes, String fileName);
}
```

### 1.4 OCR Response DTO

#### OcrResponse.java
```java
package com.swcampus.infra.ocr;

import java.util.List;

public record OcrResponse(
    String text,
    List<String> lines,
    List<Double> scores
) {}
```

### 1.5 OCR 클라이언트 구현체

#### OcrClientImpl.java
```java
package com.swcampus.infra.ocr;

import com.swcampus.domain.ocr.OcrClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.util.Collections;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class OcrClientImpl implements OcrClient {

    private final RestTemplate restTemplate;

    @Value("${ocr.server.url}")
    private String ocrServerUrl;

    @Override
    public List<String> extractText(byte[] imageBytes, String fileName) {
        try {
            String url = ocrServerUrl + "/ocr/extract";

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.MULTIPART_FORM_DATA);

            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("image", new ByteArrayResource(imageBytes) {
                @Override
                public String getFilename() {
                    return fileName;
                }
            });

            HttpEntity<MultiValueMap<String, Object>> requestEntity = 
                new HttpEntity<>(body, headers);

            OcrResponse response = restTemplate.postForObject(
                url, requestEntity, OcrResponse.class
            );

            if (response != null && response.lines() != null) {
                return response.lines();
            }
            return Collections.emptyList();

        } catch (Exception e) {
            log.error("OCR 서버 호출 실패: {}", e.getMessage());
            return Collections.emptyList();
        }
    }
}
```

### 1.6 RestTemplate 설정

#### OcrConfig.java
```java
package com.swcampus.infra.ocr;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class OcrConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
```

---

## 2. Domain 모듈

### 2.1 CertificateService.java

```java
package com.swcampus.domain.certificate;

import com.swcampus.domain.certificate.exception.CertificateAlreadyVerifiedException;
import com.swcampus.domain.certificate.exception.CertificateLectureMismatchException;
import com.swcampus.domain.lecture.Lecture;
import com.swcampus.domain.lecture.LectureRepository;
import com.swcampus.domain.lecture.exception.LectureNotFoundException;
import com.swcampus.domain.ocr.OcrClient;
import com.swcampus.domain.storage.FileStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CertificateService {

    private final CertificateRepository certificateRepository;
    private final LectureRepository lectureRepository;
    private final FileStorageService fileStorageService;
    private final OcrClient ocrClient;

    /**
     * 수료증 인증 여부 확인
     */
    public Optional<Certificate> checkCertificate(Long memberId, Long lectureId) {
        return certificateRepository.findByMemberIdAndLectureId(memberId, lectureId);
    }

    /**
     * 수료증 인증 처리
     */
    @Transactional
    public Certificate verifyCertificate(Long memberId, Long lectureId, 
                                          byte[] imageBytes, String fileName, 
                                          String contentType) {
        // 1. 이미 인증했는지 확인
        if (certificateRepository.existsByMemberIdAndLectureId(memberId, lectureId)) {
            throw new CertificateAlreadyVerifiedException();
        }

        // 2. 강의 정보 조회
        Lecture lecture = lectureRepository.findById(lectureId)
                .orElseThrow(LectureNotFoundException::new);

        // 3. OCR로 텍스트 추출
        List<String> extractedLines = ocrClient.extractText(imageBytes, fileName);

        // 4. 강의명 매칭 검증
        boolean isValid = validateLectureName(lecture.getName(), extractedLines);
        if (!isValid) {
            throw new CertificateLectureMismatchException();
        }

        // 5. S3에 이미지 업로드
        String imageUrl = fileStorageService.upload(imageBytes, fileName, contentType);

        // 6. 수료증 저장 (OCR 검증 성공 시 status = "SUCCESS")
        Certificate certificate = Certificate.create(memberId, lectureId, imageUrl, "SUCCESS");
        return certificateRepository.save(certificate);
    }

    /**
     * 강의명 유연한 매칭
     * - 공백 제거
     * - 소문자 변환
     * - 부분 일치 확인
     */
    private boolean validateLectureName(String lectureName, List<String> ocrLines) {
        if (ocrLines == null || ocrLines.isEmpty()) {
            return false;
        }

        String normalizedLectureName = normalize(lectureName);
        String ocrText = String.join("", ocrLines);
        String normalizedOcrText = normalize(ocrText);

        return normalizedOcrText.contains(normalizedLectureName);
    }

    private String normalize(String text) {
        if (text == null) {
            return "";
        }
        return text.replaceAll("\\s+", "").toLowerCase();
    }
}
```

### 2.2 추가 예외 클래스

#### CertificateLectureMismatchException.java
```java
package com.swcampus.domain.certificate.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class CertificateLectureMismatchException extends BusinessException {
    public CertificateLectureMismatchException() {
        super(ErrorCode.CERTIFICATE_LECTURE_MISMATCH);
    }
}
```

---

## 3. API 모듈

### 3.1 Request/Response DTO

#### CertificateCheckResponse.java
```java
package com.swcampus.api.certificate.response;

public record CertificateCheckResponse(
    boolean certified,
    Long certificateId,
    String imageUrl,
    String approvalStatus,
    String certifiedAt
) {
    public static CertificateCheckResponse notCertified() {
        return new CertificateCheckResponse(false, null, null, null, null);
    }

    public static CertificateCheckResponse certified(Long id, String imageUrl, 
                                                      String status, String certifiedAt) {
        return new CertificateCheckResponse(true, id, imageUrl, status, certifiedAt);
    }
}
```

#### CertificateVerifyResponse.java
```java
package com.swcampus.api.certificate.response;

public record CertificateVerifyResponse(
    Long certificateId,
    Long lectureId,
    String imageUrl,
    String approvalStatus,
    String message
) {}
```

### 3.2 Controller

#### CertificateController.java
```java
package com.swcampus.api.certificate;

import com.swcampus.api.certificate.response.CertificateCheckResponse;
import com.swcampus.api.certificate.response.CertificateVerifyResponse;
import com.swcampus.domain.certificate.Certificate;
import com.swcampus.domain.certificate.CertificateService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.format.DateTimeFormatter;

@Tag(name = "Certificate", description = "수료증 인증 API")
@RestController
@RequestMapping("/api/v1/certificates")
@RequiredArgsConstructor
public class CertificateController {

    private final CertificateService certificateService;
    private static final DateTimeFormatter FORMATTER = 
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    @Operation(summary = "수료증 인증 여부 확인")
    @GetMapping("/check")
    public ResponseEntity<CertificateCheckResponse> checkCertificate(
            @AuthenticationPrincipal Long memberId,
            @RequestParam Long lectureId) {

        return certificateService.checkCertificate(memberId, lectureId)
                .map(cert -> ResponseEntity.ok(CertificateCheckResponse.certified(
                        cert.getCertificateId(),
                        cert.getImageUrl(),
                        cert.getApprovalStatus().name(),
                        cert.getCreatedAt().format(FORMATTER)
                )))
                .orElseGet(() -> ResponseEntity.ok(CertificateCheckResponse.notCertified()));
    }

    @Operation(summary = "수료증 인증 (이미지 업로드 + OCR 검증)")
    @PostMapping(value = "/verify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<CertificateVerifyResponse> verifyCertificate(
            @AuthenticationPrincipal Long memberId,
            @RequestParam Long lectureId,
            @RequestPart MultipartFile image) throws IOException {

        Certificate certificate = certificateService.verifyCertificate(
                memberId,
                lectureId,
                image.getBytes(),
                image.getOriginalFilename(),
                image.getContentType()
        );

        CertificateVerifyResponse response = new CertificateVerifyResponse(
                certificate.getCertificateId(),
                certificate.getLectureId(),
                certificate.getImageUrl(),
                certificate.getApprovalStatus().name(),
                "수료증 인증이 완료되었습니다. 관리자 승인 후 후기 작성이 가능합니다."
        );

        return ResponseEntity.ok(response);
    }
}
```

---

## 4. 설정

### 4.1 application.yml 추가

```yaml
ocr:
  server:
    url: ${OCR_SERVER_URL:http://localhost:8000}
```

---

## 체크리스트

- [x] OcrClient 인터페이스 생성 (domain)
- [x] OcrClientImpl 구현체 생성 (infra/ocr)
- [x] OcrResponse DTO 생성
- [x] RestTemplate 설정
- [x] CertificateService 구현
- [x] CertificateLectureMismatchException 추가
- [x] CertificateController 구현
- [x] Request/Response DTO 생성
- [x] application.yml OCR 설정 추가
- [x] 컴파일 및 API 테스트
- [x] GlobalExceptionHandler에 CertificateLectureMismatchException 핸들러 추가
