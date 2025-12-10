# Phase 03: 후기 CRUD API

> 후기 작성/수정/조회 API 구현

## 목표

- 후기 작성 가능 여부 확인 API
- 후기 작성 API
- 후기 수정 API
- 닉네임 검증 로직 (JWT hasNickname)

---

## 1. Domain 모듈

### 1.1 ReviewService.java

```java
package com.swcampus.domain.review;

import com.swcampus.domain.certificate.Certificate;
import com.swcampus.domain.certificate.CertificateRepository;
import com.swcampus.domain.certificate.exception.CertificateNotVerifiedException;
import com.swcampus.domain.member.Member;
import com.swcampus.domain.member.MemberRepository;
import com.swcampus.domain.member.exception.MemberNotFoundException;
import com.swcampus.domain.review.exception.ReviewAlreadyExistsException;
import com.swcampus.domain.review.exception.ReviewNotFoundException;
import com.swcampus.domain.review.exception.ReviewNotOwnerException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final CertificateRepository certificateRepository;
    private final MemberRepository memberRepository;

    /**
     * 후기 작성 가능 여부 확인
     */
    public ReviewEligibility checkEligibility(Long memberId, Long lectureId) {
        // 1. 회원 정보 확인
        Member member = memberRepository.findById(memberId)
                .orElseThrow(MemberNotFoundException::new);

        // 2. 닉네임 설정 여부
        boolean hasNickname = member.getNickname() != null && 
                              !member.getNickname().isBlank();

        // 3. 수료증 인증 여부
        Optional<Certificate> certificate = certificateRepository
                .findByMemberIdAndLectureId(memberId, lectureId);
        boolean hasCertificate = certificate.isPresent();

        // 4. 기존 후기 존재 여부
        boolean hasReview = reviewRepository.existsByMemberIdAndLectureId(memberId, lectureId);

        return new ReviewEligibility(
                hasNickname,
                hasCertificate,
                !hasReview,
                hasNickname && hasCertificate && !hasReview
        );
    }

    /**
     * 후기 작성
     */
    @Transactional
    public Review createReview(Long memberId, Long lectureId, 
                                String comment, List<ReviewDetail> details) {
        // 1. 수료증 인증 확인
        Certificate certificate = certificateRepository
                .findByMemberIdAndLectureId(memberId, lectureId)
                .orElseThrow(CertificateNotVerifiedException::new);

        // 2. 중복 후기 확인
        if (reviewRepository.existsByMemberIdAndLectureId(memberId, lectureId)) {
            throw new ReviewAlreadyExistsException();
        }

        // 3. 후기 생성
        Review review = Review.create(
                memberId, 
                lectureId, 
                certificate.getCertificateId(), 
                comment, 
                details
        );

        return reviewRepository.save(review);
    }

    /**
     * 후기 수정
     */
    @Transactional
    public Review updateReview(Long memberId, Long reviewId, 
                                String comment, List<ReviewDetail> details) {
        // 1. 후기 조회
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(ReviewNotFoundException::new);

        // 2. 작성자 확인
        if (!review.getMemberId().equals(memberId)) {
            throw new ReviewNotOwnerException();
        }

        // 3. 후기 수정
        review.update(comment, details);

        return reviewRepository.save(review);
    }

    /**
     * 후기 상세 조회
     */
    public Review getReview(Long reviewId) {
        return reviewRepository.findById(reviewId)
                .orElseThrow(ReviewNotFoundException::new);
    }

    /**
     * 강의별 승인된 후기 목록 조회
     */
    public List<Review> getApprovedReviewsByLecture(Long lectureId) {
        return reviewRepository.findByLectureIdAndApprovalStatus(
                lectureId, ApprovalStatus.APPROVED
        );
    }
}
```

### 1.2 ReviewEligibility DTO

```java
package com.swcampus.domain.review;

public record ReviewEligibility(
    boolean hasNickname,
    boolean hasCertificate,
    boolean canWrite,       // 기존 후기 없음
    boolean eligible        // 모든 조건 충족
) {}
```

### 1.3 추가 예외 클래스

#### ReviewNotOwnerException.java
```java
package com.swcampus.domain.review.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class ReviewNotOwnerException extends BusinessException {
    public ReviewNotOwnerException() {
        super(ErrorCode.REVIEW_NOT_OWNER);
    }
}
```

