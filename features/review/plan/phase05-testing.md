# Phase 05: 테스트 및 검증

> 단위 테스트 및 통합 테스트

## 목표

- Domain 레이어 단위 테스트
- Service 레이어 테스트
- API 통합 테스트
- 시나리오 검증

---

## 1. Domain 레이어 단위 테스트

### 1.1 Review 도메인 테스트

#### ReviewTest.java
```java
package com.swcampus.domain.review;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ReviewTest {

    @Test
    @DisplayName("후기 생성 시 평균 점수가 자동 계산된다")
    void createReview_calculatesAverageScore() {
        // given
        List<ReviewDetail> details = List.of(
                ReviewDetail.create(ReviewCategory.TEACHER, 4.5, "강사님이 친절하고 설명을 잘 해주셨습니다."),
                ReviewDetail.create(ReviewCategory.CURRICULUM, 4.0, "커리큘럼이 체계적이고 실무에 도움됩니다."),
                ReviewDetail.create(ReviewCategory.MANAGEMENT, 4.5, "취업지원과 행정 서비스가 좋았습니다."),
                ReviewDetail.create(ReviewCategory.FACILITY, 3.5, "시설은 보통이었지만 학습에는 문제없었습니다."),
                ReviewDetail.create(ReviewCategory.PROJECT, 5.0, "프로젝트 경험이 정말 유익했습니다.")
        );

        // when
        Review review = Review.create(1L, 1L, 1L, "전체적으로 만족스러운 강의", details);

        // then
        assertThat(review.getScore()).isEqualTo(4.3);
        assertThat(review.getApprovalStatus()).isEqualTo(ApprovalStatus.PENDING);
        assertThat(review.isBlurred()).isFalse();
    }

    @Test
    @DisplayName("후기 수정 시 평균 점수가 재계산된다")
    void updateReview_recalculatesScore() {
        // given
        List<ReviewDetail> initialDetails = List.of(
                ReviewDetail.create(ReviewCategory.TEACHER, 3.0, "보통이었습니다. 개선이 필요해요."),
                ReviewDetail.create(ReviewCategory.CURRICULUM, 3.0, "커리큘럼이 조금 아쉬웠습니다."),
                ReviewDetail.create(ReviewCategory.MANAGEMENT, 3.0, "행정 서비스가 보통이었습니다."),
                ReviewDetail.create(ReviewCategory.FACILITY, 3.0, "시설이 좀 노후되었습니다."),
                ReviewDetail.create(ReviewCategory.PROJECT, 3.0, "프로젝트 피드백이 부족했습니다.")
        );
        Review review = Review.create(1L, 1L, 1L, null, initialDetails);

        List<ReviewDetail> newDetails = List.of(
                ReviewDetail.create(ReviewCategory.TEACHER, 5.0, "강사님이 정말 최고였습니다!"),
                ReviewDetail.create(ReviewCategory.CURRICULUM, 5.0, "커리큘럼이 완벽했습니다!"),
                ReviewDetail.create(ReviewCategory.MANAGEMENT, 5.0, "취업지원이 정말 잘 됩니다!"),
                ReviewDetail.create(ReviewCategory.FACILITY, 5.0, "시설이 깨끗하고 좋았습니다!"),
                ReviewDetail.create(ReviewCategory.PROJECT, 5.0, "프로젝트가 정말 유익했습니다!")
        );

        // when
        review.update("정말 좋았습니다", newDetails);

        // then
        assertThat(review.getScore()).isEqualTo(5.0);
        assertThat(review.getComment()).isEqualTo("정말 좋았습니다");
    }

    @Test
    @DisplayName("후기 승인 시 상태가 APPROVED로 변경된다")
    void approveReview_changesStatusToApproved() {
        // given
        Review review = Review.create(1L, 1L, 1L, "테스트", List.of());

        // when
        review.approve();

        // then
        assertThat(review.getApprovalStatus()).isEqualTo(ApprovalStatus.APPROVED);
        assertThat(review.isApproved()).isTrue();
    }

    @Test
    @DisplayName("후기 블라인드 처리")
    void blindReview_setsBlurredTrue() {
        // given
        Review review = Review.create(1L, 1L, 1L, "테스트", List.of());

        // when
        review.blind();

        // then
        assertThat(review.isBlurred()).isTrue();
    }
}
```

