# Phase 04: 관리자 API

> 2단계 관리자 승인 및 블라인드 처리 API 구현

## 목표

- 대기 중 후기 목록 조회
- 수료증 승인/반려 (1단계)
- 후기 승인/반려 (2단계)
- 블라인드 처리
- 반려 이메일 발송

---

## 1. Domain 모듈

### 1.1 AdminReviewService.java

```java
package com.swcampus.domain.review;

import com.swcampus.domain.certificate.Certificate;
import com.swcampus.domain.certificate.CertificateRepository;
import com.swcampus.domain.certificate.exception.CertificateNotFoundException;
import com.swcampus.domain.member.Member;
import com.swcampus.domain.member.MemberRepository;
import com.swcampus.domain.review.exception.ReviewNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminReviewService {

    private final ReviewRepository reviewRepository;
    private final CertificateRepository certificateRepository;
    private final MemberRepository memberRepository;
    private final EmailService emailService;

    /**
     * 대기 중인 후기 목록 조회 (수료증 또는 후기가 PENDING)
     */
    public List<Review> getPendingReviews() {
        return reviewRepository.findPendingReviews();
    }

    /**
     * 수료증 조회 (1단계 모달용)
     */
    public Certificate getCertificate(Long certificateId) {
        return certificateRepository.findById(certificateId)
                .orElseThrow(CertificateNotFoundException::new);
    }

    /**
     * 수료증 승인 (1단계)
     */
    @Transactional
    public Certificate approveCertificate(Long certificateId) {
        Certificate certificate = certificateRepository.findById(certificateId)
                .orElseThrow(CertificateNotFoundException::new);

        certificate.approve();
        return certificateRepository.save(certificate);
    }

    /**
     * 수료증 반려 (1단계)
     * - 수료증만 REJECTED
     * - 반려 이메일 발송
     * - 2단계 진행 안 함
     */
    @Transactional
    public Certificate rejectCertificate(Long certificateId) {
        Certificate certificate = certificateRepository.findById(certificateId)
                .orElseThrow(CertificateNotFoundException::new);

        certificate.reject();
        Certificate saved = certificateRepository.save(certificate);

        // 반려 이메일 발송
        Member member = memberRepository.findById(certificate.getUserId())
                .orElse(null);
        if (member != null) {
            emailService.sendCertificateRejectionEmail(member.getEmail());
        }

        return saved;
    }

    /**
     * 후기 상세 조회 (2단계 모달용)
     */
    public Review getReview(Long reviewId) {
        return reviewRepository.findById(reviewId)
                .orElseThrow(ReviewNotFoundException::new);
    }

    /**
     * 후기 승인 (2단계)
     */
    @Transactional
    public Review approveReview(Long reviewId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(ReviewNotFoundException::new);

        review.approve();
        return reviewRepository.save(review);
    }

    /**
     * 후기 반려 (2단계)
     * - 후기만 REJECTED (수료증은 이미 승인 상태)
     * - 반려 이메일 발송
     */
    @Transactional
    public Review rejectReview(Long reviewId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(ReviewNotFoundException::new);

        review.reject();
        Review saved = reviewRepository.save(review);

        // 반려 이메일 발송
        Member member = memberRepository.findById(review.getUserId())
                .orElse(null);
        if (member != null) {
            emailService.sendReviewRejectionEmail(member.getEmail());
        }

        return saved;
    }

    /**
     * 후기 블라인드 처리
     */
    @Transactional
    public Review blindReview(Long reviewId, boolean blurred) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(ReviewNotFoundException::new);

        if (blurred) {
            review.blind();
        } else {
            review.unblind();
        }

        return reviewRepository.save(review);
    }
}
```

### 1.2 EmailService 인터페이스

```java
package com.swcampus.domain.review;

public interface EmailService {
    void sendCertificateRejectionEmail(String email);
    void sendReviewRejectionEmail(String email);
}
```

---

## 2. Infra 모듈 (이메일)

### 2.1 EmailServiceImpl.java

