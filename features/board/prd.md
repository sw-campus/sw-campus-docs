# 게시판 (Board) - PRD

## 개요

SW Campus 커뮤니티 게시판. 공지사항, 자유게시판, Q&A, 학습일지 등 다양한 게시판 제공.

---

## 사용자 유형

| 유형 | Role | 권한 |
|------|------|------|
| 비회원 | GUEST | 조회만 가능 |
| 일반 사용자 | USER | 게시글/댓글 CRUD |
| 관리자 | ADMIN | 전체 관리, 공지 설정, 고정 |

---

## 기능 요구사항

### 게시판 카테고리

계층형 카테고리 (`BoardCategory` 테이블).

- 부모-자식 관계 (`pid`)
- 관리자가 동적으로 추가/수정 가능

### 게시글

| 기능 | 설명 |
|------|------|
| 목록 조회 | 페이지네이션, 카테고리/태그/키워드 필터링 |
| 상세 조회 | 조회수 증가, 이전/다음 게시글 |
| 작성 | 로그인 + 닉네임 필수, 이미지/태그 첨부 |
| 수정 | 본인 또는 관리자 |
| 삭제 | Soft Delete |
| 좋아요 | 게시글 좋아요 토글 |
| 북마크 | 게시글 북마크 |
| 상단 고정 | 관리자만 (pinned) |

### 댓글

| 기능 | 설명 |
|------|------|
| 작성 | 로그인 필수, 이미지 첨부 가능 |
| 대댓글 | parentId로 계층 구조 |
| 수정/삭제 | 본인 또는 관리자 |
| 좋아요 | 댓글 좋아요 토글 |
| 채택 | Q&A 게시글 작성자가 댓글 채택 |

### 학습 일지 (Post Diary)

강의 연동 게시글.

- 수강 중인 강의 선택
- 템플릿 기반 작성

---

## 데이터 모델

### POSTS

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| board_category_id | BIGINT | FK → BOARD_CATEGORIES |
| user_id | BIGINT | FK → MEMBERS |
| title | VARCHAR(100) | 제목 |
| body | TEXT | 본문 |
| images | TEXT[] | 이미지 URL 배열 |
| tags | TEXT[] | 태그 배열 |
| view_count | BIGINT | 조회수 |
| like_count | BIGINT | 좋아요 수 |
| comment_count | BIGINT | 댓글 수 |
| selected_comment_id | BIGINT | 채택된 댓글 ID |
| pinned | BOOLEAN | 상단 고정 |
| deleted | BOOLEAN | Soft Delete |
| created_at | TIMESTAMPTZ | 생성일시 |
| updated_at | TIMESTAMPTZ | 수정일시 |

### COMMENTS

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| post_id | BIGINT | FK → POSTS |
| user_id | BIGINT | FK → MEMBERS |
| parent_id | BIGINT | 부모 댓글 ID (대댓글) |
| body | TEXT | 내용 |
| image_url | VARCHAR | 이미지 URL |
| like_count | BIGINT | 좋아요 수 |
| deleted | BOOLEAN | Soft Delete |
| created_at | TIMESTAMPTZ | 생성일시 |
| updated_at | TIMESTAMPTZ | 수정일시 |

### BOARD_CATEGORIES

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | BIGINT | PK |
| name | VARCHAR | 카테고리명 |
| pid | BIGINT | 부모 카테고리 ID |

---

## 비기능 요구사항

| 구분 | 요구사항 |
|------|----------|
| 보안 | 작성/수정/삭제는 로그인 필수 |
| 보안 | XSS 방지 입력값 검증 |
| 성능 | 목록 조회 500ms 이내 |
| 성능 | N+1 문제 방지 (일괄 조회) |

---

## 범위

### In Scope

- [x] 게시글 CRUD
- [x] 댓글/대댓글 CRUD
- [x] 이미지 첨부
- [x] 태그
- [x] 좋아요/북마크
- [x] 검색 (제목, 본문, 태그)
- [x] 상단 고정
- [x] 댓글 채택
- [x] 학습 일지

### Out of Scope

- [ ] 실시간 알림
- [ ] 조회수 중복 방지

---

## 관련 문서

- [Spec](./spec.md)
