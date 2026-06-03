# QuickAccess

macOS 메뉴바 앱 — 자주 쓰는 웹사이트를 작은 독립 창으로 빠르게 실행합니다.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## 특징

- ⚡ **메뉴바 상주** — 번개 아이콘 클릭 한 번으로 사이트 실행
- 🪟 **독립 창** — Chrome --app 모드로 주소창 없이 깔끔하게
- 📐 **창 크기/위치 커스텀** — 사이트별 원하는 크기와 위치 설정
- 🎯 **레이아웃 프리셋** — 정중앙, 좌우/상하 분할, 4분할 원클릭 배치
- 📏 **Size 프리셋** — Tiny ~ Full까지 빠른 크기 선택
- 🎯 **Center 버튼** — Width/Height 입력 후 원클릭 중앙 배치
- ⚙️ **Settings GUI** — 코드 수정 없이 사이트 추가/관리
- 📦 **Import/Export** — 설정 파일을 공유하여 다른 사용자에게 전달
- 🚀 **Launch at Login** — 로그인 시 자동 시작 토글
- 🗑️ **Uninstall** — 설정창에서 앱 + 설정 + 로그인 항목 원클릭 제거
- 🔒 **기존 Chrome 인증 유지** — Chrome에 로그인된 세션 그대로 사용

## 요구사항

- macOS 14.0+
- Google Chrome 설치

## 설치

1. `QuickAccess.zip` 다운로드 (공유받은 파일)
2. 압축 풀기
3. `QuickAccess.app`을 Applications로 이동 (또는 바로 실행)
4. **첫 실행 시 "손상되었기 때문에 열 수 없습니다" 경고가 뜨면:**
   ```bash
   xattr -cr /Applications/QuickAccess.app
   ```
   (또는 다운로드 위치에 맞게 경로 변경)
5. 이후 정상 실행 가능

## 사용법

1. 메뉴바에서 ⚡ 클릭
2. 등록된 사이트 클릭 → Chrome 독립 창으로 열림
3. **Settings...** → 사이트 추가/수정/삭제
4. **Launch at Login** → 자동 시작 on/off

### 설정 공유

- Settings → **Export** → JSON 파일로 저장
- 상대방: Settings → **Import** → 받은 JSON 적용

### 설정 파일

`~/.quickaccess.json`에 저장됩니다:

```json
{
  "runInBackground": true,
  "sites": [
    {
      "name": "Google",
      "url": "https://www.google.com/",
      "width": 600,
      "height": 300,
      "x": 456,
      "y": 341
    }
  ]
}
```

## 만든이

**Mingyu**
- uqwe00@gmail.com

## License

MIT

---
Built with [Kiro](https://kiro.dev)