### 1.2 Certificate 도메인 테스트

#### CertificateTest.java
```java
package com.swcampus.domain.certificate;

import com.swcampus.domain.review.ApprovalStatus;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CertificateTest {

    @Test
    @DisplayName("수료증 생성 시 PENDING 상태로 생성된다")
    void createCertificate_statusIsPending() {
        // when
        Certificate certificate = Certificate.create(1L, 1L, "https://s3.../image.jpg", "SUCCESS");

        // then
        assertThat(certificate.getApprovalStatus()).isEqualTo(ApprovalStatus.PENDING);
        assertThat(certificate.isPending()).isTrue();
    }

    @Test
    @DisplayName("수료증 승인 시 APPROVED로 변경된다")
    void approveCertificate_changesStatusToApproved() {
        // given
        Certificate certificate = Certificate.create(1L, 1L, "https://s3.../image.jpg", "SUCCESS");

        // when
        certificate.approve();

        // then
        assertThat(certificate.getApprovalStatus()).isEqualTo(ApprovalStatus.APPROVED);
        assertThat(certificate.isApproved()).isTrue();
    }

    @Test
    @DisplayName("수료증 반려 시 REJECTED로 변경된다")
    void rejectCertificate_changesStatusToRejected() {
        // given
        Certificate certificate = Certificate.create(1L, 1L, "https://s3.../image.jpg", "SUCCESS");

        // when
        certificate.reject();

        // then
        assertThat(certificate.getApprovalStatus()).isEqualTo(ApprovalStatus.REJECTED);
    }
}
```

---

## 2. Service 레이어 테스트

### 2.1 CertificateServiceTest.java

```java
package com.swcampus.domain.certificate;

import com.swcampus.domain.certificate.exception.CertificateAlreadyVerifiedException;
import com.swcampus.domain.certificate.exception.CertificateLectureMismatchException;
import com.swcampus.domain.lecture.Lecture;
import com.swcampus.domain.lecture.LectureRepository;
import com.swcampus.domain.ocr.OcrClient;
import com.swcampus.domain.storage.FileStorageService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class CertificateServiceTest {

    @InjectMocks
    private CertificateService certificateService;

    @Mock
    private CertificateRepository certificateRepository;

    @Mock
    private LectureRepository lectureRepository;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private OcrClient ocrClient;

    @Test
    @DisplayName("이미 인증된 수료증이 있으면 예외 발생")
    void verifyCertificate_alreadyVerified_throwsException() {
        // given
        given(certificateRepository.existsByMemberIdAndLectureId(1L, 1L))
                .willReturn(true);

        // when & then
        assertThatThrownBy(() -> certificateService.verifyCertificate(
                1L, 1L, new byte[0], "test.jpg", "image/jpeg"
        )).isInstanceOf(CertificateAlreadyVerifiedException.class);
    }

    @Test
    @DisplayName("OCR 결과에 강의명이 포함되지 않으면 예외 발생")
    void verifyCertificate_lectureMismatch_throwsException() {
        // given
        given(certificateRepository.existsByMemberIdAndLectureId(1L, 1L))
                .willReturn(false);
        
        Lecture lecture = createLecture("Java 풀스택 개발자 과정");
        given(lectureRepository.findById(1L))
                .willReturn(Optional.of(lecture));
        
        given(ocrClient.extractText(any(), anyString()))
                .willReturn(List.of("Python", "백엔드", "과정"));

        // when & then
        assertThatThrownBy(() -> certificateService.verifyCertificate(
                1L, 1L, new byte[0], "test.jpg", "image/jpeg"
        )).isInstanceOf(CertificateLectureMismatchException.class);
    }

    @Test
    @DisplayName("유연한 매칭: 공백이 다르더라도 강의명 인식 성공")
    void verifyCertificate_flexibleMatching_success() {
        // given
        given(certificateRepository.existsByMemberIdAndLectureId(1L, 1L))
                .willReturn(false);
        
        Lecture lecture = createLecture("Java 풀스택 개발자 과정");
        given(lectureRepository.findById(1L))
                .willReturn(Optional.of(lecture));
        
        // OCR 결과: 공백이 다름
        given(ocrClient.extractText(any(), anyString()))
                .willReturn(List.of("수료증", "Java풀스택개발자과정", "홍길동"));
        
        given(fileStorageService.upload(any(), anyString(), anyString()))
                .willReturn("https://s3.../certificates/test.jpg");
        
        Certificate savedCert = Certificate.create(1L, 1L, "https://s3.../certificates/test.jpg", "SUCCESS");
        given(certificateRepository.save(any()))
                .willReturn(savedCert);

        // when
        Certificate result = certificateService.verifyCertificate(
                1L, 1L, new byte[0], "test.jpg", "image/jpeg"
        );

        // then
        assertThat(result).isNotNull();
        assertThat(result.getApprovalStatus()).isEqualTo(ApprovalStatus.PENDING);
    }

    private Lecture createLecture(String name) {
        // Lecture 생성 헬퍼 메서드
        // 실제 구현에 맞게 수정 필요
        return null; // Lecture.of(1L, name, ...);
    }
}
```

