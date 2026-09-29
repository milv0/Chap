# Notch Surface Geometry Spec

노치 표면(메인 패널·Chap Drop 도커·Drop 배지)의 시각 스펙.
**모든 수치의 단일 출처는 `Sources/ChapCore/NotchGeometry.swift`** 이며,
이 문서는 각 수치가 화면 어디에 해당하는지 보여주는 지도다.

스펙을 조정하고 싶을 때: 아래 이름으로 값을 지정하거나("badgeNotchOverlap을
8로"), 스크린샷에 마킹해서 전달하면 된다.

## 배치 다이어그램

```
 화면 최상단 ────────────────────────────────────────────────────────
 │  menu bar     [═══════ notch (hardware) ═══════]▓▓[■ 34×32]╮    │
 │                        185 × 32 (runtime)     (12+34+10)×32 │    │
 └────────────────────────────────────────────────────────────┴────┘
                     badgeNotchOverlap 12 (노치 밑으로 파고듦 ▓) ↑
                     보이는 본체 badgeBodyWidth 34 × 32, 플레어 10은 그 바깥  ↑
                     하단 바깥: badgeCornerRadius 6 볼록          ↑

 도커가 펼쳐지면 (노치 중앙 정렬):
              ╭──flare 10                        flare 10──╮
              │ [left span 32][═ notch 185 ═][badge span 32]│
              │                                             │
              ╰──dockBottomRadius 18 (모든 도커 공통)     ───╯
```

## 좌우 배지

- **오른쪽 Drop 배지**: 보관함에 파일이 있을 때 표시. hover하면 메인
  도커가 열리고, 직접 드롭도 받는다. 파일을 끌고 노치·배지에 대면 메인
  도커 위에 반투명 "Drop here" 레이어가 덮인다. Drop 파일들은 메인 도커
  하단의 가로 아이콘 행(파일이 있을 때만 표시)으로 보여준다.
- **왼쪽 상태 영역**: 별도 배지 창은 두지 않는다. Keep Awake 시작/종료는
  상단바 아이콘 색과 중앙 HUD가 담당하고, 메인 도커가 열렸을 때만 왼쪽
  plateau 안에 파란 번개(bolt.fill) 아이콘 + h:mm:ss 남은 시간을 1초마다 렌더링한다.
  묶음은 영역 중심에서 오른쪽으로 `awakeStatusOffsetX`만큼 보정한다.

## 실루엣 문법: 오목 플레어

모든 노치 표면(메인 패널·Drop 도커·드롭 존·배지)의 **상단 모서리는 볼록
라운드가 아니라 오목 플레어**다. `NotchDockShape`의 상단은 상단바 라인에서
바깥으로 흐르는 오목 곡선(반경 `dockFlareRadius`)으로 시작해 본체 벽으로
이어진다 — 실제 노치가 메뉴바와 만나는 방식과 같은 문법이라 표면이
"상단바에서 빠져나온" 것처럼 보인다.

이 구조의 부작용 두 가지를 항상 기억할 것:

1. **벽 인셋** — 본체 벽은 프레임보다 좌우 각 `dockFlareRadius`만큼
   안쪽에 선다. 메인 패널은 `NotchDockShape`과 동일한 geometry를 공유하고,
   Drop 배지는 별도 `NotchBadgeShape`으로 노치 쪽 직선 변과 바깥 플레어를 만든다.
2. **림 스트로크** — 림 하이라이트는 상단 변을 긋지 않는 `isRim` 경로를
   써야 노치 경계에 흰 줄이 생기지 않는다.

배지도 같은 `NotchDockShape`을 쓴다: 상단 오목 플레어 + 하단 볼록
(`badgeCornerRadius`). 노치 쪽 절반은 겹침(overlap)으로 하드웨어 밑에
숨고 바깥 프로필만 보인다.

## 수치 표

| 이름 | 값 | 의미 |
|---|---|---|
| `stripPlateauSideWidth` | 110 | 노치 좌우의 평평한 검정 상태 영역 폭 |
| `awakeStatusOffsetX` | -2 | 왼쪽 상태 영역 안의 h:mm:ss 번개+시간 묶음 좌측 광학 보정 |
| `badgeBodyWidth` | 34 | 배지 본체(보이는 검정) 폭. 높이는 노치 높이 |
| `badgeNotchOverlap` | 12 | 배지가 노치 밑으로 파고드는 겹침 (우측 배지 → 노치의 둥근 오른쪽 아래 모서리를 채움) |
| `badgeCornerRadius` | 6 | 배지 하단 볼록 모서리 (하드웨어 노치 곡률에 근접). 상단은 `dockFlareRadius` 오목 플레어 |
| `dockFlareRadius` | 10 | 도커 상단 오목 플레어. 상단바에서 흘러나오는 곡선. **폭 보정 계산과 공유** |
| `dockBottomRadius` | 18 | 메인 도커 하단 라운드. 배지만 비례상 작은 `badgeCornerRadius` |
| `glassEdgeBleed` | 10 | Glass 광학 edge를 플레어 밖으로 밀어 검정 꼭짓점까지 재질 연결 |
| `contentTopGap` | 15 | 노치 하단 경계와 섹션 콘텐츠 사이 세로 간격 |
| `stripEdgeDepth` | 6 | 눌린 검정 띠가 도커 끝에서 남는 최소 깊이 |
| `stripFalloff` | 90 | plateau 밖에서 곡선으로 얇아지는 감쇠 길이. 최대 깊이는 노치 세로와 동일 |
| `shadowPadding` | 28 | 그림자 클리핑 방지 투명 여백 |

## 런타임 파생 값 (하드코딩 아님)

기종·디스플레이 스케일에 따라 달라지므로 화면 API에서 매번 계산한다.

| 값 | 계산 | 14" MBP 기본 스케일 기준 |
|---|---|---|
| 노치 높이 | `safeAreaInsets.top` | 32pt |
| 노치 폭 | `auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX` (nil이면 200 폴백) | 185pt |
| 배지 한 변 | 노치 높이 | 32pt |
| Drop 도커 검정 폭 | 노치 폭 + badgeBodyWidth × 2 + 플레어 × 2 | 273pt |

## 스타일

Style 피커는 **Custom / Glass** 두 가지만 제공한다. Custom은 색상·불투명도
설정을, Glass는 System/Light/Dark appearance와 Clear/Regular 재질을 각각 노출한다.

| 스타일 | 콘텐츠 박스 | 비고 |
|---|---|---|
| Custom | 사용자 색 + 불투명도 페이드 | 기본. 과거 Black/Iceberg 설정은 이 스타일로 마이그레이션 |
| Glass | Liquid Glass 재질 (macOS 26+) | 상단 띠는 검정 유지, 26 미만은 Custom 기본 검정과 동일 |

상단바 띠는 어떤 스타일에서도 순검정이다 — 노치와 융합해야 하므로
유리·색이 침범하지 않는다.

Apple 공식 API는 연속 강도를 제공하지 않고 `Glass.clear`와
`Glass.regular` 두 재질 변형을 제공한다. appearance와 재질은 서로 독립적으로 고른다:

- appearance는 패널의 `NSAppearance`만 정한다 — `system`은 `NSPanel.appearance = nil`
  (macOS Light/Dark 자동 추적), `light`은 `NSAppearance(named: .aqua)`,
  `dark`는 `NSAppearance(named: .darkAqua)`
- 재질은 appearance와 무관하게 `config.notchGlassMaterial` 값을 그대로 쓴다.
  어떤 appearance에서도 Clear·Regular를 자유롭게 조합할 수 있다

`resolvedMaterial` 정책은 더 이상 없다. 렌더러(`glassMaterialProvider`)는
`config.notchGlassMaterial`을 직접 전달하고, Settings의 Glass Material 피커는
Glass 스타일일 때 항상 노출된다.

노치 UI는 Settings와 별도 `NSPanel`이므로 SwiftUI `colorScheme`만 바꾸지 않고
패널 자체에 appearance를 적용한다. Settings에서 재질 또는 appearance를 바꾸면
메인 도커를 2.5초 동안 자동으로 펼쳐 새 디자인을 프리뷰한다. 재질 변경은 이미 열린
SwiftUI 뷰를 새 재질로 재구성한다. Glass 콘텐츠 텍스트는 semantic
`primary`/`secondary`, 기능 아이콘은 Chap accent, hover 면은 appearance에
적응하는 `primary.opacity(0.08)`을 쓴다.

Glass는 custom 오목 플레어 경계에서 시스템 광학 edge가 안쪽으로 물러나
배경화면 틈이 생기지 않도록 두 장치를 쓴다:

1. `glassEdgeBleed`: Glass 효과의 광학 edge를 외곽으로 밀고 본체 셰이프로 마스킹
2. `GlassCornerBridgeShape`: 좌우 오목 코너의 빈 wedge를 Glass로 채워 재질이
   화면 상단 플레어 꼭짓점까지 직접 닿게 함
3. Glass의 `PressedStripShape.edgeDepth`는 0: 검정 띠가 외곽 코너에서 완전히
   사라지므로, 상단 좌우 둥근 꼭짓점에 보이는 재질은 검정이 아니라 Glass다

검정 `PressedStripShape`은 bridge 위에 별도로 그리되 본체 셰이프로 클립해
중앙 노치·배지 plateau는 검정으로 유지한다. Custom은 기존 `stripEdgeDepth` 6을
유지해 검정 상단 띠가 외곽에도 남는다.

## 가독성 기준 (Apple HIG)

콘텐츠 박스 색을 사용자가 자유롭게 고르므로 전경색은 배경 휘도에 따라
자동 적응한다. 기준은 Apple HIG의 대비 규칙(텍스트 4.5:1 최소·7:1 권장,
비텍스트 3:1)이며 규칙은 `NotchContrastPolicy`가 테스트로 고정한다.

| 요소 | 어두운 Custom 배경 | 밝은 Custom 배경 | Glass |
|---|---|---|---|
| 섹션 라벨 | 흰색 보조 계층 | 검정 65% | semantic secondary |
| 섹션 아이콘 | 밝은 블루 #89A3FF 90% | 액센트 75% | 라이트 액센트 75%, 다크 밝은 블루 90% |
| 상단 띠 아이콘 | 밝은 블루 80% (호버 100%) | 같음 | 같음 |
| 키캡 글자 / 바탕 | 본문색 80% / 14% | 본문색 80% / 14% | primary 80% / 14% |
| 본문 텍스트 | 흰 96% + 그림자 | 검정 87%, 그림자 없음 | semantic primary |

글자 크기는 세 단계만 쓴다: 본문 13pt(`DS.notchBody`), 제목·키캡 11pt semibold(`DS.notchLabel`),
보조 정보 10pt medium(`DS.notchMeta`, 노치 최소 크기). 모든 칸의 제목 줄은 16pt(`notchHeaderHeight`),
목록·스크린샷 행은 26pt로 같아 가로로 줄이 맞는다. 스크린샷 행은 잘리는 파일명 대신 34×22pt 썸네일(왼쪽)과
"5 min ago" 같은 상대 시각(오른쪽 끝 정렬, 10pt 보조색·고정폭 숫자, 다운로드 칸과 같은 크기)을 보여주고, 파일명은 툴팁·VoiceOver로 제공한다.
Glass Clear에는 창 배경색 28% 베일을 얹어 뒤 화면이 복잡해도 대비를 확보한다. 새 설정의 기본 재질은 Regular다.

참고: https://developer.apple.com/design/human-interface-guidelines/color

## 위젯 칸

위젯은 6칸 한 줄이다. 빈 칸은 그리지 않고, 칸마다 내용에 맞는 폭을 쓴다.
도커 최소 폭은 640pt(또는 노치 + 양쪽 상태 영역 110pt씩 + 80pt 중 큰 값, `NotchLauncherPolicy.dockMinWidth`)이고,
위젯 줄이 그보다 좁으면 가운데 정렬한다. Drop 파일 줄은 왼쪽 정렬을 유지한다.

| 칸 | 폭 |
|---|---|
| Sites·Finder | 가장 긴 줄(이름 + 키캡)과 제목 중 긴 쪽, 112–170pt (`LauncherListPolicy.listColumnWidth`) |
| Screenshots | 썸네일 34 + 가장 긴 시각 문구 기준, 112–170pt |
| Apps | 2열 아이콘 격자 80pt (제목이 더 길면 제목 폭) |
| Downloads | 200pt (파일명이 핵심) |
| Focus | 150pt |

글자 폭은 `NotchTextMetrics`가 실제 글꼴(13pt 본문, 11pt semibold)로 재고 SwiftUI 렌더링 여유를 더한다. 위젯 종류(Sites·Apps·Finder·Screenshots)가
모두 한 번에 들어가는 수라서 페이지를 두지 않는다. 2.1의 12칸 설정은 뒤쪽 위젯을 앞쪽 빈 칸으로
당겨 6칸에 옮기고, 2.0의 4칸 설정은 순서 그대로 앞 4칸이 된다.

## Apps 칸: 아이콘 격자

Apps 위젯은 목록 대신 앱 아이콘 2열 격자(최대 2열 × 3줄, 6개)다. 앱 수와 관계없이 2열 × 3줄 자리(113pt)를 잡고 위에서부터 한 줄에 둘씩 채운다. 아이콘 32pt, 타일 34pt 정사각(고정 폭 열), 가로 간격 8pt, 세로 간격 5.5pt. 세로 간격은 격자 3줄(앱 6개) 높이가 목록 칸 4줄 높이(26pt × 4 + 3pt × 3 = 113pt)와 정확히 같도록 계산한다.
단축키가 있으면 아이콘 오른쪽 아래에 키 글자만(`S`) 10pt semibold 키캡으로 붙인다. 호버 시 앱 이름
툴팁과 `rowHoverBackground`, VoiceOver는 "Launch Slack, Option S". 아이콘은 `AppIconLoader`가
utility queue에서 `NSWorkspace.icon(forFile:)`로 읽고 경로별로 캐시한다. Apps 칸 폭은 격자 폭 80pt다. 목록 칸(Sites·Finder 등)은 160pt 그대로다.

## 도구 위젯: Mirror · Quick Note

위젯 칸 사이에는 1pt 세로 구분선(`subtleSurface`)을 간격 중앙에 겹쳐 그린다. 모든 칸을 가장 긴 칸 높이로 늘리므로 구분선은 내용이 짧은 칸에서도 줄 전체 높이다. 폭 계산에는 영향이 없다.

- **상단 띠 도구 (Mirror · Quick Note)**: 칸이 아니라 검정 띠 오른쪽의 흰 아이콘(13pt)이다. 도커가 펼쳐져 있으면
  Drop 상자는 파일이 없어도 배지 자리에 숫자 없는 빈 상자로 보이고(접힌 노치에서는 파일이 있을 때만 배지),
  첫 도구는 항상 상자 바로 오른쪽에 두고 `stripToolPitch` 28pt 간격으로 Mirror,
  Quick Note 순서로 놓는다 (`NotchLauncherPolicy.stripToolCenterOffsets`). 한 번에 하나만 띠 아래로 펼친다.
  - Mirror: 144×108 좌우 반전 미리보기. 미리보기가 카메라 큐에서 세션에 연결된 뒤에만 캡처를 시작한다.
  - Quick Note: 팝업이 아니라 **메모 모드**다. 누르면 위젯 줄 자리가 도커 폭 전체의 메모장(줄 높이 200pt)으로 바뀌고
    도커가 SwiftUI로 잰 콘텐츠 크기를 `NotchContentSizeKey`로 올려 보내고 컨트롤러가 그 크기로 창을 맞춘다
    (`resizePanel(toContentSize:)`). 레이아웃 전 추측 측정을 쓰지 않아 아래 Drop 줄이 창 밖으로 밀리지 않는다. 도구 줄: 제목, 글자 수(`characterCountLabel`), 복사, 창으로 분리,
    × (위젯으로). 분리 창(`QuickNoteWindow`)은 floating·크기 조절·위치 기억(420×320 기본, 280×180 최소)이며, 창이 열려
    있는 동안 띠 아이콘은 그 창을 앞으로 가져온다. 분리 직전 flush하고 창은 같은 직렬 큐에서 읽어 입력을 놓치지 않는다.
  아이콘 재클릭·×·도커 닫힘, 팝업 바깥 클릭(`didClickPanel` 로컬 mouseDown 모니터, 클릭은 그대로 전달),
  패널 key 상실(다른 앱 클릭)로 접힌다. Settings → Notch의 **Show Mirror Icon**(`notchMirrorEnabled`)와
  **Show Quick Note Icon**(`notchQuickNoteEnabled`, 둘 다 기본 켬)로 숨긴다. 예전 `mirror`·`note` 칸은 디코딩 때 빠진다.
- **Quick Note 입력**: 13pt 본문 `TextEditor`, 0.5s debounce 후 직렬 큐 저장, `willHidePanel` 때 flush.
  입력 중에는 마우스가 벗어나도 닫지 않고 Esc 또는 key 상실로 끝낸다. 패널은 `NotchKeyablePanel`이다.

## 칸 제목 클릭

- Sites·Apps·Finder 제목: 누르면 도커를 닫고 설정창 Launchables 탭에서 그 타입의 첫 항목을 선택한다
  (`showSettings(focusing:)` → `SettingsView.focusLaunchType` 알림). 호버 시 옅은 면과 ›, 툴팁 "Edit Sites in Settings".
- Screenshots 제목: 스크린샷 저장 폴더를 Finder로 연다.
- Mirror·Quick Note 제목: 동작 없음.

## 노치에서 실행할 때의 창 크기

노치는 확장 런처다. Apps 칸에서 **단축키가 없는 앱**은 크기·위치를 건드리지 않고 그냥 연다
(`AppLauncher.open`, Accessibility 권한 불필요). 단축키가 있는 앱과 Sites·Finder는 상태바 메뉴와 같이
설정한 크기로 가운데에 연다. 판정은 `LauncherListPolicy.resizesOnNotchLaunch`. 상태바 메뉴와 ⌥ 단축키
실행은 항상 크기를 맞춘다.

## 단축키 키캡과 ⌥

Sites 목록과 Apps 아이콘의 키캡은 평소 키 글자만(`1`, `N`) 보여준다. 도커가 열린 채 ⌥를 누르고 있으면
모든 키캡(10pt semibold, 좌우 4·위아래 1pt 여백)이 액센트 블루로 바뀌며 `⌥1`, `⌥N`처럼 수식키를 함께 보여준다. ⌥ 상태는 visibility 타이머(80ms)가
전역 `NSEvent.modifierFlags`로 읽는다(nonactivating 패널은 flagsChanged를 받지 못하고, 전역 키 모니터는
권한이 필요하기 때문). 목록 키캡은 `⌥1` 폭을 미리 잡아 바뀌어도 줄이 움직이지 않는다. 행·아이콘 툴팁과
VoiceOver("Option 1")는 항상 전체 조합을 알려준다.

## Drop 파일 줄

파일이 있을 때만 위젯 줄 아래에 구분선과 한 줄이 생긴다. 트레이 아이콘 뒤에 64×48pt 타일(28pt 파일 아이콘 + 10pt 한 줄 파일명,
가운데 생략)을 나란히 두고, 전체 파일명은 툴팁과 VoiceOver로 제공한다. 호버 시 왼쪽 위 반투명 회색 공유(`NSSharingServicePicker`:
AirDrop·메시지·메일 등)와 오른쪽 위 빨간 삭제 ×가 보인다. 공유 메뉴가 떠 있는 동안은 도커를 고정한다
(`setSharingPinned`). 우클릭 메뉴·VoiceOver 동작: Open, Share…, Show in Finder, Remove from Chap Drop.

## 오프스크린 렌더 (개발용)

    TEST_RUNNER_CHAP_NOTCH_RENDER_DIR=/tmp/notch xcodebuild -scheme Chap -destination "platform=macOS" test

`Tests/ChapCoreTests/NotchRenderTool.swift`가 현재 `~/.chap.json`·스크린샷·Drop 파일로 도커를 그려
`notch-glass-light.png`, `notch-glass-dark.png`, `notch-custom.png`를 저장한다. 화면 기록 권한 없이 레이어를
직접 그린다. Liquid Glass 재질과 NSView(메모 입력칸, 카메라 미리보기)는 그려지지 않아 Glass는 비슷한 밝기의
배경 위 투명 도커로 근사한다. 변수 없이 테스트하면 건너뛴다.

## Focus 칸 (Keep Mac Awake)

번개 아이콘의 Focus 모드. 상태바 메뉴 Keep Mac Awake와 **같은 세션**이다.
- 꺼짐: 흐린 `bolt` + "Chap on" / "No sleep, no dimming." + 1h·4h·8h 캡슐 버튼(`focusPresets`, 호버 시 액센트).
- 켜짐: 맥박치는 파란 `bolt.fill` + 20pt 남은 시간(h:mm:ss) + 남은 시간에 따른 한 줄(Fully charged → In the zone →
  Final stretch → Landing soon, `focusActiveLine`) + "Chap off"(끄기).
- 켜져 있는 동안 상단 띠 왼쪽 Keep Awake 시계도 커피 대신 같은 번개(`bolt.fill`) 아이콘을 쓴다.
- 버튼은 `NotchFocusView.activateRequest/deactivateRequest` 알림으로 앱의 `KeepAwakeController`를 부르고, 컨트롤러는
  모든 이벤트 뒤 `didChangeNotification`을 보내 위젯·메뉴·상단 띠 시계가 함께 바뀐다. 사운드·HUD는 메뉴와 같다.

## Downloads 칸

`~/Downloads`에서 최근 4개(폴더에 들어온 시각 순, 없으면 수정 시각)를 보여준다. 숨김 파일, 받는 중인 파일
(`.crdownload`, `.download`, `.part` 등), 폴더(.app 제외)는 뺀다(`DownloadsShelfPolicy`). 한 줄은 26pt: 20pt 파일
아이콘(이미지는 썸네일), 가운데 생략 파일명, 오른쪽 끝 짧은 시각(`now`, `5m`, `3h`, `1d`, `Sep 24`). 클릭 열기, 드래그
꺼내기, 우클릭 Open·Share…·Show in Finder. 제목 클릭은 Finder로 다운로드 폴더를 연다. 2초마다 다시 읽고, 위젯이
보일 때만 읽는다. macOS가 다운로드 폴더를 보호하므로 처음 한 번 폴더 접근 권한을 묻는다.

## 모션 기준

모든 노치 표면이 같은 타이밍 기준을 쓴다. 닫힘 관련 값은 전부
`closeDuration` 하나에서 파생된다.

| 이름 | 값 | 의미 |
|---|---|---|
| `openAnimation` | spring 440/30 (~0.3s) | 패널 펼침. 노치 상단 기준 스프링 확장 |
| `closeDuration` | 0.18s | 메인 패널 접힘 시간 |
| 창 제거 | closeDuration + 0.02s | 닫힘 애니메이션 종료 직후 |
| `hideDelay` | 0.2s | 마우스가 영역 밖에 머물면 닫힘 판정 |
| `hoverMargin` | 0 | 노치·배지의 hover/드래그 인식 범위는 시각 경계와 동일 |
| `pollInterval` | 0.08s | 마우스 위치 폴링 주기 |


## 설정 Import/Export

Export는 hidden menu와 노치 설정을 포함한 현재 Config 전체를 보존한다.
Import는 launchable·일반·hidden menu 설정을 적용하지만, 노치 설정은 기기
하드웨어에 종속되므로 현재 기기의 값을 유지한다.

## 관련 파일

- `Sources/ChapCore/NotchGeometry.swift` — 수치의 단일 출처
- `Sources/ChapCore/NotchLauncherPolicy.swift` — 표시 조건·프레임 계산 (테스트로 고정)
- `Sources/ChapCore/MirrorPolicy.swift`, `QuickNoteStore.swift` — 거울 상태·메모 저장 (테스트로 고정)
- `Sources/Chap/Views/NotchWidgetViews.swift`, `Sources/Chap/MirrorCamera.swift` — 거울·메모 위젯
- `Sources/Chap/Views/NotchLauncherPanelView.swift` — 메인 패널 + 도커 실루엣 셰이프
- `Sources/Chap/Views/NotchDropViews.swift` — Drop 도커·드롭 존·배지
- `Sources/Chap/NotchLauncherController.swift` — 창 배치·표시 로직
