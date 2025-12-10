# Phase 01: 기반 구조

> Domain, Entity, Repository 기반 구조 생성

## 목표

- Review, Certificate 도메인 객체 생성
- Enum 정의 (ApprovalStatus, ReviewCategory)
- Repository 인터페이스 및 구현체 생성
- ErrorCode 추가

---

## 1. Domain 모듈

### 1.1 Enum 정의

#### ApprovalStatus.java
```java
package com.swcampus.domain.review;

public enum ApprovalStatus {
    PENDING(0),    // 대기
    APPROVED(1),   // 승인
    REJECTED(2);   // 반려

    private final int value;

    ApprovalStatus(int value) {
        this.value = value;
    }

    public int getValue() {
        return value;
    }

    public static ApprovalStatus fromValue(int value) {
        for (ApprovalStatus status : values()) {
            if (status.value == value) {
                return status;
            }
        }
        throw new IllegalArgumentException("Unknown ApprovalStatus value: " + value);
    }
}
```

#### ReviewCategory.java
```java
package com.swcampus.domain.review;

public enum ReviewCategory {
    TEACHER,      // 강사
    CURRICULUM,   // 커리큘럼
    MANAGEMENT,   // 취업지원/행정
    FACILITY,     // 시설
    PROJECT       // 프로젝트
}
```

### 1.2 Domain 객체

#### Certificate.java
```java
package com.swcampus.domain.certificate;

import com.swcampus.domain.review.ApprovalStatus;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Certificate {
    private Long certificateId;
    private Long userId;
    private Long lectureId;
    private String imageUrl;
    private String status;  // OCR 인증 결과 ("SUCCESS", "FAIL" 등)
    private ApprovalStatus approvalStatus;  // 관리자 승인 상태
    private LocalDateTime createdAt;

    public static Certificate create(Long userId, Long lectureId, String imageUrl, String status) {
        Certificate certificate = new Certificate();
        certificate.userId = userId;
        certificate.lectureId = lectureId;
        certificate.imageUrl = imageUrl;
        certificate.status = status;
        certificate.approvalStatus = ApprovalStatus.PENDING;
        return certificate;
    }

    public static Certificate of(Long certificateId, Long userId, Long lectureId, 
                                  String imageUrl, String status,
                                  ApprovalStatus approvalStatus, LocalDateTime createdAt) {
        Certificate certificate = new Certificate();
        certificate.certificateId = certificateId;
        certificate.userId = userId;
        certificate.lectureId = lectureId;
        certificate.imageUrl = imageUrl;
        certificate.status = status;
        certificate.approvalStatus = approvalStatus;
        certificate.createdAt = createdAt;
        return certificate;
    }

    public void approve() {
        this.approvalStatus = ApprovalStatus.APPROVED;
    }

    public void reject() {
        this.approvalStatus = ApprovalStatus.REJECTED;
    }

    public boolean isPending() {
        return this.approvalStatus == ApprovalStatus.PENDING;
    }

    public boolean isApproved() {
        return this.approvalStatus == ApprovalStatus.APPROVED;
    }
}
```

#### ReviewDetail.java
```java
package com.swcampus.domain.review;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ReviewDetail {
    private Long reviewDetailId;
    private Long reviewId;
    private ReviewCategory category;
    private Double score;
    private String comment;  // 카테고리별 후기 (20~500자), DB: DETAIL_COMMENT

    public static ReviewDetail create(ReviewCategory category, Double score, String comment) {
        ReviewDetail detail = new ReviewDetail();
        detail.category = category;
        detail.score = score;
        detail.comment = comment;
        return detail;
    }

    public static ReviewDetail of(Long reviewDetailId, Long reviewId, ReviewCategory category, 
                                   Double score, String comment) {
        ReviewDetail detail = new ReviewDetail();
        detail.reviewDetailId = reviewDetailId;
        detail.reviewId = reviewId;
        detail.category = category;
        detail.score = score;
        detail.comment = comment;
        return detail;
    }
}
```

