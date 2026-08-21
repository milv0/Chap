# Chap Runtime Flow

이 문서는 **"실행 시점에 무엇이 어떤 순서로 일어나는가"** 만 다룬다.

| 알고 싶은 것 | 볼 문서 |
| --- | --- |
| 파일/폴더 구조, 기능 목록, 사용 API | `ARCHITECTURE.txt` |
| 실행 순서, 분기, 스레드, 타임아웃, 판정 기준 | 이 문서 |
| 코딩 규약, 테스트 규약, 커밋 규약 | `.harness/shared/rules/` |

코드 참조는 줄 번호가 아니라 `File.swift › symbol()` 형식을 쓴다 (줄 번호는 쉽게 낡는다).

---

## 0. 읽는 순서 (LLM 권장)

1. §1 불변 규칙 — 이걸 깨는 변경은 과거 회귀 재발이다
2. §5 사이트 실행 공통 흐름 — 앱의 핵심 경로
3. 고치려는 런처만 §7에서 골라 읽기
4. §12 알려진 이슈 — "이미 아는 문제"를 새 버그로 오진하지 않기 위해

---

## 1. 불변 규칙 (Invariants)

깨면 과거에 실제로 발생했던 문제가 재발한다. 변경 전 반드시 확인한다.

| # | 규칙 | 깨질 때 생기는 문제 |
| --- | --- | --- |
| I1 | 리사이즈 대상은 **baseline 대비 새 창 1개**, 없으면 **focused 창 1개**. 절대 "앱의 모든 창"이 아니다 | 사용자가 작업 중인 기존 창들이 한꺼번에 튄다 |
| I2 | 성공 판정은 AX set 반환값이 아니라 **readback 비교** (tolerance 4px) | 앱이 최소 크기로 클램프해도 성공으로 기록됨 |
| I3 | baseline 스냅샷이 빈 배열이면 재시도한다 (5회 × 30ms) | 기존 창이 "새 창"으로 오인돼 리사이즈됨 |
| I4 | Chrome은 `Process` 실행까지 **단일 serial queue 안에서** 수행 | 연속 실행 시 요청과 창이 뒤섞여 엉뚱한 창이 리사이즈됨 |
| I5 | 창 위치(x, y)는 config에 저장하지 않는다. 항상 대상 화면 중앙 | 화면 구성이 바뀌면 화면 밖에 창이 생성됨 |
| I6 | shortcut 정규화(`sanitizedShortcuts`)는 **UI 저장 / config load / import 3경로 전부** 통과하고, load에서 바뀐 값은 즉시 저장 | 손으로 편집한 `~/.chap.json`의 다글자·중복·예약키가 런타임이나 다음 실행에 새어 든다 |
| I7 | `.` 와 `,` 는 예약 단축키 (⌥. 메뉴, ⌥, 설정) | 전역 단축키 충돌 |
| I8 | `ResizeLogger`는 `#if DEBUG` 전용 | 최종 사용자 기기에 "무엇을 언제 열었는지" 이력이 쌓인다 |
| I9 | 사용자 데이터(이름·URL·경로)는 `privacy: .private` | 통합 로그에 평문 유출 |
| I10 | 같은 앱 연속 실행 시 **최신 관찰만 유효** (`ResizeObservationRegistry` token) | 이전 AXObserver가 Office grace 20초 동안 남아 중복 스캔 |
| I11 | `GuideWindow.dismiss(token)`은 토큰이 현재일 때만 자기 창을 닫는다 | 연속 실행 시 유령 가이드 창이 남는다 |
| I12 | 관리 창(Settings/QA/Welcome) 전부 닫히면 activation policy를 `.accessory`로 복원 | Dock 아이콘이 계속 남는다 |
| I13 | 글로벌 단축키는 `RegisterEventHotKey`로 **정확한 Option 조합만** 등록. 전체 keyDown event tap 금지 | Chap 메인 스레드 정체가 일반 키 입력 전달을 막는다 |
| I14 | URL 창 재사용은 **같은 active-tab URL의 focused 창 1개**만 활성화·리사이즈. 매칭 실패 시 기존 새 창 흐름으로 폴백 | 다른 Chrome 작업 창이 이동되거나 실행 요청이 사라진다 |

---

## 2. 앱 시작 흐름

`main.swift` → `NSApplication` + Edit 메뉴만 구성 → `AppDelegate`.

`AppDelegate › applicationDidFinishLaunching` 은 **순서가 의미를 갖는다**:

```
1. migrateConfigIfNeeded()      ~/.quickaccess.json → ~/.chap.json (신규 파일 없을 때만 move)
2. copyDefaultConfigIfNeeded()  파일이 없으면 ConfigStore.seedConfig 로 생성
3. loadConfig()                 읽기 → decode → shortcut 정규화 → display UUID 마이그레이션
4. stripLegacyConfigFields()    원본 JSON에 레거시 키가 남아 있으면 1회 덮어써 정리
5. applyLoginItem()             목표 상태와 다를 때만 SMAppService register/unregister
6. NSApp.setActivationPolicy(.accessory)
7. statusItem 생성 (28pt, config.statusBarIcon에 따라 StatusBarIcon template 또는 bolt.fill 심볼)
8. buildMenu()                  메뉴 구성 + RegisterEventHotKey 전체 재등록
9. initializeAccessibilityHandling()   권한 확인 + 옵저버 등록 (+ 최초 시스템 프롬프트)
10. 0.5s 후 showWelcomeWindow()        UserDefaults "guideDisabled" 가 false일 때만
```

