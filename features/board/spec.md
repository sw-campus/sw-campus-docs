# 게시판 (Board) Spec

## 설계 결정

### 왜 카테고리를 별도 테이블로 관리하는가?

동적 카테고리 관리 필요. ENUM 대신 `BoardCategory` 테이블 사용.

- 관리자가 카테고리 추가/수정 가능
- `BoardCategoryService`로 카테고리명 조회

### 왜 닉네임 설정을 게시글 작성 조건으로 하는가?

익명성 방지 및 커뮤니티 신뢰도 확보.

- 로그인만으로 조회 가능, 작성은 닉네임 필수
- 게시글/댓글에 `authorNickname` 표시

### 왜 Soft Delete를 사용하는가?

데이터 보존 및 복구 가능성.

- 게시글 삭제 시 실제 삭제가 아닌 soft delete
- 관련 댓글도 함께 soft delete 처리

### 왜 N+1 문제를 일괄 조회로 해결하는가?

목록 조회 성능 최적화.

```java
// 댓글 수 일괄 조회
Map<Long, Long> commentCounts = commentService.getCommentCounts(postIds);
```

- `PostSummary`로 작성자/카테고리 JOIN 조회
- 댓글 수는 별도 일괄 쿼리

### 왜 조회수 증가에 별도 처리를 하지 않는가?

MVP 단계에서 단순 구현 우선.

- 상세 조회 시 `VIEW_COUNT += 1`
- 동일 사용자 중복 조회수 허용 (추후 개선)

### 왜 이전/다음 게시글 API를 별도로 제공하는가?

상세 페이지 UX 향상.

- `GET /api/v1/posts/{postId}/adjacent`
- 네비게이션 버튼용 데이터 제공

---

## 구현 노트

### 2025-01 - 게시글 고정 기능 [Server]

- 관리자 게시글 상단 고정/해제
- `POST /api/v1/posts/{postId}/pin` (ADMIN 권한)
- `@PreAuthorize("hasRole('ADMIN')")`

### 2025-01 - 북마크/좋아요 기능 [Server]

- `BookmarkService`, `PostLikeService` 추가
- 상세 조회 시 `isBookmarked`, `isLiked` 반환

### 2025-01 - Post Diary 기능 [Server][Client]

- PR: #433, #440
- 강의 연동 게시글 (학습 일지)
- `LectureSelector`, `DiaryTemplateForm` 컴포넌트

### 2025-01 - 댓글 CRUD [Server][Client]

- PR: #414
- `CommentController`, `CommentService`
- `CommentSection`, `CommentItem` 컴포넌트

### 2025-01 - 게시글 CRUD [Server][Client]

- PR: #406
- 게시글 작성/조회/수정/삭제
- 태그, 이미지 업로드 지원
- 검색 (제목, 본문, 태그)
- `PostList`, `PostCard`, `PostForm` 컴포넌트

---

## 미구현 사항

| 기능 | 상태 | 비고 |
|------|:----:|------|
| 실시간 알림 | X | Out of Scope |
| 조회수 중복 방지 | X | 추후 개선 |