#### Review.java
```java
package com.swcampus.domain.review;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Review {
    private Long reviewId;
    private Long userId;
    private Long lectureId;
    private Long certificateId;
    private String comment;           // 총평 (optional, max 500자)
    private Double score;             // 카테고리 점수 평균
    private ApprovalStatus approvalStatus;
    private boolean blurred;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private List<ReviewDetail> details = new ArrayList<>();

    public static Review create(Long userId, Long lectureId, Long certificateId,
                                 String comment, List<ReviewDetail> details) {
        Review review = new Review();
        review.userId = userId;
        review.lectureId = lectureId;
        review.certificateId = certificateId;
        review.comment = comment;
        review.details = details;
        review.score = calculateAverageScore(details);
        review.approvalStatus = ApprovalStatus.PENDING;
        review.blurred = false;
        review.createdAt = LocalDateTime.now();
        review.updatedAt = LocalDateTime.now();
        return review;
    }

    public static Review of(Long reviewId, Long userId, Long lectureId, Long certificateId,
                            String comment, Double score, ApprovalStatus approvalStatus,
                            boolean blurred, LocalDateTime createdAt, LocalDateTime updatedAt,
                            List<ReviewDetail> details) {
        Review review = new Review();
        review.reviewId = reviewId;
        review.userId = userId;
        review.lectureId = lectureId;
        review.certificateId = certificateId;
        review.comment = comment;
        review.score = score;
        review.approvalStatus = approvalStatus;
        review.blurred = blurred;
        review.createdAt = createdAt;
        review.updatedAt = updatedAt;
        review.details = details;
        return review;
    }

    public void update(String comment, List<ReviewDetail> details) {
        this.comment = comment;
        this.details = details;
        this.score = calculateAverageScore(details);
        this.updatedAt = LocalDateTime.now();
    }

    public void approve() {
        this.approvalStatus = ApprovalStatus.APPROVED;
    }

    public void reject() {
        this.approvalStatus = ApprovalStatus.REJECTED;
    }

    public void blind() {
        this.blurred = true;
    }

    public void unblind() {
        this.blurred = false;
    }

    public boolean isPending() {
        return this.approvalStatus == ApprovalStatus.PENDING;
    }

    public boolean isApproved() {
        return this.approvalStatus == ApprovalStatus.APPROVED;
    }

    private static Double calculateAverageScore(List<ReviewDetail> details) {
        if (details == null || details.isEmpty()) {
            return 0.0;
        }
        double sum = details.stream()
                .mapToDouble(ReviewDetail::getScore)
                .sum();
        return Math.round(sum / details.size() * 10) / 10.0;
    }
}
```

### 1.3 Repository 인터페이스

#### CertificateRepository.java
```java
package com.swcampus.domain.certificate;

import java.util.Optional;

public interface CertificateRepository {
    Certificate save(Certificate certificate);
    Optional<Certificate> findById(Long certificateId);
    Optional<Certificate> findByUserIdAndLectureId(Long userId, Long lectureId);
    boolean existsByUserIdAndLectureId(Long userId, Long lectureId);
}
```

#### ReviewRepository.java
```java
package com.swcampus.domain.review;

import java.util.List;
import java.util.Optional;

public interface ReviewRepository {
    Review save(Review review);
    Optional<Review> findById(Long reviewId);
    Optional<Review> findByUserIdAndLectureId(Long userId, Long lectureId);
    boolean existsByUserIdAndLectureId(Long userId, Long lectureId);
    List<Review> findByLectureIdAndApprovalStatus(Long lectureId, ApprovalStatus status);
    List<Review> findByApprovalStatus(ApprovalStatus status);
    List<Review> findPendingReviews(); // 수료증 또는 후기가 PENDING
}
```

### 1.4 예외 클래스

#### CertificateNotFoundException.java
```java
package com.swcampus.domain.certificate.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class CertificateNotFoundException extends BusinessException {
    public CertificateNotFoundException() {
        super(ErrorCode.CERTIFICATE_NOT_FOUND);
    }
}
```

#### CertificateAlreadyVerifiedException.java
```java
package com.swcampus.domain.certificate.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class CertificateAlreadyVerifiedException extends BusinessException {
    public CertificateAlreadyVerifiedException() {
        super(ErrorCode.CERTIFICATE_ALREADY_VERIFIED);
    }
}
```

#### ReviewNotFoundException.java
```java
package com.swcampus.domain.review.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class ReviewNotFoundException extends BusinessException {
    public ReviewNotFoundException() {
        super(ErrorCode.REVIEW_NOT_FOUND);
    }
}
```