- 2가 3보다 먼저여야 첫 실행에서 빈 config로 로드되지 않는다.
- 4는 3 뒤여야 한다. decode→encode 과정에서 레거시 키가 탈락하므로, 로드된 `config`를 그대로 다시 써서 정리한다.
- 9의 시스템 프롬프트는 테스트 실행 중(`isRunningTests`)에는 뜨지 않는다.

---

## 3. 접근성 권한 상태 머신

상태: `unknown` → `granted` / `denied` (`AppDelegate › AccessibilityState`).

모든 전이는 `refreshAccessibilityState(reason:showAlert:requestSystemPrompt:)` 한 곳을 지난다.
메인 스레드가 아니면 스스로 메인으로 hop 한다.

| 트리거 | reason | showAlert | 시스템 프롬프트 |
| --- | --- | --- | --- |
| 앱 시작 | `launch` | X | O (테스트 제외, 1회만) |
| 앱 활성화 (`didBecomeActive`) | `app active` | X | X |
| 메뉴바 메뉴 열림 (`menuWillOpen`) | `menu` | X | X |
| Settings 열기 | `settings` | X | X |
| 사이트 실행 | `launch` | url/app 타입일 때만 O | X |
| AX 리사이즈 실패 알림 | `resize failure` | O | X |
| 권한 감지 폴링 (2s 간격, 최대 30s) | 직전 reason | X | X |

전이 결과:

- **granted**: 폴링 중단, alert 플래그 리셋
- **denied**: (프롬프트 요청 시) 프롬프트 + 30초 폴링 시작, 상태바 아이콘을 경고 심볼로 교체
- **granted → denied (revoke)**: error 로그 + alert 1회 (`didShowAccessibilityAlert`로 중복 차단)

> 리사이즈 실패는 권한 알림을 **오발**하지 않는다. `refreshAccessibilityState`가 `AXIsProcessTrusted()`를 다시 확인하고 trusted면 즉시 return 하기 때문.
> 글로벌 단축키는 접근성 상태 머신과 독립이다. 권한이 없어도 단축키와 Finder/Shell 실행은 동작하고,
> URL/App은 실행되지만 AX 리사이즈만 생략한다.

---

## 4. 글로벌 단축키 흐름

`AppDelegate › buildMenu()`가 config 변경 때마다
`GlobalHotKeyManager › configure(sites:optionShortcutsEnabled:actionHandler:)`를 호출한다.

```
globalHotKeyRegistrations()
├─ optionShortcutsEnabled == false → 빈 등록 목록
├─ "." → openMenu
├─ "," → openSettings
└─ sanitized site.shortcut → launchSite(original index)

configure()
├─ 이전 EventHotKeyRef 전부 UnregisterEventHotKey
├─ 현재 ASCII-capable keyboard layout에서 문자→keyCode 계산
├─ Option + keyCode만 RegisterEventHotKey
└─ kEventHotKeyPressed 수신 → action ID 조회 → main async
```

- macOS는 등록된 Option 조합만 Chap에 전달한다. 일반 keyDown은 Chap 프로세스를 통과하지 않는다.
- Settings > General의 `Enable Chap Option-Key Triggers`를 끄면 `⌥.`, `⌥,`, 사이트 단축키 등록과
  메뉴의 Option key equivalent가 모두 즉시 해제된다. 사이트별 shortcut 설정값 자체는 유지된다.
- `.`/`,`를 사이트 단축키로 쓸 수는 없다 (I7 + `validateConfig`가 차단).
- 문자→keyCode는 `TISCopyCurrentASCIICapableKeyboardLayoutInputSource` + `UCKeyTranslate`를 쓴다.
  한글/일본어 IME 활성 상태에서도 ASCII 레이아웃을 얻고 AZERTY/Dvorak 물리 배열도 반영한다.
- `kTISNotifySelectedKeyboardInputSourceChanged`를 받아도 ASCII keyboard layout ID가 실제로
  달라졌을 때만 현재 layout으로 전체 단축키를 재등록한다.
- 다른 앱이 같은 조합을 먼저 등록했으면 해당 `RegisterEventHotKey`만 실패하고 status를 error 로그에 남긴다.
- 테스트 프로세스에서는 시스템 전역 단축키를 등록하지 않는다.
- 메뉴 열림 중 `isStatusMenuOpen`으로 중복 popUp을 막는다.
- 메뉴 항목에도 같은 키가 `keyEquivalent + .option`으로 붙어 있어, 앱이 활성 상태일 때는 메뉴 경로로도 실행된다.

---

## 5. 사이트 실행 공통 흐름

`AppDelegate › launchSite(_:)` — 항상 메인 스레드.

```
launchSite(site)
├─ refreshAccessibilityState(reason:"launch", showAlert: type ∈ {url, app})
├─ config.showGuideWindow && type == .url && targetScreen != nil
│     → GuideWindow.show(centeredBounds) → guideToken 보관
└─ switch site.launchType
   ├─ .url    → ChromeLauncher.launch(site) { GuideWindow.dismiss(guideToken) }
   ├─ .app    → AppLauncher.launch(site)             (guide 없음)
   ├─ .finder → folderPath 검증 → 존재 확인 → 화면 결정 → FinderLauncher.openAndResize
   │            (화면이 없으면 NSWorkspace.open 만, 리사이즈 없음)
   └─ .shell  → ShellLauncher.launch(site)
```