```java
package com.swcampus.infra.email;

import com.swcampus.domain.review.EmailService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailServiceImpl implements EmailService {

    private final JavaMailSender mailSender;

    @Async
    @Override
    public void sendCertificateRejectionEmail(String email) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(email);
            message.setSubject("[SW Campus] 수료증 인증이 반려되었습니다");
            message.setText(
                "안녕하세요, SW Campus입니다.\n\n" +
                "제출하신 수료증이 검증에 실패했습니다.\n" +
                "올바른 수료증을 다시 제출해주세요.\n\n" +
                "감사합니다."
            );
            mailSender.send(message);
            log.info("수료증 반려 이메일 발송 완료: {}", email);
        } catch (Exception e) {
            log.error("수료증 반려 이메일 발송 실패: {}", e.getMessage());
        }
    }

    @Async
    @Override
    public void sendReviewRejectionEmail(String email) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(email);
            message.setSubject("[SW Campus] 후기가 반려되었습니다");
            message.setText(
                "안녕하세요, SW Campus입니다.\n\n" +
                "작성하신 후기가 관리자 검토 결과 반려되었습니다.\n" +
                "부적절한 내용이 포함되어 있습니다.\n\n" +
                "감사합니다."
            );
            mailSender.send(message);
            log.info("후기 반려 이메일 발송 완료: {}", email);
        } catch (Exception e) {
            log.error("후기 반려 이메일 발송 실패: {}", e.getMessage());
        }
    }
}
```

### 2.2 이메일 설정 (application.yml)

```yaml
spring:
  mail:
    host: ${MAIL_HOST:smtp.gmail.com}
    port: ${MAIL_PORT:587}
    username: ${MAIL_USERNAME}
    password: ${MAIL_PASSWORD}
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: true
```

---

## 3. API 모듈

### 3.1 Request DTO

#### BlindReviewRequest.java
```java
package com.swcampus.api.admin.request;

import jakarta.validation.constraints.NotNull;

public record BlindReviewRequest(
    @NotNull(message = "blurred 값은 필수입니다")
    Boolean blurred
) {}
```

### 3.2 Response DTO

#### AdminReviewListResponse.java
```java
package com.swcampus.api.admin.response;

import java.util.List;

public record AdminReviewListResponse(
    List<AdminReviewSummary> reviews,
    int totalCount
) {
    public record AdminReviewSummary(
        Long reviewId,
        Long lectureId,
        String lectureName,
        Long userId,
        String userName,
        String nickname,
        Double score,
        String certificateApprovalStatus,
        String reviewApprovalStatus,
        String createdAt
    ) {}
}
```

#### AdminCertificateResponse.java
```java
package com.swcampus.api.admin.response;

public record AdminCertificateResponse(
    Long certificateId,
    Long lectureId,
    String lectureName,
    String imageUrl,
    String approvalStatus,
    String certifiedAt
) {}
```

#### AdminReviewDetailResponse.java
```java
package com.swcampus.api.admin.response;

import java.util.List;

public record AdminReviewDetailResponse(
    Long reviewId,
    Long lectureId,
    String lectureName,
    Long userId,
    String userName,
    String nickname,
    String comment,
    Double score,
    String approvalStatus,
    String certificateApprovalStatus,
    List<DetailScore> detailScores,
    String createdAt
) {
    public record DetailScore(
        String category,
        Double score
    ) {}
}
```

#### CertificateApprovalResponse.java
```java
package com.swcampus.api.admin.response;

public record CertificateApprovalResponse(
    Long certificateId,
    String approvalStatus,
    String message
) {}
```

#### ReviewApprovalResponse.java
```java
package com.swcampus.api.admin.response;

public record ReviewApprovalResponse(
    Long reviewId,
    String approvalStatus,
    String message
) {}
```

### 3.3 Controller

