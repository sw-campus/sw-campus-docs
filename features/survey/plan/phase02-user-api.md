# Phase 02: 사용자 API

> 설문조사 작성, 조회, 수정 API

## 목표

- MemberSurveyService 생성
- 사용자용 CRUD API 구현
- Swagger 문서화

---

## 1. Domain 모듈

### 1.1 Service

#### MemberSurveyService.java
```java
package com.swcampus.domain.survey;

import com.swcampus.domain.survey.exception.SurveyAlreadyExistsException;
import com.swcampus.domain.survey.exception.SurveyNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberSurveyService {

    private final MemberSurveyRepository surveyRepository;

    @Transactional
    public MemberSurvey createSurvey(
            Long userId,
            String major,
            Boolean bootcampCompleted,
            String wantedJobs,
            String licenses,
            Boolean hasGovCard,
            BigDecimal affordableAmount
    ) {
        if (surveyRepository.existsByUserId(userId)) {
            throw new SurveyAlreadyExistsException();
        }

        MemberSurvey survey = MemberSurvey.create(
                userId, major, bootcampCompleted, 
                wantedJobs, licenses, hasGovCard, affordableAmount
        );

        return surveyRepository.save(survey);
    }

    public MemberSurvey getSurveyByUserId(Long userId) {
        return surveyRepository.findByUserId(userId)
                .orElseThrow(SurveyNotFoundException::new);
    }

    @Transactional
    public MemberSurvey updateSurvey(
            Long userId,
            String major,
            Boolean bootcampCompleted,
            String wantedJobs,
            String licenses,
            Boolean hasGovCard,
            BigDecimal affordableAmount
    ) {
        MemberSurvey survey = surveyRepository.findByUserId(userId)
                .orElseThrow(SurveyNotFoundException::new);

        survey.update(major, bootcampCompleted, wantedJobs, 
                      licenses, hasGovCard, affordableAmount);

        return surveyRepository.save(survey);
    }

    public Page<MemberSurvey> getAllSurveys(Pageable pageable) {
        return surveyRepository.findAll(pageable);
    }
}
```

---

## 2. API 모듈

### 2.1 Request DTOs

#### CreateSurveyRequest.java
```java
package com.swcampus.api.survey.request;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

@Schema(description = "설문조사 작성 요청")
public record CreateSurveyRequest(
        @Schema(description = "전공", example = "컴퓨터공학")
        String major,

        @Schema(description = "부트캠프 수료 여부", example = "true")
        Boolean bootcampCompleted,

        @Schema(description = "희망 직무", example = "백엔드 개발자, 데이터 엔지니어")
        String wantedJobs,

        @Schema(description = "보유 자격증", example = "정보처리기사, SQLD, AWS SAA")
        String licenses,

        @Schema(description = "내일배움카드 보유 여부", example = "true")
        Boolean hasGovCard,

        @Schema(description = "자비 부담 가능 금액", example = "500000")
        BigDecimal affordableAmount
) {}
```

#### UpdateSurveyRequest.java
```java
package com.swcampus.api.survey.request;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

@Schema(description = "설문조사 수정 요청")
public record UpdateSurveyRequest(
        @Schema(description = "전공", example = "소프트웨어공학")
        String major,

        @Schema(description = "부트캠프 수료 여부", example = "true")
        Boolean bootcampCompleted,

        @Schema(description = "희망 직무", example = "풀스택 개발자")
        String wantedJobs,

        @Schema(description = "보유 자격증", example = "정보처리기사, SQLD, AWS SAA, CKAD")
        String licenses,

        @Schema(description = "내일배움카드 보유 여부", example = "true")
        Boolean hasGovCard,

        @Schema(description = "자비 부담 가능 금액", example = "1000000")
        BigDecimal affordableAmount
) {}
```

### 2.2 Response DTO