가이드 창은 **url 타입에만** 뜬다. Finder 타입의 경로 검증은 여기(AppDelegate)에서 하고,
app/shell 타입의 필수값 검증은 각 런처 진입부에서 한다.

---

## 6. 크기·위치 결정 파이프라인

모든 런처가 공유한다. 전부 `ChapCore/Validation.swift`의 순수 함수 + NSScreen 래퍼.

### 6.1 대상 화면 — `targetScreen(for:)`

```
resolvedDisplayIndex(displayIdentifier, displayName, among: 연결된 화면들)
  1. displayIdentifier(CGDisplay UUID) 완전 일치        ← 최우선
  2. displayName 이 정확히 1개 화면과 일치              ← 같은 이름 2개면 포기 (임의 선택 금지)
  3. nil → cursorScreen (커서 화면 → NSScreen.main → screens.first)
```

### 6.2 크기 — `effectiveWindowSize(for:on:)`

```
1. site가 명시적 display target을 가리키나?
   → 그렇다면 화면별 override를 무시하고 site.windowSizePreset 또는 site.width × site.height를 대상 화면에 맞춰 반환
2. Follow Cursor이고 이 화면에 해당하는 displaySizeOverrides 항목이 있나? (UUID → unique name 순 매칭)
   → 있으면 그 override의 preset(있으면) 또는 custom w/h를 화면에 맞춰 반환   [종료]
3. site.windowSizePreset 이 알려진 preset 인가?
   → 기준 화면 = Follow Cursor면 builtInScreen, 명시적 target이면 대상 화면
   → 기준 화면 비율로 크기 산출 후 실행 화면에 맞춤(fit)                        [종료]
4. site.width × site.height 를 실행 화면에 맞춤(fit)
```

`fittedSize`는 요청/최대 모두 최소 100pt로 클램프하고 종횡비를 유지하며 축소한다.
확대는 하지 않는다 (`scale = min(1.0, ...)`).

### 6.3 위치 — `centeredBounds(for:on:)`

`visibleFrame`(메뉴바·Dock 제외) 중앙에 배치하고, **좌상단 원점 bounds**를 반환한다.

```
좌표계 주의
  NSScreen  : 좌하단 원점 (AppKit)
  AX / AppleScript : 좌상단 원점
  변환 기준 : primaryHeight = NSScreen.screens.first.frame.height (글로벌 원점)
```

각 런처는 이 bounds를 `position = (left, top)`, `size = (right-left, bottom-top)`로 바꿔 AX에 넘긴다.
`GuideWindow`만 반대 방향 변환(`appKitFrame(fromTopLeft:)`)을 써서 NSWindow로 그린다.

---

## 7. 런처별 상세 흐름

### 7.1 URL — `ChromeLauncher`

전제: `/Applications/Google Chrome.app` 존재 + `launchURLHost`가 http(s) URL로 인정.

**모든 단계가 단일 serial queue `requestCoordinator`에서 실행된다** (I4).

```
[main]  경로/URL/화면 검증 → bounds 계산 → enqueue
[coordinator]
 1. queueWait 로깅 (대기 시간과 처리 시간을 분리 기록)
 2. reuseExistingWindow == true이고 Chrome 실행 중이면 Chap 프로세스의 AppleScript로 사이트별 세션 window ID를 먼저 검색
      ID 매칭 → 해당 window 전면화 → AX focused window(없으면 첫 window) 1개 리사이즈 → 종료
      ID 없음/무효 → 모든 탭 URL 검색 → 매칭한 ID를 세션에 기억한 뒤 같은 처리
      미매칭/자동화 실패 → 아래 새 창 흐름으로 폴백
 3. baseline: Chrome PID 확보 → captureExistingWindows(최대 5회 × 30ms)
 4. Process: /usr/bin/open -na "Google Chrome" --args --app=<url>
 5. 권한 없으면 여기서 종료 (리사이즈 없이 실행만)
 6. 폴링: 새 창(baseline 차집합) 탐색
      running : 50ms × 120회  = 최대 6초
      cold    : 100ms × 100회 = 최대 10초
 7. ClaimedWindowRegistry.claimFirstUnclaimed(새 창 후보, liveWindows)
      → 이미 다른 launch가 가져간 창은 건너뛰고, 닫힌 창은 레지스트리에서 정리
 8. axApplyBounds → level 판정 (§8)
 9. 단계별 timing 로그 + ResizeLogger.log(type:"url") + onComplete → 가이드 창 닫기
```

- 매 폴링에서 live Chrome 프로세스를 다시 조회해 가장 최근 프로세스를 관찰한다. PID가 바뀌면
  실행 전 window fingerprint를 새 PID의 창에서 차감해 복원 창과 요청 창을 구분한다.