#### AdminReviewController.java
```java
package com.swcampus.api.admin;

import com.swcampus.api.admin.request.BlindReviewRequest;
import com.swcampus.api.admin.response.*;
import com.swcampus.domain.certificate.Certificate;
import com.swcampus.domain.lecture.Lecture;
import com.swcampus.domain.lecture.LectureRepository;
import com.swcampus.domain.member.Member;
import com.swcampus.domain.member.MemberRepository;
import com.swcampus.domain.review.AdminReviewService;
import com.swcampus.domain.review.Review;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

@Tag(name = "Admin Review", description = "관리자 후기 관리 API")
@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
@SecurityRequirement(name = "cookieAuth")
public class AdminReviewController {

    private final AdminReviewService adminReviewService;
    private final LectureRepository lectureRepository;
    private final MemberRepository memberRepository;
    
    private static final DateTimeFormatter FORMATTER = 
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    @Operation(summary = "대기 중인 후기 목록 조회")
    @GetMapping("/reviews")
    public ResponseEntity<AdminReviewListResponse> getPendingReviews() {
        List<Review> reviews = adminReviewService.getPendingReviews();

        List<AdminReviewListResponse.AdminReviewSummary> summaries = reviews.stream()
                .map(this::toSummary)
                .collect(Collectors.toList());

        return ResponseEntity.ok(new AdminReviewListResponse(summaries, summaries.size()));
    }

    @Operation(summary = "[1단계] 수료증 조회")
    @GetMapping("/certificates/{certificateId}")
    public ResponseEntity<AdminCertificateResponse> getCertificate(
            @PathVariable Long certificateId) {
        
        Certificate certificate = adminReviewService.getCertificate(certificateId);
        
        String lectureName = lectureRepository.findById(certificate.getLectureId())
                .map(Lecture::getName)
                .orElse("알 수 없음");

        return ResponseEntity.ok(new AdminCertificateResponse(
                certificate.getCertificateId(),
                certificate.getLectureId(),
                lectureName,
                certificate.getImageUrl(),
                certificate.getApprovalStatus().name(),
                certificate.getCreatedAt().format(FORMATTER)
        ));
    }

    @Operation(summary = "[1단계] 수료증 승인")
    @PatchMapping("/certificates/{certificateId}/approve")
    public ResponseEntity<CertificateApprovalResponse> approveCertificate(
            @PathVariable Long certificateId) {
        
        Certificate certificate = adminReviewService.approveCertificate(certificateId);

        return ResponseEntity.ok(new CertificateApprovalResponse(
                certificate.getCertificateId(),
                certificate.getApprovalStatus().name(),
                "수료증이 승인되었습니다. 후기 내용을 확인해주세요."
        ));
    }

    @Operation(summary = "[1단계] 수료증 반려 (반려 이메일 발송)")
    @PatchMapping("/certificates/{certificateId}/reject")
    public ResponseEntity<CertificateApprovalResponse> rejectCertificate(
            @PathVariable Long certificateId) {
        
        Certificate certificate = adminReviewService.rejectCertificate(certificateId);

        return ResponseEntity.ok(new CertificateApprovalResponse(
                certificate.getCertificateId(),
                certificate.getApprovalStatus().name(),
                "수료증이 반려되었습니다. 반려 이메일이 발송됩니다."
        ));
    }

    @Operation(summary = "[2단계] 후기 상세 조회")
    @GetMapping("/reviews/{reviewId}")
    public ResponseEntity<AdminReviewDetailResponse> getReviewDetail(
            @PathVariable Long reviewId) {
        
        Review review = adminReviewService.getReview(reviewId);
        
        return ResponseEntity.ok(toDetailResponse(review));
    }

    @Operation(summary = "[2단계] 후기 승인")
    @PatchMapping("/reviews/{reviewId}/approve")
    public ResponseEntity<ReviewApprovalResponse> approveReview(
            @PathVariable Long reviewId) {
        
        Review review = adminReviewService.approveReview(reviewId);

        return ResponseEntity.ok(new ReviewApprovalResponse(
                review.getReviewId(),
                review.getApprovalStatus().name(),
                "후기가 승인되었습니다. 일반 사용자에게 노출됩니다."
        ));
    }

    @Operation(summary = "[2단계] 후기 반려 (반려 이메일 발송)")
    @PatchMapping("/reviews/{reviewId}/reject")
    public ResponseEntity<ReviewApprovalResponse> rejectReview(
            @PathVariable Long reviewId) {
        
        Review review = adminReviewService.rejectReview(reviewId);

        return ResponseEntity.ok(new ReviewApprovalResponse(
                review.getReviewId(),
                review.getApprovalStatus().name(),
                "후기가 반려되었습니다. 반려 이메일이 발송됩니다."
        ));
    }

    @Operation(summary = "후기 블라인드 처리")
    @PatchMapping("/reviews/{reviewId}/blind")
    public ResponseEntity<ReviewApprovalResponse> blindReview(
            @PathVariable Long reviewId,
            @Valid @RequestBody BlindReviewRequest request) {
        
        Review review = adminReviewService.blindReview(reviewId, request.blurred());

        String message = request.blurred() 
                ? "후기가 블라인드 처리되었습니다" 
                : "블라인드가 해제되었습니다";

        return ResponseEntity.ok(new ReviewApprovalResponse(
                review.getReviewId(),
                review.getApprovalStatus().name(),
                message
        ));
    }

    private AdminReviewListResponse.AdminReviewSummary toSummary(Review review) {
        String lectureName = lectureRepository.findById(review.getLectureId())
                .map(Lecture::getName)
                .orElse("알 수 없음");

        Member member = memberRepository.findById(review.getUserId()).orElse(null);
        String userName = member != null ? member.getName() : "알 수 없음";
        String nickname = member != null ? member.getNickname() : "알 수 없음";

        // 수료증 상태 조회
        String certStatus = "PENDING"; // 실제로는 certificateRepository에서 조회 필요

        return new AdminReviewListResponse.AdminReviewSummary(
                review.getReviewId(),
                review.getLectureId(),
                lectureName,
                review.getUserId(),
                userName,
                nickname,
                review.getScore(),
                certStatus,
                review.getApprovalStatus().name(),
                review.getCreatedAt().format(FORMATTER)
        );
    }

    private AdminReviewDetailResponse toDetailResponse(Review review) {
        String lectureName = lectureRepository.findById(review.getLectureId())
                .map(Lecture::getName)
                .orElse("알 수 없음");

        Member member = memberRepository.findById(review.getUserId()).orElse(null);
        String userName = member != null ? member.getName() : "알 수 없음";
        String nickname = member != null ? member.getNickname() : "알 수 없음";

        List<AdminReviewDetailResponse.DetailScore> detailScores = review.getDetails().stream()
                .map(d -> new AdminReviewDetailResponse.DetailScore(
                        d.getCategory().name(), d.getScore()
                ))
                .collect(Collectors.toList());

        return new AdminReviewDetailResponse(
                review.getReviewId(),
                review.getLectureId(),
                lectureName,
                review.getUserId(),
                userName,
                nickname,
                review.getComment(),
                review.getScore(),
                review.getApprovalStatus().name(),
                "APPROVED", // 2단계에서는 수료증이 이미 승인된 상태
                detailScores,
                review.getCreatedAt().format(FORMATTER)
        );
    }
}
```