#### CertificateNotVerifiedException.java
```java
package com.swcampus.domain.certificate.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class CertificateNotVerifiedException extends BusinessException {
    public CertificateNotVerifiedException() {
        super(ErrorCode.CERTIFICATE_NOT_VERIFIED);
    }
}
```

---

## 2. API 모듈

### 2.1 Request DTO

#### CreateReviewRequest.java
```java
package com.swcampus.api.review.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.List;

public record CreateReviewRequest(
    @NotNull(message = "강의 ID는 필수입니다")
    Long lectureId,

    @Size(max = 500, message = "총평은 최대 500자입니다")
    String comment,  // 총평 (선택사항, 최대 500자)

    @NotNull(message = "상세 점수는 필수입니다")
    @Size(min = 5, max = 5, message = "상세 점수는 5개 카테고리 모두 필요합니다")
    @Valid
    List<DetailScoreRequest> detailScores
) {}
```

#### DetailScoreRequest.java
```java
package com.swcampus.api.review.request;

import jakarta.validation.constraints.*;

public record DetailScoreRequest(
    @NotNull(message = "카테고리는 필수입니다")
    String category,

    @NotNull(message = "점수는 필수입니다")
    @DecimalMin(value = "1.0", message = "점수는 1.0 이상이어야 합니다")
    @DecimalMax(value = "5.0", message = "점수는 5.0 이하여야 합니다")
    Double score,

    @NotBlank(message = "카테고리별 후기는 필수입니다")
    @Size(min = 20, max = 500, message = "카테고리별 후기는 20~500자입니다")
    String comment  // 카테고리별 후기 (필수, 20~500자)
) {}
```

#### UpdateReviewRequest.java
```java
package com.swcampus.api.review.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.List;

public record UpdateReviewRequest(
    @Size(max = 500, message = "총평은 최대 500자입니다")
    String comment,  // 총평 (선택사항, 최대 500자)

    @NotNull(message = "상세 점수는 필수입니다")
    @Size(min = 5, max = 5, message = "상세 점수는 5개 카테고리 모두 필요합니다")
    @Valid
    List<DetailScoreRequest> detailScores
) {}
```

### 2.2 Response DTO

#### ReviewEligibilityResponse.java
```java
package com.swcampus.api.review.response;

public record ReviewEligibilityResponse(
    boolean hasNickname,
    boolean hasCertificate,
    boolean canWrite,
    boolean eligible,
    String message
) {
    public static ReviewEligibilityResponse from(
            boolean hasNickname, boolean hasCertificate, 
            boolean canWrite, boolean eligible) {
        
        String message;
        if (!hasNickname) {
            message = "닉네임 설정이 필요합니다";
        } else if (!hasCertificate) {
            message = "수료증 인증이 필요합니다";
        } else if (!canWrite) {
            message = "이미 후기를 작성한 강의입니다";
        } else {
            message = "후기 작성이 가능합니다";
        }
        
        return new ReviewEligibilityResponse(
                hasNickname, hasCertificate, canWrite, eligible, message
        );
    }
}
```

#### ReviewResponse.java
```java
package com.swcampus.api.review.response;

import java.util.List;

public record ReviewResponse(
    Long reviewId,
    Long lectureId,
    String lectureName,
    Long memberId,
    String nickname,
    String comment,    // 총평 (nullable)
    Double score,
    List<DetailScoreResponse> detailScores,
    String approvalStatus,
    boolean blurred,
    String createdAt,
    String updatedAt
) {}
```

#### DetailScoreResponse.java
```java
package com.swcampus.api.review.response;

public record DetailScoreResponse(
    String category,
    Double score,
    String comment  // 카테고리별 후기
) {}
```

### 2.3 Controller