- 새 창을 못 찾으면 `result == nil` → `detail = "no new window found"`.
- 재사용 URL 비교는 모든 Chrome 탭의 URL 완전 일치이며 경로 끝 trailing slash는 동등 처리한다.
  새 창으로 폴백한 경우에도 전면 Chrome window ID를 해당 사이트의 **현재 Chap 실행 세션에만** 기억한다.
  따라서 로그인 리다이렉트처럼 URL이 바뀌어도 다음 실행에서 같은 창을 재사용할 수 있다. Chrome 재시작
  또는 창 종료로 ID가 무효가 되면 URL 검색으로 되돌아간다. 매칭된 탭을 활성화하고 창을 전면화한 뒤
  AX focused window가 전파될 때까지 최대 1초 대기해 하나만 리사이즈한다. 포커스 값을 읽지 못할 때만
  마지막에 첫 AX window로 폴백한다.
  최초 사용 시 macOS가 Chrome 자동화 권한을 요청할 수 있다. 거부되면 한 번 권한 안내를 표시하고
  새 창 흐름으로 폴백한다.
- 단계별 timing은 baseline·launch request·window wait·AX apply를 분리하고, 관찰된 PID 경로와
  최초 PID event·원래 baseline PID 복귀 시점을 함께 기록한다. PID 선택 정책과 폴링 동작은 바꾸지 않는다.

### 7.2 App — `AppLauncher`

전제: `appPath` 존재. 권한 없거나 화면 없으면 `openApplication`만 하고 종료.

**관찰 정책** (`resizeObservationPolicy`):

| 앱 | 상태 | timeout | postResizeGrace | focusedFallbackDelay |
| --- | --- | --- | --- | --- |
| 일반 | running | 8s | 3s | 0.2s |
| 일반 | cold | 20s | 3s | 20s (= timeout) |
| Office | running | 30s | 20s | 0.2s |
| Office | cold | 30s | 20s | 30s (= timeout) |

Office 판정은 prefix가 아니라 **명시 allowlist**다: `com.microsoft.Powerpoint` / `Excel` / `Word` / `onenote.mac`.
(Teams·Outlook 같은 비문서형 앱이 걸리지 않게 하기 위함. PowerPoint의 ID 표기는 `Powerpoint`가 맞다.)

```
[main]  baseline 캡처 → openApplication(activates: true)
[NSWorkspace 콜백]
   policy 결정 → observationRegistry.begin(key: bundleId) → token 발급
[global(userInitiated)]              ← 관찰이 30초까지 갈 수 있어 전용 백그라운드에서 실행
   observeAndResizeOneWindow()
   ├─ AXObserverCreate 실패 → axResizePolling() 폴백 (120ms 간격, Office 교체/grace 포함 같은 정책)
   ├─ kAXWindowCreatedNotification 구독 + run loop source 등록
   └─ while now < deadline && 관찰이 최신(token)
        · 1초마다 창 스냅샷 debug 로깅
        · baseline에 없는 창들에 resizeIfNewStandardWindow()
        · CFRunLoopRunInMode(0.05)          ← 50ms 재스캔 + 콜백 처리
        · elapsed >= focusedFallbackDelay && 아직 리사이즈 못했고 시도 안 했으면
              focusedWindowFallback() 1회                   ★ §12 이슈 1
              일반 앱은 성공 시 종료, Office는 성공해도 문서창을 계속 관찰
        · 일반 앱  : 새 창 리사이즈 성공 후 grace(3s) 지나면 break
        · Office  : 리사이즈 성공 후 grace(20s) 동안 새 문서창 계속 대기 → 지나면 break
   → 루프 종료 후 아직 리사이즈 못했으면 focusedWindowFallback() 한 번 더
```

**대상 창 자격** (`isEligibleWindowMetadata`, 순수 함수 · 테스트 있음):

```
role == AXWindow && canSetPosition && canSetSize   ← 필수
  └ subrole == AXStandardWindow            → 자격 있음
  └ 그 외 subrole                          → Office 앱일 때만 자격 있음
```

AXHelpTag 등 보조 요소가 걸러지고, Office의 리사이즈 가능한 비표준 문서창은 통과한다.

**교체 정책**: 일반 앱은 첫 성공 창 하나로 끝. Office는 focused fallback이나 시작창을 먼저
리사이즈했어도 grace 동안 새 문서창을 기다려 **이전 리사이즈를 교체**한다. 처리 완료한 창은
다시 적용하지 않는다. AXObserver 생성 실패 시 polling 폴백도 같은 규칙을 따른다.

**supersede**: 같은 앱을 다시 실행하면 새 token이 발급되고, 이전 관찰은 다음 루프 검사에서 빠져나와
`wasSuperseded: true`로 조용히 끝난다. 로그·CSV를 남기지 않는다.

### 7.3 Finder — `FinderLauncher`

단일 AppleScript로 열기와 bounds 설정을 **한 번에** 한다 → 딜레이·폴링이 없다.

```
osascript -e '
  tell application "Finder"
    set targetFolder to (POSIX file "<escaped>") as alias
    open targetFolder
    set bounds of front window to {l, t, r, b}
    activate
  end tell'
```

- 경로는 `\` → `\\`, `"` → `\"` 로 이스케이프한다.
- `global()` 큐에서 실행하고, **`waitUntilExit` 전에 stderr를 먼저 읽는다** (파이프 버퍼 데드락 방지).
- 실패해도 alert를 띄우지 않고 error 로그만 남긴다. `ResizeLogger`에도 기록하지 않는다.
- 필요 권한은 Accessibility가 아니라 **Automation**(Apple Events)이다.