---

## 4. 설정

### 4.1 @Async 활성화

```java
package com.swcampus.api.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

@Configuration
@EnableAsync
public class AsyncConfig {
}
```

---

## API 엔드포인트 요약

| 기능 | Method | Endpoint |
|------|--------|----------|
| 대기 중 후기 목록 | GET | `/api/v1/admin/reviews` |
| 수료증 조회 | GET | `/api/v1/admin/certificates/{certificateId}` |
| 수료증 승인 | PATCH | `/api/v1/admin/certificates/{certificateId}/approve` |
| 수료증 반려 | PATCH | `/api/v1/admin/certificates/{certificateId}/reject` |
| 후기 상세 조회 | GET | `/api/v1/admin/reviews/{reviewId}` |
| 후기 승인 | PATCH | `/api/v1/admin/reviews/{reviewId}/approve` |
| 후기 반려 | PATCH | `/api/v1/admin/reviews/{reviewId}/reject` |
| 블라인드 처리 | PATCH | `/api/v1/admin/reviews/{reviewId}/blind` |

---

## 체크리스트

- [ ] AdminReviewService 구현
- [ ] EmailService 인터페이스 생성 (domain)
- [ ] EmailServiceImpl 구현 (infra)
- [ ] BlindReviewRequest DTO 생성
- [ ] AdminReviewListResponse DTO 생성
- [ ] AdminCertificateResponse DTO 생성
- [ ] AdminReviewDetailResponse DTO 생성
- [ ] CertificateApprovalResponse DTO 생성
- [ ] ReviewApprovalResponse DTO 생성
- [ ] AdminReviewController 구현
- [ ] @PreAuthorize("hasRole('ADMIN')") 적용
- [ ] @Async 이메일 발송 설정
- [ ] application.yml 메일 설정 추가
- [ ] 컴파일 및 API 테스트