#### ReviewController.java
```java
package com.swcampus.api.review;

import com.swcampus.api.review.request.CreateReviewRequest;
import com.swcampus.api.review.request.UpdateReviewRequest;
import com.swcampus.api.review.response.ReviewEligibilityResponse;
import com.swcampus.api.review.response.ReviewResponse;
import com.swcampus.api.review.response.DetailScoreResponse;
import com.swcampus.domain.review.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

@Tag(name = "Review", description = "후기 API")
@RestController
@RequestMapping("/api/v1/reviews")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;
    private static final DateTimeFormatter FORMATTER = 
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    @Operation(summary = "후기 작성 가능 여부 확인")
    @SecurityRequirement(name = "cookieAuth")
    @GetMapping("/eligibility")
    public ResponseEntity<ReviewEligibilityResponse> checkEligibility(
            @AuthenticationPrincipal Long memberId,
            @RequestParam Long lectureId) {

        ReviewEligibility eligibility = reviewService.checkEligibility(memberId, lectureId);

        return ResponseEntity.ok(ReviewEligibilityResponse.from(
                eligibility.hasNickname(),
                eligibility.hasCertificate(),
                eligibility.canWrite(),
                eligibility.eligible()
        ));
    }

    @Operation(summary = "후기 작성")
    @SecurityRequirement(name = "cookieAuth")
    @PostMapping
    public ResponseEntity<ReviewResponse> createReview(
            @AuthenticationPrincipal Long memberId,
            @Valid @RequestBody CreateReviewRequest request) {

        List<ReviewDetail> details = request.detailScores().stream()
                .map(d -> ReviewDetail.create(
                        ReviewCategory.valueOf(d.category()),
                        d.score(),
                        d.comment()
                ))
                .collect(Collectors.toList());

        Review review = reviewService.createReview(
                memberId,
                request.lectureId(),
                request.comment(),
                details
        );

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(toResponse(review));
    }

    @Operation(summary = "후기 수정")
    @SecurityRequirement(name = "cookieAuth")
    @PutMapping("/{reviewId}")
    public ResponseEntity<ReviewResponse> updateReview(
            @AuthenticationPrincipal Long memberId,
            @PathVariable Long reviewId,
            @Valid @RequestBody UpdateReviewRequest request) {

        List<ReviewDetail> details = request.detailScores().stream()
                .map(d -> ReviewDetail.create(
                        ReviewCategory.valueOf(d.category()),
                        d.score(),
                        d.comment()
                ))
                .collect(Collectors.toList());

        Review review = reviewService.updateReview(
                memberId,
                reviewId,
                request.comment(),
                details
        );

        return ResponseEntity.ok(toResponse(review));
    }

    @Operation(summary = "후기 상세 조회")
    @GetMapping("/{reviewId}")
    public ResponseEntity<ReviewResponse> getReview(@PathVariable Long reviewId) {
        Review review = reviewService.getReview(reviewId);
        return ResponseEntity.ok(toResponse(review));
    }

    private ReviewResponse toResponse(Review review) {
        List<DetailScoreResponse> detailScores = review.getDetails().stream()
                .map(d -> new DetailScoreResponse(
                        d.getCategory().name(), 
                        d.getScore(),
                        d.getComment()
                ))
                .collect(Collectors.toList());

        return new ReviewResponse(
                review.getReviewId(),
                review.getLectureId(),
                null, // lectureName은 별도 조회 필요
                review.getMemberId(),
                null, // nickname은 별도 조회 필요
                review.getComment(),
                review.getScore(),
                detailScores,
                review.getApprovalStatus().name(),
                review.isBlurred(),
                review.getCreatedAt().format(FORMATTER),
                review.getUpdatedAt().format(FORMATTER)
        );
    }
}
```

---

## 3. 닉네임 검증 (JWT hasNickname)

### 3.1 JWT에서 hasNickname 확인

> 기존 JWT 구조에 `hasNickname` 클레임이 있다면 활용
> 없다면 DB 조회로 대체 (현재 구현)

#### 현재 구현 방식 (DB 조회)
```java
// ReviewService.checkEligibility() 내부
Member member = memberRepository.findById(memberId)
        .orElseThrow(MemberNotFoundException::new);

boolean hasNickname = member.getNickname() != null && 
                      !member.getNickname().isBlank();
```

#### JWT 클레임 방식 (향후 개선)
```java
// JwtTokenProvider에서 hasNickname 클레임 추출
public boolean hasNickname(String token) {
    Claims claims = parseClaims(token);
    return claims.get("hasNickname", Boolean.class);
}
```

---

## 체크리스트

- [ ] ReviewService 구현
- [ ] ReviewEligibility DTO 생성
- [ ] ReviewNotOwnerException 생성
- [ ] CertificateNotVerifiedException 생성
- [ ] CreateReviewRequest DTO 생성
- [ ] UpdateReviewRequest DTO 생성
- [ ] ReviewResponse DTO 생성
- [ ] ReviewEligibilityResponse DTO 생성
- [ ] ReviewController 구현
- [ ] Validation 어노테이션 적용
- [ ] 컴파일 및 API 테스트