### 7.4 Shell — `ShellLauncher`

`$SHELL -c <script>` (없으면 `/bin/zsh`). 리사이즈 없음 — 스크립트가 창을 만든다는 보장이 없다.
stdout/stderr를 한 파이프로 합쳐 `waitUntilExit` 전에 전부 읽고, exit code ≠ 0이면 그 내용을 alert로 보여준다.

---

## 8. AX bounds 적용과 검증

`LauncherUtils › axApplyBounds` — 모든 런처의 공통 종점.

```
set position → set size → usleep(50ms) → set size → set position → usleep(20ms) → readback
                                          └ 최종 에러 코드는 2차 적용 결과를 쓴다
```

2회 적용은 안정성 때문이다 (일부 앱이 첫 set을 무시하거나 자체 레이아웃으로 되돌린다).

**판정** — `AXBoundsResult.determineLevel` (순수 함수, tolerance 4px):

| position | size | level |
| --- | --- | --- |
| 범위 내 | 범위 내 | `fully` |
| 하나만 범위 내 | | `partial` |
| 둘 다 벗어남 / 둘 다 읽기 실패 | | `failed` |

readback을 못 하면 그 축은 실패로 본다. **AX set이 `.success`를 반환해도 readback이 없으면 성공이 아니다** (I2).

**진단 문자열** — `AXBoundsResult.diagnosticSummary` (콤마 없음 = CSV 한 칸에 들어간다):

```
posReq=(197 140) posAct=(197 140) pos=ok
sizeReq=1118x680 sizeAct=1118x680 size=ok
posErr=0 sizeErr=0
```

- `pos`/`size` 값은 `ok` / `off` / `unreadable` 세 가지. `off`(값이 다름)와 `unreadable`(읽기 실패)을 구분하는 것이 목적이다.
- 대상 창을 아예 못 찾은 경우엔 대신 창 상태 요약이 들어간다: `windows=1 focused=[role=... canSetSize=true]`.

---

## 9. 설정 흐름

Settings는 하단의 `Launchables`와 `General` 두 탭으로 오른쪽 패널을 전환한다. 왼쪽 사이트
사이드바는 두 탭에서 유지되며, General에서 사이트를 선택하면 Launchables로 복귀한다.
Launchables는 사이트 실행·창 설정을, General은 Option 단축키·Guide Window·로그인 실행·
상태바 아이콘을 관리한다.

### 9.1 로드 — `ConfigStore.load(connectedDisplays:)`

```
파일 읽기 실패        → ConfigStoreError.readFailed → Config.default (alert 없음)
JSON decode 실패      → decodeFailed → alert("Config file is corrupted") + Config.default
성공
 ├─ optionShortcutsEnabled 누락 시 true (기존 config 동작 유지)
 ├─ sanitizedShortcuts   빈값/다글자/예약키/중복(대소문자 무시, 앞의 것 유지) → nil
 ├─ migrateDisplayIdentifiers
 │    · UUID가 연결돼 있으면 유지하고 displayName만 최신화
 │    · UUID 없거나 stale이면 이름으로 폴백. 이름이 정확히 1개 화면과 일치할 때만 UUID 보강
 │    · 0개 → disconnectedDisplay 경고 / 2개 이상 → ambiguousDisplay 경고 (자동 선택 안 함)
 └─ 값이 바뀌었으면 즉시 save() (= .bak 생성 후 atomic write)
```

레거시 호환은 decode 시점에 흡수된다: `hotkey`→`shortcut`, `showGhostWindow`→`showGuideWindow`,
`x`/`y`는 decode만 하고 버림, `runInBackground`는 키 자체가 없음.

### 9.2 저장

두 단계 검증이다. **UI와 AppDelegate가 각각 `validateConfig` 전체를 돌린다** (선택된 항목만이 아니라 전체 sites).

```
SettingsView.save(showAlerts:)
 ├─ validateConfig(전체)
 │    자동 저장(showAlerts=false)이고 invalid → 조용히 중단      ← 편집 중 사이트가 있어도 방해하지 않음
 │    수동 저장이고 invalid → 에러 목록 alert 후 중단
 │    warning 있으면 저장 먼저 하고 안내 alert
 └─ vm.onSave(payload)  → AppDelegate 클로저
      ├─ validateConfig 재검증 → invalid면 alert + false 반환
      ├─ configStore.save (기존 파일을 .bak로 복사 후 atomic write)
      ├─ self.config 갱신 → applyLoginItem → buildMenu
      └─ true 반환 → vm.markSaved() (hasChanges = false)
```

`onSave`가 `false`를 반환하면 `markSaved()`가 호출되지 않으므로, 저장 실패 시 변경 상태가 유지된다.
전역 설정(Guide Window/Login/Option Shortcuts/Status Bar Icon)만 바꿀 때는 `saveGlobals()`가
`originalSites`(마지막 저장 시점)를 써서, 편집 중 사이트의 검증 실패와 무관하게 저장된다.

`hasChanges`는 창 닫기/종료 시 확인 alert의 근거다. `Site.==`는 `id`(세션 한정 UUID)를 제외한 값 비교다.

### 9.3 Import — `normalizeForImport`