### 2.2 ReviewServiceTest.java

```java
package com.swcampus.domain.review;

import com.swcampus.domain.certificate.Certificate;
import com.swcampus.domain.certificate.CertificateRepository;
import com.swcampus.domain.certificate.exception.CertificateNotVerifiedException;
import com.swcampus.domain.member.Member;
import com.swcampus.domain.member.MemberRepository;
import com.swcampus.domain.review.exception.ReviewAlreadyExistsException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class ReviewServiceTest {

    @InjectMocks
    private ReviewService reviewService;

    @Mock
    private ReviewRepository reviewRepository;

    @Mock
    private CertificateRepository certificateRepository;

    @Mock
    private MemberRepository memberRepository;

    @Test
    @DisplayName("수료증 없이 후기 작성 시 예외 발생")
    void createReview_noCertificate_throwsException() {
        // given
        given(certificateRepository.findByMemberIdAndLectureId(1L, 1L))
                .willReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> reviewService.createReview(
                1L, 1L, "테스트", List.of()
        )).isInstanceOf(CertificateNotVerifiedException.class);
    }

    @Test
    @DisplayName("이미 후기가 있는 강의에 작성 시 예외 발생")
    void createReview_alreadyExists_throwsException() {
        // given
        Certificate certificate = Certificate.create(1L, 1L, "https://s3.../image.jpg", "SUCCESS");
        given(certificateRepository.findByMemberIdAndLectureId(1L, 1L))
                .willReturn(Optional.of(certificate));
        
        given(reviewRepository.existsByMemberIdAndLectureId(1L, 1L))
                .willReturn(true);

        // when & then
        assertThatThrownBy(() -> reviewService.createReview(
                1L, 1L, "테스트", List.of()
        )).isInstanceOf(ReviewAlreadyExistsException.class);
    }

    @Test
    @DisplayName("후기 작성 가능 여부 확인 - 모든 조건 충족")
    void checkEligibility_allConditionsMet_eligible() {
        // given
        Member member = createMemberWithNickname("홍길동");
        given(memberRepository.findById(1L))
                .willReturn(Optional.of(member));
        
        Certificate certificate = Certificate.create(1L, 1L, "https://s3.../image.jpg", "SUCCESS");
        given(certificateRepository.findByMemberIdAndLectureId(1L, 1L))
                .willReturn(Optional.of(certificate));
        
        given(reviewRepository.existsByMemberIdAndLectureId(1L, 1L))
                .willReturn(false);

        // when
        ReviewEligibility eligibility = reviewService.checkEligibility(1L, 1L);

        // then
        assertThat(eligibility.eligible()).isTrue();
        assertThat(eligibility.hasNickname()).isTrue();
        assertThat(eligibility.hasCertificate()).isTrue();
        assertThat(eligibility.canWrite()).isTrue();
    }

    private Member createMemberWithNickname(String nickname) {
        // Member 생성 헬퍼 메서드
        // 실제 구현에 맞게 수정 필요
        return null;
    }
}
```

---

## 3. API 통합 테스트

### 3.1 CertificateControllerTest.java

