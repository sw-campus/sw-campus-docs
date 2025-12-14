# Phase 03: 관리자 API + 테스트

> 관리자 전용 API 및 API 통합 테스트

## 목표

- 관리자 설문조사 조회 API 구현
- API 통합 테스트 작성 (선택적)

> **Note**: Domain 단위 테스트는 Phase 02에서 `MemberSurveyServiceTest`로 완료됨

---

## 1. 관리자 Controller

### AdminSurveyController.java
```java
package com.swcampus.api.admin;

import com.swcampus.api.survey.response.SurveyResponse;
import com.swcampus.domain.survey.MemberSurvey;
import com.swcampus.domain.survey.MemberSurveyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Admin Survey", description = "관리자 설문조사 관리 API")
@RestController
@RequestMapping("/api/v1/admin/surveys")
@RequiredArgsConstructor
@SecurityRequirement(name = "cookieAuth")
@PreAuthorize("hasRole('ADMIN')")
public class AdminSurveyController {

    private final MemberSurveyService surveyService;

    @Operation(summary = "전체 설문조사 목록 조회", description = "모든 회원의 설문조사를 페이징 조회합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 필요"),
            @ApiResponse(responseCode = "403", description = "권한 없음 (ADMIN만 가능)")
    })
    @GetMapping
    public ResponseEntity<Page<SurveyResponse>> getSurveys(
            @PageableDefault(size = 20) Pageable pageable
    ) {
        Page<MemberSurvey> surveys = surveyService.getAllSurveys(pageable);
        Page<SurveyResponse> response = surveys.map(SurveyResponse::from);
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "특정 회원 설문조사 조회", description = "특정 회원의 설문조사를 조회합니다.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "조회 성공"),
            @ApiResponse(responseCode = "401", description = "인증 필요"),
            @ApiResponse(responseCode = "403", description = "권한 없음 (ADMIN만 가능)"),
            @ApiResponse(responseCode = "404", description = "설문조사 없음")
    })
    @GetMapping("/members/{memberId}")
    public ResponseEntity<SurveyResponse> getSurvey(
            @Parameter(description = "회원 ID", example = "1")
            @PathVariable Long memberId
    ) {
        MemberSurvey survey = surveyService.getSurveyByMemberId(memberId);
        return ResponseEntity.ok(SurveyResponse.from(survey));
    }
}
```

---

## 2. 테스트 코드

### 2.1 Domain 단위 테스트