#### SurveyResponse.java
```java
package com.swcampus.api.survey.response;

import com.swcampus.domain.survey.MemberSurvey;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Schema(description = "설문조사 응답")
public record SurveyResponse(
        @Schema(description = "회원 ID", example = "1")
        Long userId,

        @Schema(description = "전공", example = "컴퓨터공학")
        String major,

        @Schema(description = "부트캠프 수료 여부", example = "true")
        Boolean bootcampCompleted,

        @Schema(description = "희망 직무", example = "백엔드 개발자, 데이터 엔지니어")
        String wantedJobs,

        @Schema(description = "보유 자격증", example = "정보처리기사, SQLD, AWS SAA")
        String licenses,

        @Schema(description = "내일배움카드 보유 여부", example = "true")
        Boolean hasGovCard,

        @Schema(description = "자비 부담 가능 금액", example = "500000")
        BigDecimal affordableAmount,

        @Schema(description = "생성일시")
        LocalDateTime createdAt,

        @Schema(description = "수정일시")
        LocalDateTime updatedAt
) {
    public static SurveyResponse from(MemberSurvey survey) {
        return new SurveyResponse(
                survey.getUserId(),
                survey.getMajor(),
                survey.getBootcampCompleted(),
                survey.getWantedJobs(),
                survey.getLicenses(),
                survey.getHasGovCard(),
                survey.getAffordableAmount(),
                survey.getCreatedAt(),
                survey.getUpdatedAt()
        );
    }
}
```

### 2.3 Controller

#### SurveyController.java
```java
package com.swcampus.api.survey;

import com.swcampus.api.security.LoginUser;
import com.swcampus.api.survey.request.CreateSurveyRequest;
import com.swcampus.api.survey.request.UpdateSurveyRequest;
import com.swcampus.api.survey.response.SurveyResponse;
import com.swcampus.domain.survey.MemberSurvey;
import com.swcampus.domain.survey.MemberSurveyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "설문조사", description = "회원 설문조사 API")
@RestController
@RequestMapping("/api/v1/members/me/survey")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
public class SurveyController {

    private final MemberSurveyService surveyService;

    @Operation(summary = "설문조사 작성", description = "회원 설문조사를 작성합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "작성 성공"),
            @ApiResponse(responseCode = "401", description = "인증 필요"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "409", description = "이미 설문조사 존재")
    })
    @PostMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<SurveyResponse> createSurvey(
            @AuthenticationPrincipal LoginUser loginUser,
            @RequestBody CreateSurveyRequest request
    ) {
        MemberSurvey survey = surveyService.createSurvey(
                loginUser.getMemberId(),
                request.major(),
                request.bootcampCompleted(),
                request.wantedJobs(),
                request.licenses(),
                request.hasGovCard(),
                request.affordableAmount()
        );

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(SurveyResponse.from(survey));
    }

    @Operation(summary = "내 설문조사 조회", description = "본인의 설문조사를 조회합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 필요"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "설문조사 없음")
    })
    @GetMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<SurveyResponse> getMySurvey(
            @AuthenticationPrincipal LoginUser loginUser
    ) {
        MemberSurvey survey = surveyService.getSurveyByUserId(loginUser.getMemberId());
        return ResponseEntity.ok(SurveyResponse.from(survey));
    }

    @Operation(summary = "내 설문조사 수정", description = "본인의 설문조사를 수정합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "수정 성공"),
            @ApiResponse(responseCode = "401", description = "인증 필요"),
            @ApiResponse(responseCode = "403", description = "권한 없음"),
            @ApiResponse(responseCode = "404", description = "설문조사 없음")
    })
    @PutMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<SurveyResponse> updateMySurvey(
            @AuthenticationPrincipal LoginUser loginUser,
            @RequestBody UpdateSurveyRequest request
    ) {
        MemberSurvey survey = surveyService.updateSurvey(
                loginUser.getMemberId(),
                request.major(),
                request.bootcampCompleted(),
                request.wantedJobs(),
                request.licenses(),
                request.hasGovCard(),
                request.affordableAmount()
        );

        return ResponseEntity.ok(SurveyResponse.from(survey));
    }
}
```

---

## 완료 체크리스트

- [x] `MemberSurveyService.java` 생성
- [x] `MemberSurveyServiceTest.java` 생성 (단위 테스트)
- [x] `CreateSurveyRequest.java` 생성
- [x] `UpdateSurveyRequest.java` 생성
- [x] `SurveyResponse.java` 생성
- [x] `SurveyController.java` 생성
- [ ] Swagger UI에서 API 테스트
  - [ ] POST /api/v1/members/me/survey 테스트
  - [ ] GET /api/v1/members/me/survey 테스트
  - [ ] PUT /api/v1/members/me/survey 테스트

---

## 다음 단계

[Phase 03: 관리자 API + 테스트](./phase03-admin-test.md)로 진행
