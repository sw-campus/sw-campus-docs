# Phase 01: 기반 구조

> Domain, Entity, Repository 기반 구조 생성

## 목표

- MemberSurvey 도메인 객체 생성
- Repository 인터페이스 및 구현체 생성
- Exception 클래스 생성
- ErrorCode 추가

---

## 1. Domain 모듈

### 1.1 Domain 객체

#### MemberSurvey.java
```java
package com.swcampus.domain.survey;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MemberSurvey {
    private Long userId;
    private String major;
    private Boolean bootcampCompleted;
    private String wantedJobs;
    private String licenses;
    private Boolean hasGovCard;
    private BigDecimal affordableAmount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static MemberSurvey create(
            Long userId,
            String major,
            Boolean bootcampCompleted,
            String wantedJobs,
            String licenses,
            Boolean hasGovCard,
            BigDecimal affordableAmount
    ) {
        MemberSurvey survey = new MemberSurvey();
        survey.userId = userId;
        survey.major = major;
        survey.bootcampCompleted = bootcampCompleted;
        survey.wantedJobs = wantedJobs;
        survey.licenses = licenses;
        survey.hasGovCard = hasGovCard;
        survey.affordableAmount = affordableAmount;
        return survey;
    }

    public static MemberSurvey of(
            Long userId,
            String major,
            Boolean bootcampCompleted,
            String wantedJobs,
            String licenses,
            Boolean hasGovCard,
            BigDecimal affordableAmount,
            LocalDateTime createdAt,
            LocalDateTime updatedAt
    ) {
        MemberSurvey survey = new MemberSurvey();
        survey.userId = userId;
        survey.major = major;
        survey.bootcampCompleted = bootcampCompleted;
        survey.wantedJobs = wantedJobs;
        survey.licenses = licenses;
        survey.hasGovCard = hasGovCard;
        survey.affordableAmount = affordableAmount;
        survey.createdAt = createdAt;
        survey.updatedAt = updatedAt;
        return survey;
    }

    public void update(
            String major,
            Boolean bootcampCompleted,
            String wantedJobs,
            String licenses,
            Boolean hasGovCard,
            BigDecimal affordableAmount
    ) {
        this.major = major;
        this.bootcampCompleted = bootcampCompleted;
        this.wantedJobs = wantedJobs;
        this.licenses = licenses;
        this.hasGovCard = hasGovCard;
        this.affordableAmount = affordableAmount;
    }
}
```

### 1.2 Repository 인터페이스

#### MemberSurveyRepository.java
```java
package com.swcampus.domain.survey;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.Optional;

public interface MemberSurveyRepository {
    MemberSurvey save(MemberSurvey survey);
    Optional<MemberSurvey> findByUserId(Long userId);
    boolean existsByUserId(Long userId);
    Page<MemberSurvey> findAll(Pageable pageable);
}
```

### 1.3 Exception 클래스

#### SurveyNotFoundException.java
```java
package com.swcampus.domain.survey.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class SurveyNotFoundException extends BusinessException {
    public SurveyNotFoundException() {
        super(ErrorCode.SURVEY_NOT_FOUND);
    }
}
```

#### SurveyAlreadyExistsException.java
```java
package com.swcampus.domain.survey.exception;

import com.swcampus.shared.exception.BusinessException;
import com.swcampus.shared.exception.ErrorCode;

public class SurveyAlreadyExistsException extends BusinessException {
    public SurveyAlreadyExistsException() {
        super(ErrorCode.SURVEY_ALREADY_EXISTS);
    }
}
```

### 1.4 ErrorCode 추가

기존 `ErrorCode.java`에 추가:
```java
// Survey
SURVEY_NOT_FOUND(HttpStatus.NOT_FOUND, "SURVEY002", "설문조사를 찾을 수 없습니다"),
SURVEY_ALREADY_EXISTS(HttpStatus.CONFLICT, "SURVEY001", "이미 설문조사를 작성하셨습니다"),
```

---

## 2. Infra 모듈 (db-postgres)

### 2.1 Entity