```
decode → 안전 정규화 → 전체 validateConfig → blocking 이슈 있으면 파일·VM 무변경으로 중단
```

정규화(각각 fixes로 사용자에게 보고):
- width/height < 100 → 100으로 올림 (override 포함)
- 알 수 없는 preset ID → nil (Custom)
- display UUID/이름 마이그레이션
- 잘못된/중복 shortcut 제거

성공 시 일반 저장과 같은 `vm.onSave(payload)` 경로를 사용한다. 따라서 AppDelegate가 재검증 후
`configStore.save` → config 갱신 → Login Item 즉시 적용 → 메뉴 재구성을 수행하고, 성공한 경우에만
VM 갱신 → `markSaved()` → fixes/warnings 요약 alert로 이어진다.

### 9.4 Export

디스크 파일이 아니라 **현재 편집 상태**(저장 안 된 변경 포함)를 pretty-printed JSON으로 내보낸다.
기본 위치 `~/Downloads`.

---

## 10. 스레드 · 큐 지도

| 작업 | 실행 컨텍스트 | 비고 |
| --- | --- | --- |
| Carbon hotkey 이벤트 | application event target | 등록된 Option 조합만 수신, 실제 동작은 main async |
| `launchSite`, 메뉴, alert, 창 | main | |
| Chrome 전체 파이프라인 | serial queue `ChromeRequestCoordinator` | Process 실행 포함 (I4) |
| App 관찰 루프 | `global(qos: .userInitiated)` | 최대 30초 점유. AXObserver run loop source를 이 스레드 런루프에 붙인다 |
| Finder / Shell `Process` | `global()` | `waitUntilExit` 전에 파이프를 읽는다 |
| `ResizeLogger` 파일 쓰기 | 호출한 큐 그대로 | DEBUG 전용. `NSLock`으로 디렉터리/헤더/append 전체를 직렬화 |
| `GuideWindow` show/dismiss | 내부에서 main으로 hop | 토큰으로 소유권 판별 |

`ResizeContext`는 락이 없다. AXObserver 콜백과 스캔 루프가 **같은 스레드**에서 실행되기 때문이며,
이 전제를 깨는 변경(다른 큐에서 ctx 접근)은 데이터 레이스가 된다.

---

## 11. 관측성

### 11.1 통합 로그 (os.Logger)

subsystem = 번들 ID(`com.mingyupark.Chap`), category = `app` / `launcher` / `config`.

```bash
# 최근 실패만 (zsh는 log를 shadow하므로 절대경로로 호출)
/usr/bin/log show --predicate 'subsystem == "com.mingyupark.Chap" && messageType >= 16' \
  --last 1d --style compact

# 런처 전체 흐름 (debug 포함하려면 --debug)
/usr/bin/log show --predicate 'subsystem == "com.mingyupark.Chap" && category == "launcher"' \
  --last 2h --style compact --info
```

**보존 기간이 짧다 (이 기기에서 대략 1~2일).** 며칠 지난 사건은 통합 로그로 추적할 수 없다.
그래서 판정 근거를 CSV에도 남긴다.

### 11.2 리사이즈 CSV (DEBUG 빌드만)

`~/Library/Logs/Chap/resize_YYYY-MM-DD.csv`

| # | 열 | 의미 |
| --- | --- | --- |
| 1 | `timestamp` | ISO8601 (로컬 타임존) |
| 2 | `site` | 사이트 이름 |
| 3 | `type` | `url` / `app` (finder·shell은 기록하지 않음) |
| 4 | `app_state` | `running` / `cold` |
| 5 | `attempt` | **항상 1** (레거시 열) |
| 6 | `delay` | **항상 0.00** (레거시 열) |
| 7 | `total_time` | **첫 applied(`fully`/`partial`) 리사이즈까지의 시간**. 관찰 루프 전체 길이가 아니다 |
| 8 | `result` | `fully` / `partial` / `failed` |
| 9 | `window_count` | **실행 전 baseline 창 개수**. 실패 시점의 창 수가 아니다 |
| 10 | `display` | 대상 디스플레이 이름 |
| 11 | `size` | 화면 fitting·화면별 override까지 반영해 AX에 실제 요청한 `WxH` |
| 12 | `detail` | 판정 근거 (§8), 창 상태 요약, URL 타입의 단계별 timing |

7·9번 열의 의미를 착각하면 원인을 오진한다. 특히 `total_time`은 리사이즈에 실패한 행에서는
`elapsed`(루프 전체)로 대체되지만, 성공 행에서는 첫 `fully`/`partial` 적용까지의 시간이다.
시도만 하고 readback 판정이 `failed`인 시점은 latency로 기록하지 않는다.

`detail`은 마지막 열로 나중에 추가됐다. 헤더는 파일 생성 시 한 번만 쓰므로 그 이전에 만들어진
파일에는 헤더에 `detail`이 없다. 1~11열 위치는 그대로여서 기존 분석 스크립트는 계속 동작한다.

URL 타입은 판정 근거 뒤에 다음 고정 형식의 timing suffix를 붙인다.

```text
timing baseline=0.121s launch=0.005s window_wait=1.776s ax=0.021s
pid_switches=2 first_pid_event=0.242s baseline_pid_return=1.768s
pid_path=2109>37320>2109
```