#### MemberSurveyServiceTest.java
```java
package com.swcampus.domain.survey;

import com.swcampus.domain.survey.exception.SurveyAlreadyExistsException;
import com.swcampus.domain.survey.exception.SurveyNotFoundException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
@DisplayName("MemberSurveyService 단위 테스트")
class MemberSurveyServiceTest {

    @Mock
    private MemberSurveyRepository surveyRepository;

    @InjectMocks
    private MemberSurveyService surveyService;

    private final Long userId = 1L;

    @Nested
    @DisplayName("createSurvey")
    class CreateSurvey {

        @Test
        @DisplayName("성공 - 새 설문조사 생성")
        void success() {
            // given
            given(surveyRepository.existsByUserId(userId)).willReturn(false);
            given(surveyRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            // when
            MemberSurvey result = surveyService.createSurvey(
                    userId, "컴퓨터공학", true, 
                    "백엔드 개발자", "정보처리기사", 
                    true, BigDecimal.valueOf(500000)
            );

            // then
            assertThat(result.getUserId()).isEqualTo(userId);
            assertThat(result.getMajor()).isEqualTo("컴퓨터공학");
        }

        @Test
        @DisplayName("실패 - 이미 설문조사 존재")
        void fail_alreadyExists() {
            // given
            given(surveyRepository.existsByUserId(userId)).willReturn(true);

            // when & then
            assertThatThrownBy(() -> surveyService.createSurvey(
                    userId, "컴퓨터공학", true, 
                    "백엔드 개발자", "정보처리기사", 
                    true, BigDecimal.valueOf(500000)
            )).isInstanceOf(SurveyAlreadyExistsException.class);
        }
    }

    @Nested
    @DisplayName("getSurveyByUserId")
    class GetSurveyByUserId {

        @Test
        @DisplayName("성공 - 설문조사 조회")
        void success() {
            // given
            MemberSurvey survey = MemberSurvey.create(
                    userId, "컴퓨터공학", true, 
                    "백엔드 개발자", "정보처리기사", 
                    true, BigDecimal.valueOf(500000)
            );
            given(surveyRepository.findByUserId(userId)).willReturn(Optional.of(survey));

            // when
            MemberSurvey result = surveyService.getSurveyByUserId(userId);

            // then
            assertThat(result.getUserId()).isEqualTo(userId);
        }

        @Test
        @DisplayName("실패 - 설문조사 없음")
        void fail_notFound() {
            // given
            given(surveyRepository.findByUserId(userId)).willReturn(Optional.empty());

            // when & then
            assertThatThrownBy(() -> surveyService.getSurveyByUserId(userId))
                    .isInstanceOf(SurveyNotFoundException.class);
        }
    }

    @Nested
    @DisplayName("updateSurvey")
    class UpdateSurvey {

        @Test
        @DisplayName("성공 - 설문조사 수정")
        void success() {
            // given
            MemberSurvey survey = MemberSurvey.create(
                    userId, "컴퓨터공학", true, 
                    "백엔드 개발자", "정보처리기사", 
                    true, BigDecimal.valueOf(500000)
            );
            given(surveyRepository.findByUserId(userId)).willReturn(Optional.of(survey));
            given(surveyRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            // when
            MemberSurvey result = surveyService.updateSurvey(
                    userId, "소프트웨어공학", false, 
                    "프론트엔드 개발자", "SQLD", 
                    false, BigDecimal.valueOf(1000000)
            );

            // then
            assertThat(result.getMajor()).isEqualTo("소프트웨어공학");
            assertThat(result.getWantedJobs()).isEqualTo("프론트엔드 개발자");
        }

        @Test
        @DisplayName("실패 - 설문조사 없음")
        void fail_notFound() {
            // given
            given(surveyRepository.findByUserId(userId)).willReturn(Optional.empty());

            // when & then
            assertThatThrownBy(() -> surveyService.updateSurvey(
                    userId, "소프트웨어공학", false, 
                    "프론트엔드 개발자", "SQLD", 
                    false, BigDecimal.valueOf(1000000)
            )).isInstanceOf(SurveyNotFoundException.class);
        }
    }
}
```

### 2.2 API 통합 테스트

