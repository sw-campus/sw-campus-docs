# CLAUDE.md - Docs

This file provides guidance to Claude Code when working with sw-campus-docs.

## Project Overview

SW Campus 기술 문서 및 코드 규칙

## Code Rules Structure

```
code-rules/
├── README.md           # 개요
├── 00-index.md         # AI 협업용 인덱스
├── server/             # Backend (Spring Boot) 코드 규칙
│   ├── 01-module-structure.md
│   ├── 02-naming-convention.md
│   ├── 03-dependency-rules.md
│   ├── 04-api-design.md
│   ├── 05-exception-handling.md
│   ├── 06-design-principles.md
│   └── 07-swagger-documentation.md
└── front/              # Frontend (Next.js) 코드 규칙
    └── (준비 중)
```

## AI 협업

AI와 협업 시 `code-rules/00-index.md`를 컨텍스트로 제공하면,
AI가 작업에 필요한 규칙 문서를 스스로 참조합니다.