#### ReviewAlreadyExistsException.java
```java
package com.swcampus.domain.review.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class ReviewAlreadyExistsException extends BusinessException {
    public ReviewAlreadyExistsException() {
        super(ErrorCode.REVIEW_ALREADY_EXISTS);
    }
}
```

---

## 2. Shared 모듈

### 2.1 ErrorCode 추가

```java
// ErrorCode.java에 추가
// Certificate
CERTIFICATE_NOT_FOUND(404, "CERT001", "수료증을 찾을 수 없습니다"),
CERTIFICATE_ALREADY_VERIFIED(409, "CERT002", "이미 인증된 수료증입니다"),
CERTIFICATE_INVALID_IMAGE(400, "CERT003", "올바르지 않은 이미지 형식입니다"),
CERTIFICATE_LECTURE_MISMATCH(400, "CERT004", "해당 강의의 수료증이 아닙니다"),
CERTIFICATE_NOT_VERIFIED(403, "CERT005", "수료증 인증이 필요합니다"),

// Review
REVIEW_NOT_FOUND(404, "REV001", "후기를 찾을 수 없습니다"),
REVIEW_ALREADY_EXISTS(409, "REV002", "이미 후기를 작성한 강의입니다"),
REVIEW_NOT_OWNER(403, "REV003", "본인의 후기만 수정할 수 있습니다"),
REVIEW_INVALID_STATUS(400, "REV004", "후기 상태가 올바르지 않습니다"),
REVIEW_NICKNAME_REQUIRED(403, "REV005", "닉네임 설정이 필요합니다"),
```

---

## 3. Infra 모듈 (db-postgres)

### 3.1 Entity 클래스

#### CertificateEntity.java
```java
package com.swcampus.infra.postgres.certificate;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "CERTIFICATES")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CertificateEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "CERTIFICATE_ID")
    private Long certificateId;

    @Column(name = "USER_ID", nullable = false)
    private Long userId;

    @Column(name = "LECTURE_ID", nullable = false)
    private Long lectureId;

    @Column(name = "STATUS", nullable = false)
    private String status;  // 기존: OCR 인증 결과 ("SUCCESS", "FAIL" 등)

    @Column(name = "IMAGE_URL")
    private String imageUrl;

    @Column(name = "APPROVAL_STATUS", nullable = false)
    private Integer approvalStatus;  // 신규: 관리자 승인 상태 (0: PENDING, 1: APPROVED, 2: REJECTED)

    @CreationTimestamp
    @Column(name = "CREATED_AT")
    private LocalDateTime createdAt;  // 신규: 인증 일시

    public static CertificateEntity of(Long userId, Long lectureId, 
                                        String imageUrl, String status,
                                        Integer approvalStatus) {
        CertificateEntity entity = new CertificateEntity();
        entity.userId = userId;
        entity.lectureId = lectureId;
        entity.imageUrl = imageUrl;
        entity.status = status;
        entity.approvalStatus = approvalStatus;
        return entity;
    }

    public void updateApprovalStatus(Integer approvalStatus) {
        this.approvalStatus = approvalStatus;
    }
}
```

#### ReviewEntity.java
```java
package com.swcampus.infra.postgres.review;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "REVIEWS")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ReviewEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "REVIEW_ID")
    private Long reviewId;

    @Column(name = "LECTURE_ID", nullable = false)
    private Long lectureId;

    @Column(name = "USER_ID", nullable = false)
    private Long userId;

    @Column(name = "CERTIFICATE_ID")  // 신규: 수료증 연결
    private Long certificateId;

    @Column(name = "COMMENT", columnDefinition = "TEXT")
    private String comment;  // 총평 (선택사항, 최대 500자)

    @Column(name = "SCORE", precision = 2, scale = 1)
    private Double score;  // 상세 별점 평균

    @Column(name = "BLURRED")
    private Boolean blurred;

    @Column(name = "APPROVAL_STATUS", nullable = false)
    private Integer approvalStatus;  // 0: PENDING, 1: APPROVED, 2: REJECTED

    @CreationTimestamp
    @Column(name = "CREATED_AT")
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "UPDATED_AT")
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "review", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ReviewDetailEntity> details = new ArrayList<>();

    public static ReviewEntity of(Long userId, Long lectureId, Long certificateId,
                                   String comment, Double score, Integer approvalStatus,
                                   Boolean blurred) {
        ReviewEntity entity = new ReviewEntity();
        entity.userId = userId;
        entity.lectureId = lectureId;
        entity.certificateId = certificateId;
        entity.comment = comment;
        entity.score = score;
        entity.approvalStatus = approvalStatus;
        entity.blurred = blurred;
        return entity;
    }

    public void update(String comment, Double score) {
        this.comment = comment;
        this.score = score;
    }

    public void updateApprovalStatus(Integer approvalStatus) {
        this.approvalStatus = approvalStatus;
    }

    public void updateBlurred(Boolean blurred) {
        this.blurred = blurred;
    }

    public void addDetail(ReviewDetailEntity detail) {
        this.details.add(detail);
        detail.setReview(this);
    }

    public void clearDetails() {
        this.details.clear();
    }
}
```

