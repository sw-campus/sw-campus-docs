# VSCode 개발 환경 설정

VSCode에서 Spring Boot 멀티모듈 프로젝트를 개발하기 위한 설정 가이드입니다.

## 필수 확장 프로그램

- Extension Pack for Java
- Spring Boot Extension Pack

## 초기 설정

VSCode에서 프로젝트를 처음 열거나, 모듈 인식 오류가 발생할 경우:

```bash
cd sw-campus-server
./gradlew eclipse
```

이 명령은 Eclipse 프로젝트 메타데이터(`.classpath`, `.project`)를 생성하여 VSCode Java Extension이 모든 모듈을 인식할 수 있게 합니다.

## 문제 해결

### "missing required Java project" 오류

```
Project 'sw-campus-api' is missing required Java project: 'analytics'
```

위와 같은 오류 발생 시:

1. `./gradlew eclipse` 실행
2. VSCode에서 `Cmd + Shift + P` → `Java: Clean Java Language Server Workspace`
3. "Reload and delete" 선택

### 디버깅 설정

`.vscode/launch.json` 설정:

```json
{
    "type": "java",
    "name": "SwCampusServerApplication",
    "request": "launch",
    "mainClass": "com.swcampus.SwCampusServerApplication",
    "projectName": "sw-campus-api",
    "preLaunchTask": "gradle-build",
    "vmArgs": "-Dspring.profiles.active=local -Dspring.flyway.schemas=swcampus -Dspring.flyway.default-schema=swcampus -Dspring.flyway.baseline-on-migrate=true"
}
```

## 참고

- IntelliJ 사용자는 이 설정이 필요 없습니다 (자체 Gradle import 사용)
- `.classpath`, `.project` 파일은 `.gitignore`에 포함되어 있어 로컬에만 존재합니다
