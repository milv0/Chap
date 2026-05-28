# QuickAccess

macOS 메뉴바 앱 — 자주 쓰는 웹사이트를 작은 독립 창으로 빠르게 실행합니다.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## 특징

- 🖥️ **메뉴바 상주** — 클릭 한 번으로 사이트 실행
- 🪟 **독립 창** — Chrome --app 모드로 주소창 없이 깔끔하게
- 📐 **창 크기/위치 커스텀** — 사이트별 원하는 크기와 위치 설정
- 🎯 **레이아웃 프리셋** — 정중앙, 좌우/상하 분할, 4분할 원클릭 배치
- ⚡ **Size 프리셋** — Tiny ~ Full까지 빠른 크기 선택
- ⚙️ **Settings GUI** — 코드 수정 없이 사이트 추가/관리
- 🔒 **기존 Chrome 인증 유지** — Chrome에 로그인된 세션 그대로 사용

## 요구사항

- macOS 14.0+
- Google Chrome 설치

## 설치 (바이너리)

1. [Releases](https://github.com/milv0/QuickAccess/releases)에서 `QuickAccess.zip` 다운로드
2. 압축 풀기
3. `QuickAccess.app` 더블클릭
4. "확인되지 않은 개발자" 경고 시 → 우클릭 → 열기 → 열기

## 빌드 (소스)

```bash
git clone https://github.com/milv0/QuickAccess.git
cd QuickAccess
swiftc QuickAccess.swift -o QuickAccess.app/Contents/MacOS/QuickAccess -framework Cocoa
open QuickAccess.app
```

## 사용법

1. 메뉴바에서 **QA** 클릭
2. 등록된 사이트 클릭 → Chrome 독립 창으로 열림
3. **Settings...** → 사이트 추가/수정/삭제

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

**Mingyu Park**
- uqwe00@gmail.com
- brianmg@naver.com

## License

MIT