| 키 | 기준 |
| --- | --- |
| `baseline` | 현재 Chrome 프로세스 조회 + 실행 전 AX 창 스냅샷 |
| `launch` | `/usr/bin/open` Process 시작 요청이 반환될 때까지. Chrome 핸드오프 완료 시간이 아님 |
| `window_wait` | launch 반환 후 새 AX 창 감지 또는 timeout까지. PID 핸드오프·Chrome 창 생성 포함 |
| `ax` | position/size 설정 + readback 검증 |
| `pid_switches` | 폴링 중 관찰된 PID 전환 횟수 |
| `first_pid_event` | launch 반환 후 최초 PID 전환까지. 없으면 `na` |
| `baseline_pid_return` | 전환 후 실행 전 PID로 돌아오기까지. 복귀하지 않으면 `na` |
| `pid_path` | 실행 전 PID부터 관찰된 PID 순서. 콜드 스타트의 시작값은 `none` |

```bash
# 오늘 실패·부분 적용만
awk -F, '$8!="fully"' ~/Library/Logs/Chap/resize_$(date +%F).csv

# 전체 기간에서 문제 행만
grep -h -E ",(failed|partial)," ~/Library/Logs/Chap/resize_*.csv
```

---

## 12. 알려진 이슈 (미해결)

새 버그로 오진하지 말 것. 고칠 때는 아래 근거를 먼저 확인한다.

### 이슈 1 — 실행 중 Office 앱에서 30초 헛도는 경로 (미수정)

**증상**: 2026-08-03 Excel 6건이 정확히 ~30.3초 후 `failed`. `app_state=running`, `window_count=0`.

**코드상 원인** (`AppLauncher › observeAndResizeOneWindow`):
1. `didAttemptEarlyFocusedFallback`가 **단발 플래그**라 focused fallback을 0.2초에 한 번만 시도한다.
2. 두 break 조건이 모두 `ctx.lastResizeTime != nil`을 요구한다. 아무것도 리사이즈하지 못하면
   break가 성립하지 않아 30초 deadline까지 50ms 루프를 계속 돈다.

**정황**: 해당 행들은 baseline 창 개수가 0이다. Excel이 실행 중인데 AX 창이 0개
(`captureExistingWindows` 5회 재시도 후에도 빈 배열) → 활성화만 되고 새 창이 안 생기고,
focused 창도 없거나 자격 미달 → 위 경로에 갇힌다.

**영향 범위**: 전용 백그라운드 큐라서 UI·다른 런처를 막지 않는다. 권한 알림도 오발하지 않는다(§3).
사용자에게는 "리사이즈가 안 됨"으로만 나타난다.

**재현 안 되는 이유**: 이후 Excel 실행은 모두 `cold`였고, cold는 `focusedFallbackDelay == timeout`이라
이 경로를 밟지 않는다. 코드는 그대로 남아 있다.

**제안된 수정**: focused fallback을 캡 있는 스케줄(예: 0.2s / 0.6s / 1.2s)로 재시도. 기존
`policy.focusedFallbackDelay` 게이트를 유지하면 cold 동작은 그대로다. 조기 종료(early exit)는
Office 시작창→문서창 전환을 놓치므로 권하지 않는다.

### 이슈 2 — 앱 최소 창 크기보다 작게 요청하면 `partial` (동작상 정상)

Outlook을 831x519로 요청한 2건이 `partial`이었다. 앱이 자체 최소 크기로 클램프한 결과이며 버그가 아니다.
사용자가 1300x769로 올려 해소됐다. 개선 여지: 요청 크기가 앱 최소 크기보다 작을 때 안내.

### 이슈 3 — Chrome `partial`의 20ms readback 경합 (관측 개선 완료)

Chrome이 비동기로 창을 정착시키는 동안 20ms 후 readback이 먼저 찍히면 `partial`이 된다.
과거에는 level만 로그에 남아 원인 구분이 불가능했다. 현재는 `detail` 열에 어느 축이 얼마나
벗어났는지 남으므로, 재발 시 근거를 갖고 판단할 수 있다.

### 이슈 4 — Excel 시작창이 대상이 되는 경우

Excel을 실행하면 `Open new and recent files`(시작창)가 리사이즈 대상이 되는 것이 관측된다.
Office 정책의 `postResizeGrace: 20.0`이 정확히 이 상황을 위한 것(문서창이 늦게 뜨면 교체)이지만,
시작창에서 파일을 클릭해 문서창을 여는 흐름이 20초 안에 끝나는지는 확인되지 않았다.

---

## 13. 변경 시 어디를 고치나