#### MemberSurveyEntity.java
```java
package com.swcampus.infra.postgres.survey;

import com.swcampus.domain.survey.MemberSurvey;
import com.swcampus.infra.postgres.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "member_surveys")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MemberSurveyEntity extends BaseEntity {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(length = 100)
    private String major;

    private Boolean bootcampCompleted;

    @Column(length = 255)
    private String wantedJobs;

    @Column(length = 500)
    private String licenses;

    private Boolean hasGovCard;

    @Column(precision = 15, scale = 2)
    private BigDecimal affordableAmount;

    public static MemberSurveyEntity from(MemberSurvey survey) {
        MemberSurveyEntity entity = new MemberSurveyEntity();
        entity.userId = survey.getUserId();
        entity.major = survey.getMajor();
        entity.bootcampCompleted = survey.getBootcampCompleted();
        entity.wantedJobs = survey.getWantedJobs();
        entity.licenses = survey.getLicenses();
        entity.hasGovCard = survey.getHasGovCard();
        entity.affordableAmount = survey.getAffordableAmount();
        return entity;
    }

    public MemberSurvey toDomain() {
        return MemberSurvey.of(
                this.userId,
                this.major,
                this.bootcampCompleted,
                this.wantedJobs,
                this.licenses,
                this.hasGovCard,
                this.affordableAmount,
                this.getCreatedAt(),
                this.getUpdatedAt()
        );
    }

    public void update(MemberSurvey survey) {
        this.major = survey.getMajor();
        this.bootcampCompleted = survey.getBootcampCompleted();
        this.wantedJobs = survey.getWantedJobs();
        this.licenses = survey.getLicenses();
        this.hasGovCard = survey.getHasGovCard();
        this.affordableAmount = survey.getAffordableAmount();
    }
}
```

### 2.2 JPA Repository

#### MemberSurveyJpaRepository.java
```java
package com.swcampus.infra.postgres.survey;

import org.springframework.data.jpa.repository.JpaRepository;

public interface MemberSurveyJpaRepository extends JpaRepository<MemberSurveyEntity, Long> {
}
```

### 2.3 Repository 구현체

#### MemberSurveyEntityRepository.java
```java
package com.swcampus.infra.postgres.survey;

import com.swcampus.domain.survey.MemberSurvey;
import com.swcampus.domain.survey.MemberSurveyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class MemberSurveyEntityRepository implements MemberSurveyRepository {

    private final MemberSurveyJpaRepository jpaRepository;

    @Override
    public MemberSurvey save(MemberSurvey survey) {
        // 기존 엔티티가 있으면 업데이트, 없으면 새로 생성
        MemberSurveyEntity entity = jpaRepository.findById(survey.getUserId())
                .map(existing -> {
                    existing.update(survey);
                    return existing;
                })
                .orElseGet(() -> MemberSurveyEntity.from(survey));
        
        return jpaRepository.save(entity).toDomain();
    }

    @Override
    public Optional<MemberSurvey> findByUserId(Long userId) {
        return jpaRepository.findById(userId)
                .map(MemberSurveyEntity::toDomain);
    }

    @Override
    public boolean existsByUserId(Long userId) {
        return jpaRepository.existsById(userId);
    }

    @Override
    public Page<MemberSurvey> findAll(Pageable pageable) {
        return jpaRepository.findAll(pageable)
                .map(MemberSurveyEntity::toDomain);
    }
}
```

---

## 완료 체크리스트

- [x] `MemberSurvey.java` 생성
- [x] `MemberSurveyRepository.java` 생성
- [x] `SurveyNotFoundException.java` 생성
- [x] `SurveyAlreadyExistsException.java` 생성
- [x] ~~`ErrorCode.java`에 SURVEY 에러 코드 추가~~ (기존 프로젝트에 ErrorCode 없음, RuntimeException 패턴 사용)
- [x] `MemberSurveyEntity.java` 생성
- [x] `MemberSurveyJpaRepository.java` 생성
- [x] `MemberSurveyEntityRepository.java` 생성
- [ ] 서버 기동 후 테이블 자동 생성 확인

---

## 다음 단계

[Phase 02: 사용자 API](./phase02-user-api.md)로 진행