#### ReviewDetailEntity.java
```java
package com.swcampus.infra.postgres.review;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "REVIEWS_DETAILS")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ReviewDetailEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "REVEIW_DETAIL_ID")  // 원본 SQL 오타 유지
    private Long reviewDetailId;

    @Setter
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "REVIEW_ID", nullable = false)
    private ReviewEntity review;

    @Column(name = "CATEGORY")
    private String category;

    @Column(name = "SCORE", precision = 2, scale = 1)
    private Double score;

    @Column(name = "DETAIL_COMMENT", columnDefinition = "TEXT")
    private String detailComment;  // 카테고리별 후기 (20~500자)

    public static ReviewDetailEntity of(String category, Double score, String detailComment) {
        ReviewDetailEntity entity = new ReviewDetailEntity();
        entity.category = category;
        entity.score = score;
        entity.detailComment = detailComment;
        return entity;
    }
}
```

### 3.2 JPA Repository

#### CertificateJpaRepository.java
```java
package com.swcampus.infra.postgres.certificate;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CertificateJpaRepository extends JpaRepository<CertificateEntity, Long> {
    Optional<CertificateEntity> findByUserIdAndLectureId(Long userId, Long lectureId);
    boolean existsByUserIdAndLectureId(Long userId, Long lectureId);
}
```

#### ReviewJpaRepository.java
```java
package com.swcampus.infra.postgres.review;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ReviewJpaRepository extends JpaRepository<ReviewEntity, Long> {
    Optional<ReviewEntity> findByUserIdAndLectureId(Long userId, Long lectureId);
    boolean existsByUserIdAndLectureId(Long userId, Long lectureId);
    List<ReviewEntity> findByLectureIdAndApprovalStatus(Long lectureId, Integer approvalStatus);
    List<ReviewEntity> findByApprovalStatus(Integer approvalStatus);
    
    @Query("SELECT r FROM ReviewEntity r " +
           "JOIN CertificateEntity c ON r.certificateId = c.certificateId " +
           "WHERE r.approvalStatus = 0 OR c.approvalStatus = 0")
    List<ReviewEntity> findPendingReviews();
}
```

#### ReviewDetailJpaRepository.java
```java
package com.swcampus.infra.postgres.review;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ReviewDetailJpaRepository extends JpaRepository<ReviewDetailEntity, Long> {
    List<ReviewDetailEntity> findByReview_ReviewId(Long reviewId);
    void deleteByReview_ReviewId(Long reviewId);
}
```

### 3.3 Repository 구현체

#### CertificateEntityRepository.java
```java
package com.swcampus.infra.postgres.certificate;

import com.swcampus.domain.certificate.Certificate;
import com.swcampus.domain.certificate.CertificateRepository;
import com.swcampus.domain.review.ApprovalStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class CertificateEntityRepository implements CertificateRepository {

    private final CertificateJpaRepository jpaRepository;

    @Override
    public Certificate save(Certificate certificate) {
        CertificateEntity entity = toEntity(certificate);
        CertificateEntity saved = jpaRepository.save(entity);
        return toDomain(saved);
    }

    @Override
    public Optional<Certificate> findById(Long id) {
        return jpaRepository.findById(id).map(this::toDomain);
    }

    @Override
    public Optional<Certificate> findByUserIdAndLectureId(Long userId, Long lectureId) {
        return jpaRepository.findByUserIdAndLectureId(userId, lectureId)
                .map(this::toDomain);
    }

    @Override
    public boolean existsByUserIdAndLectureId(Long userId, Long lectureId) {
        return jpaRepository.existsByUserIdAndLectureId(userId, lectureId);
    }

    private CertificateEntity toEntity(Certificate domain) {
        return CertificateEntity.of(
                domain.getUserId(),
                domain.getLectureId(),
                domain.getImageUrl(),
                domain.getStatus(),
                domain.getApprovalStatus().getValue()
        );
    }

    private Certificate toDomain(CertificateEntity entity) {
        return Certificate.of(
                entity.getCertificateId(),
                entity.getUserId(),
                entity.getLectureId(),
                entity.getImageUrl(),
                entity.getStatus(),
                ApprovalStatus.fromValue(entity.getApprovalStatus()),
                entity.getCreatedAt()
        );
    }
}
```

