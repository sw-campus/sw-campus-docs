# Tailscale 테스트 서버 접속 가이드

테스트 서버에 접속하기 위한 Tailscale VPN 설정 가이드입니다.

## 서버 정보

| 항목 | 값 |
|------|-----|
| 서버명 | `<서버명>` |
| IP | `<Tailscale 내부 IP>` |
| SSH 계정 | `<SSH 계정>` |
| 웹 URL | `<테스트 서버 URL>` |

> 위 정보는 팀에서 별도로 공유받으세요.

---

## Windows 설정

### 1. Tailscale 설치

1. [Tailscale 다운로드 페이지](https://tailscale.com/download) 접속
2. **Windows** 버튼 클릭하여 설치 파일 다운로드
3. 다운로드된 `.exe` 파일 실행하여 설치

### 2. Tailscale 로그인

1. 설치 완료 후 시스템 트레이에서 Tailscale 아이콘 클릭
2. **Log in** 클릭
3. 팀에서 공유한 계정으로 로그인

> 또는 명령 프롬프트(관리자 권한)에서 authkey로 로그인:
> ```cmd
> tailscale up --authkey=<팀에서 공유받은 인증키>
> ```

### 3. 연결 확인

명령 프롬프트에서:
```cmd
tailscale status
```
`<서버명>`이 목록에 표시되면 연결 성공

### 4. 서버 접속

**SSH 접속** (PowerShell 또는 CMD):
```cmd
ssh <SSH 계정>@<Tailscale 내부 IP>
```

**웹 접속**:
브라우저에서 `<테스트 서버 URL>` 접속

---

## Android 설정

### 1. Tailscale 앱 설치

1. Google Play Store에서 "Tailscale" 검색
2. [Tailscale](https://play.google.com/store/apps/details?id=com.tailscale.ipn) 앱 설치

### 2. 로그인

1. 앱 실행
2. **Get Started** 탭
3. 팀에서 공유한 계정으로 로그인
4. VPN 연결 권한 허용

### 3. 연결 확인

앱 메인 화면에서 `<서버명>`이 목록에 표시되면 연결 성공

### 4. 웹 접속

모바일 브라우저에서 `<테스트 서버 URL>` 접속

---

## Linux (Arch Linux) 설정

### 1. Tailscale 설치

```bash
sudo pacman -S tailscale
```

### 2. 서비스 시작

```bash
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
```

### 3. 로그인

```bash
sudo tailscale up --authkey=<팀에서 공유받은 인증키>
```

### 4. 연결 확인

```bash
tailscale status
```

### 5. SSH 접속

```bash
ssh <SSH 계정>@<Tailscale 내부 IP>
```

---

## macOS 설정

### 1. Tailscale 설치

1. [Tailscale 다운로드 페이지](https://tailscale.com/download) 접속
2. **macOS** 버튼 클릭
3. App Store에서 설치 또는 직접 다운로드

### 2. 로그인

1. 메뉴 바에서 Tailscale 아이콘 클릭
2. **Log in** 선택
3. 팀에서 공유한 계정으로 로그인

### 3. 연결 확인

터미널에서:
```bash
tailscale status
```

### 4. SSH 접속

```bash
ssh <SSH 계정>@<Tailscale 내부 IP>
```

---

## 문제 해결

### 연결이 안 될 때

1. Tailscale 서비스가 실행 중인지 확인
2. 인터넷 연결 상태 확인
3. 방화벽 설정 확인

### SSH 호스트 키 오류

```bash
ssh-keyscan -H <Tailscale 내부 IP> >> ~/.ssh/known_hosts
```

### Windows에서 SSH가 없을 때

1. 설정 > 앱 > 선택적 기능 > 기능 추가
2. "OpenSSH 클라이언트" 설치

또는 [Git Bash](https://git-scm.com/downloads) 설치 후 사용