| 바꾸려는 것 | 파일 | 함께 해야 할 것 |
| --- | --- | --- |
| 창 자격 판정, 관찰 타임아웃/정책 | `Chap/Launchers/AppLauncher.swift` | `isEligibleWindowMetadata`·`focusedFallbackDelay`는 순수 함수 → `AXBoundsResultTests.swift`에 테스트 추가 |
| Chrome 창 감지·폴링 | `Chap/Launchers/ChromeLauncher.swift` | I4 유지 (Process를 큐 밖으로 빼지 말 것) |
| bounds 적용·판정·진단 문자열 | `Chap/Launchers/LauncherUtils.swift` | 순수 함수로 유지 → 테스트 추가 |
| CSV 열 | `Chap/Launchers/ResizeLogger.swift` | 열은 **끝에만** 추가. 기존 위치 유지 + `ARCHITECTURE.txt`·§11.2 갱신 |
| 단축키 등록·키보드 배열 변경 | `Chap/GlobalHotKeyManager.swift` | I13 + §4 유지, `GlobalHotKeyManagerTests` |
| 메뉴·권한·창 관리 | `Chap/AppDelegate.swift` | §3·§4 갱신 |
| 크기/좌표 계산, 디스플레이 매칭 | `ChapCore/Validation.swift` | 순수 코어로 분리 → `ValidationTests`/`GeometryTests` |
| config 스키마 | `ChapCore/Models.swift` | decode 폴백 유지 + `ModelTests` round-trip + `ARCHITECTURE.txt` |
| 저장/백업/마이그레이션 | `ChapCore/ConfigStore.swift` | `ConfigStoreTests` |
| 검증 규칙 | `ChapCore/ConfigValidation.swift` | `ConfigValidationTests`. UI·AppDelegate 두 경로가 같은 함수를 쓰는지 확인 |
| Import 정규화 | `ChapCore/ImportNormalization.swift` | `ImportNormalizationTests` |
| UI | `Chap/Views/` | 테스트 대상 아님. 로직은 ChapCore로 내릴 것 |

검증 명령 (좁은 것부터):

```bash
xcrun swift-format lint --recursive --strict Sources Tests
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

`swift test`는 쓸 수 없다 (`Package.swift`가 없다). 파일을 추가/삭제/이동했으면 `xcodegen generate` 후
`ARCHITECTURE.txt`를 갱신한다 (`.harness/shared/rules/architecture-docs.md`).


## 2026-08 AX 안정화 실행 보충

### Accessibility system prompt가 Welcome에 종속되지 않는 이유

`AccessibilityStateController › start()`는 `refresh(reason:"launch")`와 observer 등록을 마친 뒤
main run loop에 `requestSystemPromptAtLaunch()`를 예약한다. interactive 실행이고 아직 trusted가
아니면 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`를 정확히 한 번 요청하고
30초 grant polling을 시작한다. `showWelcomeWindow()` 뒤의
`requestSystemPromptAfterOnboarding()`은 fallback 경로이며, `didRequestSystemPrompt`가 이미 요청된
경우 중복 호출하지 않는다. 따라서 `guideDisabled=true`도 prompt 요청을 막지 않는다.

### 모든 URL/App 리사이즈의 공통 종점

Chrome/App이 새 창을 식별한 뒤에는 같은 `LauncherUtils › axApplyBounds`로 들어간다.
각 AX app/window element에 2초 messaging timeout을 걸기 때문에 응답 없는 대상 앱이 관찰 루프를
시스템 기본 timeout만큼 멈추게 하지 않는다.

```
axApplyBounds(window, targetPosition, targetSize)
├─ AXMinSize → AXMinimumSize 읽기
│   └─ target보다 크면 notes += minSize=WxH
├─ app.AXEnhancedUserInterface 읽기
│   └─ true면 false로 전환, notes += enhancedUI=disabled
├─ set size(targetSize)
├─ set position(targetPosition)
├─ set size(targetSize)
├─ 20ms 대기 → actualPosition / actualSize readback
├─ actual size가 target과 4pt 초과 차이인가?
│   ├─ no  → 기존 targetPosition으로 판정
│   └─ yes → actual size 기준으로 중앙을 보존한 position 재적용
│             notes += recentered=(x y) → 20ms 대기 → 재-readback
├─ 원래 EnhancedUI가 true였을 때만 true로 복원
└─ 최종 readback으로 AXBoundsResult level 판정
```

`size → position → size` 순서는 화면 사이 창 이동에서 중요하다. macOS가 첫 size를 **현재 화면**의
가시 영역에 맞춰 clamp할 수 있으므로, position으로 목표 화면에 옮긴 뒤 목표 size를 다시 적용한다.
실제 size가 앱의 minimum size 때문에 달라지면 center 보정은 위치만 바로잡으며, size readback은
여전히 다르므로 level은 `partial`이다. 이는 성공을 과장하지 않는 의도된 동작이다.

### 진단 해석

`ResizeLogger`의 `detail`은 기본 `posReq/posAct/sizeReq/sizeAct/posErr/sizeErr` 뒤에 공백으로
notes를 붙인다. 다음 token은 조건부다.

| token | 의미 | 없을 때 |
| --- | --- | --- |
| `enhancedUI=disabled` | 대상 앱이 Enhanced UI를 켜서 Chap이 리사이즈 중 껐다가 복원함 | 기능이 빠진 것이 아니라 대상 앱이 해당 상태가 아니었음 |
| `minSize=WxH` | AX가 노출한 minimum size가 요청 size보다 큼 | 앱이 minimum attribute를 안 주거나 요청이 minimum 이상 |
| `recentered=(x y)` | 실제 clamp size로 요청 중앙을 유지하도록 position을 재적용함 | size가 요청과 같거나 4pt tolerance 안 |

App 적용 로그의 `id=`는 public `CGWindowListCopyWindowInfo`의 `pid + frame` 매칭 결과이며, 실패하면
CFHash 기반 파생 id다. 이 id는 진단용이며 Chrome relaunch 경계를 넘는 identity는 아니다.