#### SurveyApiIntegrationTest.java
```java
package com.swcampus.api.survey;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.swcampus.api.survey.request.CreateSurveyRequest;
import com.swcampus.api.survey.request.UpdateSurveyRequest;
import com.swcampus.domain.auth.TokenProvider;
import com.swcampus.domain.member.Role;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
@DisplayName("설문조사 API 통합 테스트")
class SurveyApiIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private TokenProvider tokenProvider;

    private static final String BASE_URL = "/api/v1/members/me/survey";

    @Nested
    @DisplayName("POST /api/v1/members/me/survey")
    class CreateSurvey {

        @Test
        @DisplayName("성공 - 설문조사 작성")
        void success() throws Exception {
            // given
            String token = tokenProvider.createAccessToken(1L, "user@test.com", Role.USER);
            CreateSurveyRequest request = new CreateSurveyRequest(
                    "컴퓨터공학", true, "백엔드 개발자",
                    "정보처리기사", true, BigDecimal.valueOf(500000)
            );

            // when & then
            mockMvc.perform(post(BASE_URL)
                            .header("Authorization", "Bearer " + token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(request)))
                    .andDo(print())
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.userId").value(1))
                    .andExpect(jsonPath("$.major").value("컴퓨터공학"));
        }

        @Test
        @DisplayName("실패 - 인증 없음")
        void fail_unauthorized() throws Exception {
            // given
            CreateSurveyRequest request = new CreateSurveyRequest(
                    "컴퓨터공학", true, "백엔드 개발자",
                    "정보처리기사", true, BigDecimal.valueOf(500000)
            );

            // when & then
            mockMvc.perform(post(BASE_URL)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("실패 - ADMIN은 작성 불가")
        void fail_forbidden_admin() throws Exception {
            // given
            String token = tokenProvider.createAccessToken(99L, "admin@test.com", Role.ADMIN);
            CreateSurveyRequest request = new CreateSurveyRequest(
                    "컴퓨터공학", true, "백엔드 개발자",
                    "정보처리기사", true, BigDecimal.valueOf(500000)
            );

            // when & then
            mockMvc.perform(post(BASE_URL)
                            .header("Authorization", "Bearer " + token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isForbidden());
        }
    }

    @Nested
    @DisplayName("GET /api/v1/members/me/survey")
    class GetMySurvey {

        @Test
        @DisplayName("실패 - 설문조사 없음")
        void fail_notFound() throws Exception {
            // given
            String token = tokenProvider.createAccessToken(999L, "nosurvey@test.com", Role.USER);

            // when & then
            mockMvc.perform(get(BASE_URL)
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isNotFound());
        }
    }

    @Nested
    @DisplayName("관리자 API")
    class AdminApi {

        @Test
        @DisplayName("GET /api/v1/admin/members/surveys - 성공")
        void getAllSurveys_success() throws Exception {
            // given
            String token = tokenProvider.createAccessToken(99L, "admin@test.com", Role.ADMIN);

            // when & then
            mockMvc.perform(get("/api/v1/admin/members/surveys")
                            .header("Authorization", "Bearer " + token))
                    .andDo(print())
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content").isArray());
        }

        @Test
        @DisplayName("GET /api/v1/admin/members/surveys - 실패 (USER 권한)")
        void getAllSurveys_fail_forbidden() throws Exception {
            // given
            String token = tokenProvider.createAccessToken(1L, "user@test.com", Role.USER);

            // when & then
            mockMvc.perform(get("/api/v1/admin/members/surveys")
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isForbidden());
        }
    }
}
```

---

## 완료 체크리스트

- [x] `AdminSurveyController.java` 생성
- [x] `@PreAuthorize("hasRole('ADMIN')")` 권한 검사 추가
- [x] `GlobalExceptionHandler`에 Survey 예외 핸들러 추가
  - [x] `SurveyNotFoundException` → 404 NOT_FOUND
  - [x] `SurveyAlreadyExistsException` → 409 CONFLICT
- [x] ~~`MemberSurveyServiceTest.java` 생성 (단위 테스트)~~ Phase 02에서 완료
- [x] `SurveyControllerTest.java` 생성 (Controller 슬라이스 테스트) - 6개 테스트 통과
- [x] `AdminSurveyControllerTest.java` 생성 (Controller 슬라이스 테스트) - 4개 테스트 통과
- [ ] Swagger UI에서 관리자 API 테스트
  - [ ] GET /api/v1/admin/members/surveys 테스트
  - [ ] GET /api/v1/admin/members/{userId}/survey 테스트

---

## 개발 완료 후

모든 Phase 완료 후 `report.md`에 결과를 기록합니다.

### 검증 항목

1. **기능 테스트**
   - [x] USER로 설문조사 작성/조회/수정 (Controller 구현 완료)
   - [x] ADMIN으로 전체 목록/특정 회원 조회 (Controller 구현 완료)
   - [x] 권한 없는 접근 시 403 반환 (`@PreAuthorize` 적용)

2. **예외 케이스**
   - [x] 중복 설문조사 작성 시 409 반환 (`SurveyAlreadyExistsException` → GlobalExceptionHandler)
   - [x] 존재하지 않는 설문조사 조회 시 404 반환 (`SurveyNotFoundException` → GlobalExceptionHandler)
   - [x] 인증 없이 접근 시 401 반환 (Spring Security 기본 처리)

3. **테스트**
   - [x] 단위 테스트 전체 통과 (`MemberSurveyServiceTest` - 6개 통과)
   - [x] Controller 슬라이스 테스트 전체 통과 (`SurveyControllerTest` 6개 + `AdminSurveyControllerTest` 4개 = 10개 통과)
