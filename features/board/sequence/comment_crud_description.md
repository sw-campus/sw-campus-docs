## 필수 정보

### 1. 참여자 (Participants/Actors)

| 참여자 | 설명 | 기술 스택 |
|--------|------|-----------|
| 사용자 (User) | 서비스 이용자 | 브라우저 |
| 게시글 작성자 (Author) | 게시글 작성자 | 브라우저 |
| 프론트엔드 (Frontend) | 웹 클라이언트 | Next.js |
| 백엔드 (Backend) | API 서버 | Spring Boot |
| S3 | 이미지 저장소 | AWS S3 |
| DB (Database) | 데이터 저장소 | PostgreSQL |

### 2. 시나리오/흐름 설명

- 댓글 작성 (이미지 첨부 가능)
- 대댓글 작성 (parentId 기반)
- 댓글 수정
- 댓글 삭제 (Soft Delete)
- 댓글 채택 (Q&A 게시글)

### 3. 메시지 흐름 순서

#### 3-1. 댓글 작성

```
1. 사용자 → 프론트엔드: 댓글 작성 (내용, 이미지)
2. [조건] 비로그인: 로그인 필요 안내
3. [선택] 이미지 첨부:
   - 프론트엔드 → S3: 이미지 업로드
   - S3 → 프론트엔드: 이미지 URL 반환
4. 프론트엔드 → 백엔드: POST /api/v1/posts/{postId}/comments
5. 백엔드 → DB: 댓글 저장
6. 백엔드 → DB: 게시글 commentCount 증가
7. 백엔드 → 프론트엔드: 201 Created
8. 프론트엔드 → 사용자: 댓글 목록에 추가
```

#### 3-2. 대댓글 작성

```
1. 사용자 → 프론트엔드: 답글 버튼 클릭
2. 프론트엔드 → 사용자: 답글 입력 폼 표시
3. 사용자 → 프론트엔드: 대댓글 작성
4. 프론트엔드 → 백엔드: POST /api/v1/posts/{postId}/comments (parentId 포함)
5. 백엔드 → DB: 대댓글 저장 (parent_id 설정)
6. 백엔드 → DB: 게시글 commentCount 증가
7. 백엔드 → 프론트엔드: 201 Created
8. 프론트엔드 → 사용자: 대댓글 목록에 추가
```

#### 3-3. 댓글 수정

```
1. 사용자 → 프론트엔드: 수정 버튼 클릭
2. 프론트엔드 → 사용자: 수정 폼 표시
3. 사용자 → 프론트엔드: 수정 내용 제출
4. 프론트엔드 → 백엔드: PUT /api/v1/posts/{postId}/comments/{commentId}
5. 백엔드 → DB: 권한 확인 (본인 또는 관리자)
6. [조건] 권한 있음:
   - 백엔드 → DB: 댓글 수정
   - 백엔드 → 프론트엔드: 200 OK
7. [조건] 권한 없음:
   - 백엔드 → 프론트엔드: 403 Forbidden
```

#### 3-4. 댓글 삭제

```
1. 사용자 → 프론트엔드: 삭제 버튼 클릭
2. 프론트엔드 → 사용자: 삭제 확인
3. 사용자 → 프론트엔드: 삭제 확인
4. 프론트엔드 → 백엔드: DELETE /api/v1/posts/{postId}/comments/{commentId}
5. 백엔드 → DB: 권한 확인 (본인 또는 관리자)
6. [조건] 권한 있음:
   - 백엔드 → DB: Soft Delete (deleted = true)
   - 백엔드 → DB: 게시글 commentCount 감소
   - 백엔드 → 프론트엔드: 204 No Content
7. [조건] 권한 없음:
   - 백엔드 → 프론트엔드: 403 Forbidden
```

#### 3-5. 댓글 채택 (Q&A)

```
1. 게시글 작성자 → 프론트엔드: 채택 버튼 클릭
2. 프론트엔드 → 백엔드: POST /api/v1/posts/{postId}/comments/{commentId}/select
3. 백엔드 → DB: 게시글 작성자 확인
4. [조건] 본인 게시글:
   - 백엔드 → DB: selectedCommentId 업데이트
   - 백엔드 → 프론트엔드: 200 OK
5. [조건] 권한 없음:
   - 백엔드 → 프론트엔드: 403 Forbidden
```

---

## 선택 정보

### 4. 조건부 흐름 (alt/opt)

| 시나리오 | 분기 조건 |
|----------|-----------|
| 댓글 작성 | 로그인 여부 |
| 댓글 수정/삭제 | 본인 또는 관리자 권한 |
| 댓글 채택 | 게시글 작성자만 |

### 5. 기술 정보

| 항목 | 설명 |
|------|------|
| 대댓글 | parent_id로 계층 구조 표현 |
| 삭제 방식 | Soft Delete (deleted 플래그) |
| 삭제된 댓글 표시 | "삭제된 댓글입니다" |

### 6. API 엔드포인트

| Method | Path | 설명 | 권한 |
|--------|------|------|------|
| POST | /api/v1/posts/{postId}/comments | 작성 | USER |
| PUT | /api/v1/posts/{postId}/comments/{commentId} | 수정 | 작성자/ADMIN |
| DELETE | /api/v1/posts/{postId}/comments/{commentId} | 삭제 | 작성자/ADMIN |
| POST | /api/v1/posts/{postId}/comments/{commentId}/select | 채택 | 게시글 작성자 |