#### ReviewEntityRepository.java
```java
package com.swcampus.infra.postgres.review;

import com.swcampus.domain.review.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Repository
@RequiredArgsConstructor
public class ReviewEntityRepository implements ReviewRepository {

    private final ReviewJpaRepository jpaRepository;
    private final ReviewDetailJpaRepository detailJpaRepository;

    @Override
    public Review save(Review review) {
        ReviewEntity entity = toEntity(review);
        
        // 상세 점수 및 후기 추가
        for (ReviewDetail detail : review.getDetails()) {
            ReviewDetailEntity detailEntity = ReviewDetailEntity.of(
                    detail.getCategory().name(),
                    detail.getScore(),
                    detail.getComment()
            );
            entity.addDetail(detailEntity);
        }
        
        ReviewEntity saved = jpaRepository.save(entity);
        return toDomain(saved);
    }

    @Override
    public Optional<Review> findById(Long id) {
        return jpaRepository.findById(id).map(this::toDomain);
    }

    @Override
    public Optional<Review> findByUserIdAndLectureId(Long userId, Long lectureId) {
        return jpaRepository.findByUserIdAndLectureId(userId, lectureId)
                .map(this::toDomain);
    }

    @Override
    public boolean existsByUserIdAndLectureId(Long userId, Long lectureId) {
        return jpaRepository.existsByUserIdAndLectureId(userId, lectureId);
    }

    @Override
    public List<Review> findByLectureIdAndApprovalStatus(Long lectureId, ApprovalStatus status) {
        return jpaRepository.findByLectureIdAndApprovalStatus(lectureId, status.getValue())
                .stream()
                .map(this::toDomain)
                .collect(Collectors.toList());
    }

    @Override
    public List<Review> findByApprovalStatus(ApprovalStatus status) {
        return jpaRepository.findByApprovalStatus(status.getValue())
                .stream()
                .map(this::toDomain)
                .collect(Collectors.toList());
    }

    @Override
    public List<Review> findPendingReviews() {
        return jpaRepository.findPendingReviews()
                .stream()
                .map(this::toDomain)
                .collect(Collectors.toList());
    }

    private ReviewEntity toEntity(Review domain) {
        return ReviewEntity.of(
                domain.getUserId(),
                domain.getLectureId(),
                domain.getCertificateId(),
                domain.getComment(),
                domain.getScore(),
                domain.getApprovalStatus().getValue(),
                domain.isBlurred()
        );
    }

    private Review toDomain(ReviewEntity entity) {
        List<ReviewDetail> details = entity.getDetails().stream()
                .map(d -> ReviewDetail.of(
                        d.getReviewDetailId(),
                        entity.getReviewId(),
                        ReviewCategory.valueOf(d.getCategory()),
                        d.getScore(),
                        d.getDetailComment()
                ))
                .collect(Collectors.toList());

        return Review.of(
                entity.getReviewId(),
                entity.getUserId(),
                entity.getLectureId(),
                entity.getCertificateId(),
                entity.getComment(),
                entity.getScore(),
                ApprovalStatus.fromValue(entity.getApprovalStatus()),
                entity.getBlurred(),
                entity.getCreatedAt(),
                entity.getUpdatedAt(),
                details
        );
    }
}
```

---

## 체크리스트

- [ ] Enum (ApprovalStatus, ReviewCategory) 생성
- [ ] Domain 객체 (Certificate, Review, ReviewDetail) 생성
- [ ] Repository 인터페이스 생성
- [ ] 예외 클래스 생성
- [ ] ErrorCode 추가
- [ ] JPA Entity 생성
- [ ] JPA Repository 생성
- [ ] Repository 구현체 생성
- [ ] 컴파일 확인