```java
package com.swcampus.api.certificate;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class CertificateControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("수료증 인증 여부 확인 - 미인증")
    void checkCertificate_notCertified() throws Exception {
        mockMvc.perform(get("/api/v1/certificates/check")
                        .param("lectureId", "1")
                        // .cookie(...) 인증 쿠키 추가
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.certified").value(false));
    }

    @Test
    @DisplayName("수료증 인증 - 성공")
    void verifyCertificate_success() throws Exception {
        MockMultipartFile image = new MockMultipartFile(
                "image",
                "certificate.jpg",
                MediaType.IMAGE_JPEG_VALUE,
                "test image".getBytes()
        );

        mockMvc.perform(multipart("/api/v1/certificates/verify")
                        .file(image)
                        .param("lectureId", "1")
                        // .cookie(...) 인증 쿠키 추가
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.certificateId").exists())
                .andExpect(jsonPath("$.approvalStatus").value("PENDING"));
    }
}
```

### 3.2 ReviewControllerTest.java

```java
package com.swcampus.api.review;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.swcampus.api.review.request.CreateReviewRequest;
import com.swcampus.api.review.request.DetailScoreRequest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class ReviewControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("후기 작성 - 성공")
    void createReview_success() throws Exception {
        CreateReviewRequest request = new CreateReviewRequest(
                1L,
                "정말 좋은 강의였습니다. 추천합니다!",
                List.of(
                        new DetailScoreRequest("TEACHER", 4.5),
                        new DetailScoreRequest("CURRICULUM", 4.0),
                        new DetailScoreRequest("MANAGEMENT", 4.5),
                        new DetailScoreRequest("FACILITY", 3.5),
                        new DetailScoreRequest("PROJECT", 5.0)
                )
        );

        mockMvc.perform(post("/api/v1/reviews")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
                        // .cookie(...) 인증 쿠키 추가
                )
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.reviewId").exists())
                .andExpect(jsonPath("$.score").value(4.3));
    }

    @Test
    @DisplayName("후기 작성 - 유효성 검증 실패")
    void createReview_validationFail() throws Exception {
        CreateReviewRequest request = new CreateReviewRequest(
                1L,
                "짧음", // 10자 미만
                List.of() // 5개 카테고리 필요
        );

        mockMvc.perform(post("/api/v1/reviews")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
                )
                .andExpect(status().isBadRequest());
    }
}
```

---

## 4. 시나리오 검증 체크리스트

### 4.1 사용자 후기 작성 시나리오

```
□ 로그인 없이 접근 시 401 반환
□ 닉네임 없는 사용자가 후기 작성 시도 시 403 반환
□ 수료증 미인증 사용자가 후기 작성 시도 시 403 반환
□ OCR로 강의명 매칭 실패 시 400 반환
□ 이미 후기 작성한 강의에 재작성 시도 시 409 반환
□ 정상 후기 작성 시 201 반환, PENDING 상태
□ 후기 수정 시 본인만 가능 (403)
□ 후기 수정 후 평균 점수 재계산 확인
```

### 4.2 관리자 승인 시나리오

```
□ 일반 사용자가 관리자 API 접근 시 403 반환
□ 대기 중인 후기 목록 조회 정상 동작
□ [1단계] 수료증 승인 → APPROVED 상태 변경
□ [1단계] 수료증 반려 → REJECTED 상태, 이메일 발송
□ [2단계] 후기 승인 → APPROVED 상태, 노출됨
□ [2단계] 후기 반려 → REJECTED 상태, 이메일 발송
□ 블라인드 처리 → blurred: true
□ 블라인드 해제 → blurred: false
```

### 4.3 후기 조회 시나리오

```
□ 일반 사용자는 APPROVED 상태 후기만 조회
□ 블라인드 후기는 목록에 표시되지만 내용 숨김 처리 (프론트엔드)
□ REJECTED 후기는 목록에 미노출
□ PENDING 후기는 목록에 미노출
```

---

## 체크리스트

- [ ] ReviewTest 작성 및 통과
- [ ] CertificateTest 작성 및 통과
- [ ] CertificateServiceTest 작성 및 통과
- [ ] ReviewServiceTest 작성 및 통과
- [ ] CertificateControllerTest 작성
- [ ] ReviewControllerTest 작성
- [ ] AdminReviewControllerTest 작성
- [ ] 시나리오 검증 완료
- [ ] 코드 커버리지 확인 (Domain 90% 목표)
